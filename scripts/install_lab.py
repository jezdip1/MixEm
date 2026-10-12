#!/usr/bin/env python3
"""Install one verified candidate with optional stimuli, keeping existing config."""
import argparse
import grp
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import pwd
import shutil
import subprocess
import tempfile
import shlex

from assets import import_assets


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def manifest_files(root):
    files = []
    for line in (root / 'SOURCE_SHA256SUMS').read_text().splitlines():
        expected, rel = line.split('  ', 1)
        parts = PurePosixPath(rel)
        if parts.is_absolute() or '..' in parts.parts:
            raise ValueError('Invalid source manifest path')
        path = root / rel
        if path.is_symlink() or digest(path) != expected:
            raise ValueError(f'Source checksum mismatch: {rel}')
        files.append(rel)
    if not files:
        raise ValueError('Empty source manifest')
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stimuli', type=Path, help='Source Stimuli directory; copied, never moved')
    parser.add_argument('--lab-root', type=Path, default=Path('/srv/hammerlab'))
    parser.add_argument('--data-root', type=Path, default=Path('/data'))
    parser.add_argument('--operator', default='laboperator')
    parser.add_argument('--group', default='hammerlab')
    parser.add_argument('--desktop-root', type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error('Run with sudo so the release and operator permissions can be installed')
    source = Path(__file__).resolve().parents[1]
    metadata = json.loads((source / 'DEPLOYMENT.json').read_text())
    name, release = metadata['paradigm'], metadata['release']
    assert name in ('MixEm', 'MusEm')
    assert '/' not in release and release not in ('.', '..')
    files = manifest_files(source)
    operator = pwd.getpwnam(args.operator)
    group = grp.getgrnam(args.group)
    lab_root, data_root = args.lab_root.resolve(), args.data_root.resolve()
    release_root = lab_root / 'paradigms' / name
    dest = release_root / 'releases' / release
    assets = data_root / 'stimuli' / name / 'snapshot-20261012'
    results = data_root / 'results' / name
    config = lab_root / 'config' / (name + '.env')
    desktop = args.desktop_root or Path(operator.pw_dir) / 'Desktop'
    # Detect path collisions before publishing a release or changing current.
    for folder in (dest.parent, results, config.parent, desktop):
        folder.mkdir(parents=True, exist_ok=True)
    if args.stimuli:
        import_assets(args.stimuli, assets, name)
        for path in [assets] + list(assets.rglob('*')):
            os.chown(path, 0, group.gr_gid)
            path.chmod(0o2750 if path.is_dir() else 0o640)
    try:
        git_command = ['git', '-c', f'safe.directory={source}', '-C', str(source), 'rev-parse']
        top = subprocess.check_output(git_command + ['--show-toplevel'],
                                      text=True, stderr=subprocess.DEVNULL).strip()
        if Path(top).resolve() != source:
            raise ValueError('Bundle is inside an unrelated Git checkout')
        commit = subprocess.check_output(git_command + ['HEAD'],
                                         text=True, stderr=subprocess.DEVNULL).strip()
    except (subprocess.CalledProcessError, FileNotFoundError, ValueError):
        commit = (source / 'GIT_COMMIT').read_text().strip()
    if len(commit) != 40 or any(c not in '0123456789abcdef' for c in commit):
        raise ValueError('A complete published Git commit is required')
    if dest.exists():
        for rel in files:
            if not (dest / rel).is_file() or digest(source / rel) != digest(dest / rel):
                raise ValueError(f'Release already exists with different content: {dest}. Use a new release.')
        if (dest / 'GIT_COMMIT').read_text().strip() != commit:
            raise ValueError('Existing release has different Git provenance; use a new release')
    else:
        stage = Path(tempfile.mkdtemp(prefix='.install-', dir=dest.parent))
        try:
            for rel in files:
                output = stage / rel
                output.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source / rel, output)
            (stage / 'GIT_COMMIT').write_text(commit + '\n')
            sums = [f'{digest(p)}  {p.relative_to(stage)}' for p in sorted(stage.rglob('*')) if p.is_file()]
            (stage / 'SHA256SUMS').write_text('\n'.join(sums) + '\n')
            for path in [stage] + list(stage.rglob('*')):
                os.chown(path, 0, group.gr_gid)
                executable = path.suffix == '.sh'
                path.chmod(0o2750 if path.is_dir() else 0o750 if executable else 0o640)
            os.rename(stage, dest)
        finally:
            if stage.exists():
                shutil.rmtree(stage)
    for folder in (results, config.parent, release_root, dest.parent):
        os.chown(folder, 0, group.gr_gid)
        folder.chmod(0o2770 if folder == results else 0o2750)
    # Parent traversal and a shared lock must work for the operator account.
    for folder in (data_root / 'stimuli', data_root / 'stimuli' / name):
        folder.mkdir(parents=True, exist_ok=True)
        os.chown(folder, 0, group.gr_gid); folder.chmod(0o2750)
    lock = data_root / 'results' / '.mixem-musem-session.lock'
    lock.touch(exist_ok=True); os.chown(lock, 0, group.gr_gid); lock.chmod(0o660)
    if not config.exists():
        config.write_text('\n'.join([
            '# Machine-specific settings; preserved on reinstall.',
            'HAMMER_RESULTS_ROOT=' + shlex.quote(str(results)),
            'HAMMER_STIMULI_ROOT=' + shlex.quote(str(assets)),
            'HAMMER_LOCK_FILE=' + shlex.quote(str(lock)),
            "HAMMER_TRIGGER_PORT='' # empty: exactly one Pico by-id is required",
            'HAMMER_TRIGGER_BAUD=115200', 'HAMMER_SKIP_SYNC_TESTS=0',
            "HAMMER_SCREEN_NUMBER='' # empty: highest Psychtoolbox screen number",
            "HAMMER_AUDIO_DEVICE='' # empty: default PsychPortAudio output",
            "HAMMER_MIC_DEVICE='' # empty: default audioDeviceReader input",
            "HAMMER_PYTHON='' # MixEm: optional compatible Python with StreamDeck packages",
            'HAMMER_MATLAB_BIN=/usr/local/MATLAB/R2024b/bin/matlab', '',
        ]))
        os.chown(config, 0, group.gr_gid); config.chmod(0o640)
    current = release_root / 'current'
    if current.exists() and not current.is_symlink():
        raise ValueError(f'Refusing to replace a non-symlink: {current}')
    link = release_root / f'.current-{os.getpid()}'
    link.symlink_to(dest)
    os.replace(link, current)
    commands = [('main','Spustit'),('preflight','Kontrola'),('devices','Zarizeni'),
                ('ff','Trigger FF'),('00','Trigger 00'),('results','Vysledky'),('instructions','Navod')]
    desktop.mkdir(parents=True, exist_ok=True)
    applications = (desktop.parent / '.local' / 'share' / 'applications') if not args.desktop_root else desktop / 'applications'
    applications.mkdir(parents=True, exist_ok=True)
    for directory in (desktop, applications):
        os.chown(directory, operator.pw_uid, group.gr_gid)
    for action, label in commands:
        text = ('[Desktop Entry]\nType=Application\n'
                f'Name={name} - {label}\n'
                f'Exec="{current}/scripts/run.sh" {action}\n'
                'Icon=applications-science\nTerminal=true\nCategories=Science;Education;\n')
        for directory in (desktop, applications):
            file = directory / f'{name}-{action}.desktop'
            file.write_text(text); file.chmod(0o750); os.chown(file, operator.pw_uid, group.gr_gid)
    print(f'CODE INSTALLED {name}: {dest}')
    print(f'CONFIG: {config} (existing settings preserved)')
    print('ASSETS: ' + ('IMPORTED AND VERIFIED' if args.stimuli else 'NOT IMPORTED IN THIS COMMAND'))
    print(f'NEXT: log in as {args.operator}; run {name} - Kontrola, then check hardware.')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Offline stimulus import and verification; Python standard library only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile


def sha256(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for data in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(data)
    return h.hexdigest()


def structure(root, paradigm):
    if not root.is_dir():
        raise ValueError(f'Missing stimulus directory: {root}')
    if paradigm == 'MusEm':
        requirements = [
            ('Imp/Practice - wav', '*.wav', 4),
            ('Imp/Subset Imp - wav', '*.wav', 40),
            ('Affect_Em/Practice - wav', '*.wav', 2),
            ('Affect_Em/Subset 1 - 40 - wav', '*.wav', 40),
            ('Affect_Em/Subset 2 - 40 - wav', '*.wav', 40),
        ]
        for rel in ['Imp/imp_rating_task_map.csv', 'Volume test/02 Piste 2.wav']:
            if not (root / rel).is_file():
                raise ValueError(f'Missing required stimulus metadata/audio: {rel}')
    else:
        requirements = [
            ('MAV_MEB_practice', '*.wav', 10), ('OASIS_practice', '*.jpg', 10),
            ('MAV_vocal_selection', '*.wav', 1), ('MEB_musical_selection', '*.wav', 1),
            ('MAV_vocal_other', '*.wav', 1), ('MEB_musical_other', '*.wav', 1),
            ('OASIS_person_selection', '*.jpg', 1), ('OASIS_os_selection', '*.jpg', 1),
            ('OASIS_person_other', '*.jpg', 1), ('OASIS_os_other', '*.jpg', 1),
            ('control_stimuli', 'control_tone_*.wav', 3),
            ('control_stimuli', 'control_grey_*.png', 3), ('vol_test', '*.wav', 1),
        ]
    for folder, pattern, minimum in requirements:
        count = sum(p.is_file() for p in (root / folder).glob(pattern))
        if count < minimum:
            raise ValueError(f'{folder}/{pattern}: need at least {minimum}, found {count}')


def inventory(root):
    entries = []
    for path in sorted(root.rglob('*')):
        rel = path.relative_to(root)
        if any(part.startswith('.') for part in rel.parts):
            continue
        if path.is_symlink():
            raise ValueError(f'Symbolic links in a stimulus export are unsupported: {rel}')
        if path.is_file():
            if rel.as_posix() == 'ASSETS.json':
                continue
            entries.append({'path': rel.as_posix(), 'bytes': path.stat().st_size,
                            'sha256': sha256(path)})
    return entries


def verify(root, paradigm):
    structure(root, paradigm)
    manifest = root / 'ASSETS.json'
    data = json.loads(manifest.read_text())
    if data.get('paradigm') != paradigm:
        raise ValueError('Manifest belongs to a different paradigm')
    if data['files'] != inventory(root):
        raise ValueError('Stimuli differ from ASSETS.json; restore or import a new version')
    print(f'ASSETS PASS {paradigm}: {len(data["files"])} files; manifest {sha256(manifest)}')


def import_assets(source, dest, paradigm):
    source = source.resolve()
    structure(source, paradigm)
    if dest.exists():
        verify(dest, paradigm)
        if inventory(source) != json.loads((dest / 'ASSETS.json').read_text())['files']:
            raise ValueError('Existing asset version differs from this source; use a new destination')
        print('Identical asset version already installed')
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.parent.resolve().is_relative_to(source):
        raise ValueError('Destination cannot be inside the stimulus source')
    files = inventory(source)
    stage = Path(tempfile.mkdtemp(prefix='.import-', dir=dest.parent))
    try:
        for entry in files:
            rel = entry['path']
            output = stage / rel
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / rel, output)
            if sha256(output) != entry['sha256']:
                raise ValueError(f'Source changed or transfer failed: {rel}')
        (stage / 'ASSETS.json').write_text(json.dumps(
            {'paradigm': paradigm, 'files': files}, indent=2, ensure_ascii=False) + '\n')
        verify(stage, paradigm)
        # os.rename will not replace a nonempty existing version.
        os.rename(stage, dest)
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['import', 'verify', 'check'])
    parser.add_argument('paradigm', choices=['MixEm', 'MusEm'])
    parser.add_argument('root', type=Path)
    parser.add_argument('--source', type=Path)
    args = parser.parse_args()
    if args.action == 'import':
        if args.source is None:
            parser.error('--source is required for import')
        import_assets(args.source, args.root, args.paradigm)
    elif args.action == 'verify':
        verify(args.root, args.paradigm)
    else:
        structure(args.root, args.paradigm)
        print('STRUCTURE PASS; complete filename and schedule validation runs in MATLAB preflight')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(2)

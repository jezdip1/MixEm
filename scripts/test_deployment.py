#!/usr/bin/env python3
"""Offline tests for import integrity and isolated installation behavior."""
import grp
import json
import os
from pathlib import Path
import pwd
import shutil
import subprocess
import tempfile
import unittest

from assets import import_assets, verify


def fake_assets(root):
    # Deliberately tiny synthetic files: these test transfer integrity, not audio.
    folders = {'Imp/Practice - wav': 4, 'Imp/Subset Imp - wav': 40,
               'Affect_Em/Practice - wav': 2, 'Affect_Em/Subset 1 - 40 - wav': 40,
               'Affect_Em/Subset 2 - 40 - wav': 40}
    for folder, count in folders.items():
        (root / folder).mkdir(parents=True)
        for n in range(count):
            (root / folder / f'{n}.wav').write_bytes(b'synthetic-integrity-fixture')
    (root / 'Imp/imp_rating_task_map.csv').write_text('Set,StimulusID,TaskType\n')
    (root / 'Volume test').mkdir()
    (root / 'Volume test/02 Piste 2.wav').write_bytes(b'fixture')


class Assets(unittest.TestCase):
    def test_import_verify_and_repeat(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); src = root / 'source'; dst = root / 'installed'
            fake_assets(src)
            import_assets(src, dst, 'MusEm')
            verify(dst, 'MusEm')
            import_assets(src, dst, 'MusEm')
            self.assertTrue((src / 'Imp/imp_rating_task_map.csv').exists())

    def test_corruption_and_changed_source_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); src = root / 'source'; dst = root / 'installed'
            fake_assets(src); import_assets(src, dst, 'MusEm')
            changed = src / 'Imp/Practice - wav/0.wav'
            changed.write_bytes(b'different version')
            with self.assertRaises(ValueError):
                import_assets(src, dst, 'MusEm')
            (dst / 'Imp/Practice - wav/0.wav').write_bytes(b'corrupt')
            with self.assertRaises(ValueError):
                verify(dst, 'MusEm')

    def test_missing_map_and_external_symlink_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); src = root / 'source'; fake_assets(src)
            mapping = src / 'Imp/imp_rating_task_map.csv'; mapping.unlink()
            with self.assertRaises(ValueError):
                import_assets(src, root / 'installed', 'MusEm')
            mapping.write_text('restored')
            (src / 'unexpected').symlink_to(root)
            with self.assertRaises(ValueError):
                import_assets(src, root / 'installed', 'MusEm')
            self.assertFalse((root / 'installed').exists())


@unittest.skipUnless(os.geteuid() == 0, 'Installer permission checks require root in isolated fixture')
class Installation(unittest.TestCase):
    def test_bundle_inside_unrelated_git_uses_bundle_identity(self):
        with tempfile.TemporaryDirectory(prefix='hammer-parent-git-test-') as tmp:
            tmp = Path(tmp); parent = tmp / 'other-repo'; parent.mkdir()
            subprocess.run(['git','init','-q',str(parent)],check=True)
            (parent/'seed').write_text('unrelated project')
            subprocess.run(['git','-C',str(parent),'add','.'],check=True)
            subprocess.run(['git','-C',str(parent),'-c','user.name=Fixture','-c',
                            'user.email=fixture@example.invalid','commit','-qm','Unrelated'],check=True)
            project = Path(__file__).resolve().parents[1]
            src = parent / 'bundle'
            shutil.copytree(project,src,ignore=shutil.ignore_patterns('.git','__pycache__'))
            expected = (src/'GIT_COMMIT').read_text().strip()
            name = json.loads((src/'DEPLOYMENT.json').read_text())['paradigm']
            command = ['python3',str(src/'scripts/install_lab.py'),
                       '--lab-root',str(tmp/'lab'),'--data-root',str(tmp/'data'),
                       '--operator',pwd.getpwuid(os.getuid()).pw_name,
                       '--group',grp.getgrgid(os.getgid()).gr_name,
                       '--desktop-root',str(tmp/'desktop')]
            run = subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(run.returncode,0,run.stdout+run.stderr)
            installed = tmp/'lab'/'paradigms'/name/'current'/'GIT_COMMIT'
            self.assertEqual(installed.read_text().strip(),expected)

    def test_install_reinstall_launch_and_tamper(self):
        with tempfile.TemporaryDirectory(prefix='hammer-install-test-') as tmp:
            tmp = Path(tmp); src = tmp / 'source'
            project = Path(__file__).resolve().parents[1]
            shutil.copytree(project, src, ignore=shutil.ignore_patterns('.git','__pycache__'))
            subprocess.run(['git','init','-q',str(src)],check=True)
            subprocess.run(['git','-C',str(src),'add','.'],check=True)
            subprocess.run(['git','-C',str(src),'-c','user.name=Fixture','-c',
                            'user.email=fixture@example.invalid','commit','-qm','Fixture'],check=True)
            name = json.loads((src/'DEPLOYMENT.json').read_text())['paradigm']
            operator = pwd.getpwuid(os.getuid()).pw_name
            group = grp.getgrgid(os.getgid()).gr_name
            command = ['python3',str(src/'scripts/install_lab.py'),
                       '--lab-root',str(tmp/'lab'),'--data-root',str(tmp/'data'),
                       '--operator',operator,'--group',group,'--desktop-root',str(tmp/'desktop')]
            first = subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(first.returncode,0,first.stdout+first.stderr)
            current = tmp/'lab'/'paradigms'/name/'current'
            self.assertTrue(current.is_symlink())
            subprocess.run(command,check=True,capture_output=True)
            config = tmp/'lab'/'config'/(name+'.env')
            mock_matlab = tmp/'matlab'
            mock_matlab.write_text('#!/usr/bin/env python3\nimport json,os,sys\n'
                                  'json.dump({"args":sys.argv[1:],"mode":os.getenv("MUSEM_AUTOPILOT")},'
                                  'open(os.environ["MOCK_OUTPUT"],"w"))\n')
            mock_matlab.chmod(0o755)
            with config.open('a') as stream:
                stream.write(f'HAMMER_MATLAB_BIN={mock_matlab}\n')
            env = dict(os.environ,HAMMER_CONFIG_FILE=str(config),MOCK_OUTPUT=str(tmp/'launch.json'))
            run = subprocess.run([str(current/'scripts/run.sh'),'devices'],env=env,
                                 capture_output=True,text=True)
            self.assertEqual(run.returncode,0,run.stdout+run.stderr)
            capture = json.loads((tmp/'launch.json').read_text())
            self.assertIn('-desktop',capture['args'])
            self.assertNotIn('-nojvm',capture['args'])
            self.assertEqual(capture['mode'],'0')
            # Main must stop before calling MATLAB when the stimuli have not been imported.
            (tmp/'launch.json').unlink()
            run = subprocess.run([str(current/'scripts/run.sh'),'main'],env=env,capture_output=True)
            self.assertNotEqual(run.returncode,0)
            self.assertFalse((tmp/'launch.json').exists())
            # Altered installed code is rejected even for device inventory.
            changed = current/'+hammer/number.m'
            changed.write_text(changed.read_text()+'\n% changed\n')
            run = subprocess.run([str(current/'scripts/run.sh'),'devices'],env=env,capture_output=True)
            self.assertNotEqual(run.returncode,0)
            self.assertFalse((tmp/'launch.json').exists())
            repeat = subprocess.run(command,capture_output=True)
            self.assertNotEqual(repeat.returncode,0)


if __name__ == '__main__':
    unittest.main(verbosity=2)

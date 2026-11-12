import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from backup_setup import setup

class SetupTests(unittest.TestCase):
    def test_profile_and_launcher_are_portable_and_idempotent(self):
        with tempfile.TemporaryDirectory(prefix='gg setup ') as t:
            root=Path(t);mod=root/'Mod With Spaces';(mod/'tools').mkdir(parents=True)
            (mod/'config.lua').write_text('return {}');(mod/'backup-version.txt').write_text('test')
            (mod/'tools/backup_session.py').write_text('pass')
            saves=root/'Saved/SaveGames';saves.mkdir(parents=True)
            launcher,profile=setup(mod,saves)
            data=json.loads(profile.read_text())
            self.assertEqual(data['quiet_seconds'],120)
            self.assertEqual(Path(data['destination']),saves.parent/'GrowingGroundsBackups')
            self.assertIn('sys.argv[1:]',launcher.read_text())
            self.assertIn('--setenv=',launcher.read_text())
            self.assertEqual(setup(mod,saves),(launcher,profile))
            self.assertTrue(launcher.stat().st_mode & 0o100)
            self.assertEqual(list(saves.iterdir()),[])
            compile(launcher.read_text(),str(launcher),'exec')

if __name__=='__main__':unittest.main()

import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from contextlib import contextmanager

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
import backup_windows as session
import backup_policy
import save_backup
from backup_control import Cancelled, cancellable
from backup_win32 import GAME


class FakeWin:
    def __init__(self):
        self.cancelled = False;self.running = False;self.code = 0;self.creation = 12
        self.waits = [];self.on_wait = lambda handles, ms: None
    def open_process(self, pid): return 'process'
    def created(self, handle): return self.creation
    def image(self, handle): return Path('Palworld-Win64-Shipping.exe')
    def event(self, name): return 'cancel'
    def background(self): pass
    def close(self, handle): pass
    def exit_code(self, handle): return self.code
    def game_running(self): return self.running
    @contextmanager
    def gate(self, name): yield
    def wait(self, handles, ms):
        self.waits.append((handles, ms));self.on_wait(handles, ms)
        if self.cancelled: return 0
        return 1 if len(handles) == 2 else 258


class WindowsTests(unittest.TestCase):
    def test_shipping_console_server_and_its_save_root(self):
        for name in ('Palworld-Win64-Shipping.exe', 'Palworld-WinGDK-Shipping.exe',
                     'PalServer-Win64-Shipping.exe', 'PalServer-Win64-Shipping-Cmd.exe'):
            self.assertIsNotNone(GAME.fullmatch(name))
        self.assertIsNone(GAME.fullmatch('Palworld-helper.exe'))
        game = self.root/'server/Pal/Binaries/Win64/PalServer-Win64-Shipping-Cmd.exe'
        save, archives, state = session.paths(game, self.mod)
        self.assertEqual(save, self.root/'server/Pal/Saved/SaveGames')

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name);self.mod = self.root/'mod';self.mod.mkdir()
        (self.mod/'config.lua').write_text('return {}')
        self.save = self.root/'Saved/SaveGames';self.world = self.save/'account'/('A'*32)
        self.world.mkdir(parents=True)
        (self.world/'Level.sav').write_bytes(b'world'*100)
        (self.world/'LevelMeta.sav').write_bytes(b'meta')
        self.dest = self.root/'Saved/GrowingGroundsBackups'
        self.path = self.root/'job.json';self.win = FakeWin()
        self.job = {'token': 'f'*32, 'pid': 100, 'created': 12, 'game': str(self.win.image(None)),
                    'save_root': str(self.save), 'mod': str(self.mod), 'destination': str(self.dest),
                    'quiet_seconds': 120, 'version': 'test'}
        session.atomic(self.path, self.job)
    def watch(self): return session.watch(self.path, self.job['token'], self.win)

    def test_no_archive_until_clean_exit_and_full_quiet_period(self):
        with patch.object(session.backup_policy, 'automatic_once', wraps=backup_policy.automatic_once) as archive:
            self.win.on_wait = lambda handles, ms: archive.assert_not_called() if ms else None
            self.assertEqual(self.watch(), 'idle')
            archive.assert_called_once()
        self.assertEqual(self.win.waits[:2], [(['cancel','process'], 0xFFFFFFFF), (['cancel'], 120000)])
        files = list(self.dest.glob('*.zip'));self.assertEqual(len(files), 1)
        self.assertEqual(save_backup.verify(files[0])['kind'], 'baseline')
        result = self.root/'restored';save_backup.restore_copy(files[0], result)
        self.assertEqual((result/'world/Level.sav').read_bytes(), (self.world/'Level.sav').read_bytes())
        self.assertLess(sum(p.stat().st_size for p in self.dest.iterdir()), 1024**3)

    def test_crash_never_creates_archive(self):
        self.win.code = 0xC0000005
        with patch.object(session.backup_policy, 'automatic_once') as archive:
            self.assertEqual(self.watch(), 'unclean');archive.assert_not_called()
        self.assertEqual(len(self.win.waits), 1)

    def test_quick_relaunch_cancels_quiet_window(self):
        def relaunch(handles, ms):
            if ms == 120000:self.win.cancelled = True
        self.win.on_wait = relaunch
        with patch.object(session.backup_policy, 'automatic_once') as archive:
            self.assertEqual(self.watch(), 'cancelled');archive.assert_not_called()
        self.assertFalse(self.dest.exists())

    def test_another_game_before_lua_startup_also_cancels(self):
        self.win.running = True
        with patch.object(session.backup_policy, 'automatic_once') as archive:
            self.assertEqual(self.watch(), 'cancelled');archive.assert_not_called()

    def test_superseded_job_or_reused_pid_never_reads_save(self):
        with patch.object(session, 'worlds') as discover:
            self.assertEqual(session.watch(self.path, 'old-token', self.win), 'superseded')
            self.win.creation = 13
            with self.assertRaisesRegex(ValueError, 'identity changed'):self.watch()
            discover.assert_not_called()

    def test_only_authoritative_worlds_and_one_shared_budget(self):
        remote = self.save/'account'/('B'*32);remote.mkdir();(remote/'LocalData.sav').write_bytes(b'cache')
        self.assertEqual(session.worlds(self.save), [self.world])
        with self.assertRaisesRegex(ValueError, 'policy'):
            backup_policy.automatic_once(self.world,self.mod,self.dest,stopped=True,policy={'max_bytes':1024**3+1})

    def test_cancel_during_write_discards_partial_and_keeps_last_good(self):
        baseline = backup_policy.automatic_once(self.world,self.mod,self.dest,stopped=True)['archive']
        original = Path(baseline).read_bytes()
        (self.world/'Level.sav').write_bytes(os.urandom(3*1024*1024))
        def check():
            if any(p.stat().st_size > 1024*1024 for p in self.dest.glob('*.partial')):
                raise Cancelled('relaunch')
        with cancellable(check), self.assertRaises(Cancelled):
            save_backup.create(self.world,self.mod,self.dest,stopped=True)
        self.assertEqual(Path(baseline).read_bytes(), original)
        self.assertFalse(list(self.dest.glob('*.partial')))
        self.assertEqual(len(list(self.dest.glob('*.zip'))), 1)

    def test_cancel_is_not_swallowed_as_an_unverified_archive(self):
        backup_policy.automatic_once(self.world,self.mod,self.dest,stopped=True)
        with cancellable(lambda: None):
            with patch('save_backup.checkpoint', side_effect=Cancelled('relaunch')):
                with self.assertRaises(Cancelled):backup_policy.scan(self.dest)


if __name__ == '__main__':unittest.main()

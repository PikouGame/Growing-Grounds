import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parents[1]/'tools'))
import backup_session as session


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.path = root/'profile.json'
        self.path.write_text(json.dumps({'session_unit': 'test-game', 'backup_unit': 'test-archive',
            'state': str(root/'state'), 'destination': str(root/'archives'),
            'mod': str(root/'mod'), 'worlds': [str(root/('A'*32))], 'version': 'test'}))
        self.profile = session.load_profile(self.path)

    def ready(self, **kwargs):
        session.write_state(self.profile, dict(status='waiting-for-quiet', clean_exit=True,
                                              eligible_at=0, **kwargs))

    def test_worker_never_archives_active_session(self):
        self.ready()
        with session.session_lock(self.profile), patch.object(session.backup_policy, 'automatic_once') as archive:
            self.assertEqual(session.worker(self.path)['status'], 'session-active')
            archive.assert_not_called()
        with patch.object(session, 'inactive', return_value=False), patch.object(session.backup_policy, 'automatic_once') as archive:
            self.assertEqual(session.worker(self.path)['status'], 'not-eligible')
            archive.assert_not_called()

    def test_quiet_window_and_clean_exit_required(self):
        for status in ({'status': 'waiting-for-quiet', 'clean_exit': True, 'eligible_at': time.time()+120},
                       {'status': 'unclean-exit-no-backup', 'clean_exit': False, 'eligible_at': 0}):
            session.write_state(self.profile, status)
            with patch.object(session.backup_policy, 'automatic_once') as archive:
                self.assertEqual(session.worker(self.path)['status'], 'not-eligible')
                archive.assert_not_called()

    def test_eligible_worker_runs_once_after_shutdown(self):
        self.ready()
        with patch.object(session, 'inactive', return_value=True), patch.object(
                session.backup_policy, 'automatic_once', return_value={'status': 'created'}) as archive:
            self.assertEqual(session.worker(self.path)['status'], 'idle')
            self.assertTrue(archive.call_args.kwargs['stopped'])
            self.assertEqual(session.worker(self.path)['status'], 'not-eligible')
            self.assertEqual(archive.call_count, 1)

    def test_launcher_cancels_pending_and_holds_lock_until_clean_exit(self):
        events = []
        def cancel(_): events.append('cancel')
        def child(_command):
            events.append('child')
            with self.assertRaises(BlockingIOError), session.session_lock(self.profile):
                pass
            return subprocess.Popen([sys.executable, '-c', 'pass'])
        actual_popen = subprocess.Popen
        def fake_popen(command, **kwargs):
            self.assertEqual(kwargs['env']['GG_BACKUP_MANAGED'], '1')
            with patch.object(subprocess, 'Popen', actual_popen):
                return child(command)
        with (patch.object(session, 'cancel_pending', cancel),
              patch.object(session, 'baselines_before_first_launch'),
              patch.object(session, 'schedule') as schedule,
              patch.object(session.subprocess, 'Popen', fake_popen)):
            self.assertEqual(session.launch(self.path, ['placeholder']), 0)
            schedule.assert_called_once()
        self.assertEqual(events, ['cancel', 'child'])

    def test_failed_process_does_not_schedule_archive(self):
        with (patch.object(session, 'cancel_pending'),
              patch.object(session, 'baselines_before_first_launch'),
              patch.object(session, 'schedule') as schedule):
            self.assertEqual(session.launch(self.path, [sys.executable, '-c', 'raise SystemExit(3)']), 3)
            schedule.assert_not_called()

    def test_new_worlds_discovered_but_server_client_cache_excluded(self):
        root = self.profile['state'].parent/'SaveGames'
        world = root/'account'/('B'*32)
        world.mkdir(parents=True)
        (world/'Level.sav').write_bytes(b'world')
        cache = root/'account'/('C'*32)
        cache.mkdir(); (cache/'LocalData.sav').write_bytes(b'client-cache')
        self.profile['save_root'] = root
        self.assertIn(world, session.worlds(self.profile))
        self.assertNotIn(cache, session.worlds(self.profile))

    def test_existing_baseline_avoids_startup_hashing(self):
        self.profile['destination'].mkdir()
        world = self.profile['worlds'][0]
        (self.profile['destination']/f'gg-{world.name}-baseline-known.zip').write_bytes(b'existing')
        manifest = {'world_id': world.name, 'kind': 'baseline'}
        with (patch.object(session.backup_policy, 'automatic_once') as archive,
              patch.object(session.backup_policy.archive, 'verify', return_value=manifest) as verify):
            session.baselines_before_first_launch(self.profile)
            session.baselines_before_first_launch(self.profile)
            archive.assert_not_called()
            self.assertEqual(verify.call_count, 1)


if __name__ == '__main__':
    unittest.main()

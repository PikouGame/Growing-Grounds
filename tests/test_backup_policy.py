import importlib.util
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).parents[1]/'tools'
sys.path.insert(0, str(TOOLS))
import backup_policy as policy


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.world, self.mod, self.dest = self.root/('A'*32), self.root/'mod', self.root/'archives'
        self.world.mkdir(); self.mod.mkdir()
        (self.world/'Level.sav').write_bytes(b'world')
        (self.world/'LevelMeta.sav').write_bytes(b'meta')
        (self.mod/'config.lua').write_bytes(b'config')

    def once(self, **kwargs):
        return policy.automatic_once(self.world, self.mod, self.dest, stopped=True, **kwargs)

    def test_relaunch_cooldown_persists_and_unchanged_save_is_skipped(self):
        first = self.once()
        self.assertTrue(first['archive_created'])
        m = policy.archive.verify(first['archive'])
        created = datetime.fromisoformat(m['created_utc'])
        for minute in (1, 2, 5, 10, 29):
            self.assertEqual(self.once(now=created+timedelta(minutes=minute))['status'], 'cooldown')
        self.assertEqual(self.once(now=created+timedelta(hours=1))['status'], 'unchanged')
        self.assertEqual(len(list(self.dest.glob('*.zip'))), 1)
        (self.world/'Level.sav').write_bytes(b'changed-world')
        self.assertEqual(self.once(now=created+timedelta(hours=1))['status'], 'created')

    def test_budget_and_free_space_preserve_baseline_and_last_good_copy(self):
        first = self.once()
        original = Path(first['archive']).read_bytes()
        (self.world/'Level.sav').write_bytes(b'changed')
        for override in ({'max_bytes': 1}, {'reserve_bytes': 10**18}):
            result = self.once(now=datetime.now(timezone.utc)+timedelta(hours=1), policy=override)
            self.assertEqual(result['status'], 'storage-limit')
            self.assertEqual(Path(first['archive']).read_bytes(), original)
        self.assertFalse(list(self.dest.glob('*.partial')))

    def test_daily_copies_are_shared_with_recent_not_duplicated(self):
        now = datetime(2026, 11, 11, 20, tzinfo=timezone.utc)
        records = []
        for day in range(10):
            for hour in (1, 2, 3, 4):
                records.append({'path': Path(f'{day}-{hour}.zip'),
                                'time': now-timedelta(days=day, hours=hour),
                                'manifest': {'world_id': 'A'*32, 'kind': 'rolling'}})
        baseline = {'path': Path('baseline.zip'), 'time': now-timedelta(days=20),
                    'manifest': {'world_id': 'A'*32, 'kind': 'baseline'}}
        records.append(baseline)
        keep = policy.retained(records, now, policy.DEFAULTS)
        self.assertEqual(len(keep), 11)  # Three recent + seven days + baseline.
        self.assertIn(baseline['path'], keep)
        self.assertIn(Path('7-1.zip'), keep)
        self.assertNotIn(Path('8-1.zip'), keep)
        self.assertNotIn(Path('1-4.zip'), keep)

    def test_clock_rollback_does_not_cause_backup_storm(self):
        self.once()
        result = self.once(now=datetime(2000, 1, 1, tzinfo=timezone.utc))
        self.assertEqual(result['status'], 'clock-moved-backwards')
        self.assertEqual(len(list(self.dest.glob('*.zip'))), 1)

    def test_missing_baseline_is_created_even_after_an_unchanged_rolling_copy(self):
        rolling = Path(policy.archive.create(self.world, self.mod, self.dest,
                                            stopped=True)['archive'])
        original = rolling.read_bytes()
        created = datetime.fromisoformat(policy.archive.verify(rolling)['created_utc'])
        for minutes in (1, 60):
            with self.subTest(minutes=minutes):
                result = self.once(now=created+timedelta(minutes=minutes))
                self.assertEqual(result['status'], 'created')
                baseline = Path(result['archive'])
                self.assertEqual(policy.archive.verify(baseline)['kind'], 'baseline')
                self.assertEqual(rolling.read_bytes(), original)
                baseline.unlink()  # Model a missing baseline at both eligibility times.

    def test_corrupt_baseline_is_reported_before_cooldown_or_unchanged_skip(self):
        rolling = policy.archive.create(self.world, self.mod, self.dest, stopped=True)['archive']
        created = datetime.fromisoformat(policy.archive.verify(rolling)['created_utc'])
        bad = self.dest/f'gg-{self.world.name}-baseline-corrupt.zip'
        bad.write_bytes(b'broken')
        for minutes in (1, 60):
            with self.subTest(minutes=minutes):
                result = self.once(now=created+timedelta(minutes=minutes))
                self.assertEqual(result['status'], 'baseline-needs-attention')
                self.assertFalse(result['archive_created'])
        self.assertEqual(bad.read_bytes(), b'broken')
        self.assertEqual(len(list(self.dest.glob('*.zip'))), 2)


if __name__ == '__main__':
    unittest.main()

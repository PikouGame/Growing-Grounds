"""Archive safety tests; fixtures do not establish in-game restore compatibility."""
import importlib.util
import json
from pathlib import Path
import tempfile
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('backup', Path(__file__).parents[1]/'tools/save_backup.py')
backup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup)


class BackupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.world = self.root/('A'*32)
        (self.world/'Players').mkdir(parents=True)
        (self.world/'Level.sav').write_bytes(b'compressed-world\0'*3000)
        (self.world/'LevelMeta.sav').write_bytes(b'world-metadata')
        (self.world/'Players'/'player.sav').write_bytes(b'player-data')
        (self.world/'backup').mkdir()
        (self.world/'backup'/'old.sav').write_bytes(b'excluded-native-rotation')
        self.mod = self.root/'BaseRangeGrowth'
        self.mod.mkdir()
        (self.mod/'config.lua').write_text('return {maxPalboxBonusPages=32}')
        (self.mod/'world-settings.ini').write_text('[world]\nvalue=32\n')
        self.dest = self.root/'archives'

    def create(self, **kwargs):
        return Path(backup.create(self.world, self.mod, self.dest, stopped=True, **kwargs)['archive'])

    def rewrite(self, archive, mutate):
        with zipfile.ZipFile(archive) as z:
            entries = {n: z.read(n) for n in z.namelist()}
        mutate(entries)
        with zipfile.ZipFile(archive, 'w') as z:
            for n, data in entries.items():
                z.writestr(n, data)

    def test_roundtrip_full_world_and_settings(self):
        archive = self.create(kind='baseline')
        m = backup.verify(archive)
        self.assertEqual(len(m['files']), 5)
        self.assertFalse(any('/backup/' in n for n in m['files']))
        target = self.root/'restored'
        backup.restore_copy(archive, target)
        for name in m['files']:
            group, rel = name.split('/', 1)
            source = (self.world if group == 'world' else self.mod)/rel
            self.assertEqual(source.read_bytes(), (target/name).read_bytes())
        self.assertFalse((target/'RESTORE-INCOMPLETE.txt').exists())
        with self.assertRaisesRegex(ValueError, 'must not exist'):
            backup.restore_copy(archive, target)

    def test_retention_protects_baseline_other_world_and_unknown_files(self):
        baseline = self.create(kind='baseline', keep=2)
        other = self.dest/('gg-'+'B'*32+'-rolling-unknown.zip')
        other.write_bytes(b'foreign-world')
        unknown = self.dest/'personal.zip'
        unknown.write_bytes(b'personal')
        rolling = [self.create(keep=2) for _ in range(4)]
        self.assertTrue(baseline.exists() and other.exists() and unknown.exists())
        self.assertEqual([p.exists() for p in rolling], [False, False, True, True])
        with self.assertRaisesRegex(ValueError, 'baseline already exists'):
            self.create(kind='baseline')

    def test_incomplete_client_cache_refused(self):
        (self.world/'Level.sav').unlink()
        with self.assertRaisesRegex(ValueError, 'complete world'):
            self.create()
        self.assertFalse(list(self.dest.glob('*.zip')))

    def test_requires_offline_source_and_external_destination(self):
        with self.assertRaisesRegex(ValueError, 'Stop the game'):
            backup.create(self.world, self.mod, self.dest)
        for inside in (self.world/'archives', self.mod/'archives'):
            with self.assertRaisesRegex(ValueError, 'outside'):
                backup.create(self.world, self.mod, inside, stopped=True)

    def test_corruption_refuses_restore_and_rotation_preserves_bad_archive(self):
        archive = self.create(keep=1)
        self.rewrite(archive, lambda e: e.update({'world/Level.sav': b'corrupt'}))
        with self.assertRaisesRegex(ValueError, 'mismatch'):
            backup.restore_copy(archive, self.root/'corrupt-restore')
        self.assertFalse((self.root/'corrupt-restore').exists())
        result = backup.create(self.world, self.mod, self.dest, stopped=True, keep=1)
        self.assertTrue(archive.exists())
        self.assertEqual(len(result['warnings']), 1)

    def test_unsafe_manifest_paths_and_extra_entries_refused(self):
        archive = self.create()
        def mutate(entries):
            m = json.loads(entries['manifest.json'])
            data = entries.pop('world/Level.sav')
            m['files']['world/../../escape'] = m['files'].pop('world/Level.sav')
            entries['world/../../escape'] = data
            entries['manifest.json'] = json.dumps(m).encode()
        self.rewrite(archive, mutate)
        with self.assertRaises(ValueError):
            backup.restore_copy(archive, self.root/'unsafe')
        self.assertFalse((self.root/'escape').exists())
        for name in ('world/../escape', 'world/C:escape', 'world/CON.sav', 'world/a\\b', 'world/a.'):
            with self.assertRaises(ValueError):
                backup.safe_name(name)

    def test_source_changes_fail_without_publishing_or_pruning(self):
        existing = self.create(keep=1)
        original, calls = backup.inventory, 0
        def changed(world, mod):
            nonlocal calls
            calls += 1
            if calls == 2:
                (world/'Players'/'late-player.sav').write_bytes(b'late-save')
            return original(world, mod)
        with patch.object(backup, 'inventory', changed):
            with self.assertRaisesRegex(ValueError, 'changed'):
                self.create(keep=1)
        self.assertEqual(list(self.dest.glob('*.zip')), [existing])
        self.assertFalse(list(self.dest.glob('*.partial')))
        with backup.locked(self.dest):
            pass  # A failed write must release the OS lock.

    def test_write_failure_preserves_previous_backup(self):
        existing = self.create(keep=1)
        with patch.object(backup.zipfile.ZipFile, 'writestr', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                self.create(keep=1)
        self.assertEqual(list(self.dest.glob('*.zip')), [existing])
        backup.verify(existing)

    def test_archive_size_limit_is_enforced_while_writing(self):
        existing = self.create(keep=1)
        with self.assertRaisesRegex(ValueError, 'budget exceeded'):
            self.create(keep=1, max_archive_bytes=100)
        self.assertEqual(list(self.dest.glob('*.zip')), [existing])
        self.assertFalse(list(self.dest.glob('*.partial')))

    def test_lock_and_symbolic_links_refused(self):
        self.dest.mkdir()
        with backup.locked(self.dest), self.assertRaises(OSError):
            self.create()
        try:
            (self.world/'linked.sav').symlink_to(self.world/'Level.sav')
        except OSError:
            self.skipTest('Host does not allow symlinks')
        with self.assertRaisesRegex(ValueError, 'regular files'):
            self.create()

    def test_interrupted_restore_keeps_a_marked_copy_and_preserves_archive(self):
        archive = self.create()
        original = archive.read_bytes()
        destination = self.root/'interrupted'
        rename = backup.os.rename
        def interrupted(source, target):
            if Path(target).name == 'settings':
                raise OSError('restore interrupted')
            return rename(source, target)
        with patch.object(backup.os, 'rename', interrupted):
            with self.assertRaisesRegex(OSError, 'restore interrupted'):
                backup.restore_copy(archive, destination)
        self.assertTrue((destination/'RESTORE-INCOMPLETE.txt').is_file())
        self.assertEqual((destination/'world/Level.sav').read_bytes(), (self.world/'Level.sav').read_bytes())
        self.assertEqual(archive.read_bytes(), original)
        self.assertFalse(list(self.root.glob('.gg-restore-*')))


if __name__ == '__main__':
    unittest.main()

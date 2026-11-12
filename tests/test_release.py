"""Distribution checks use temporary outputs; they never install or publish a mod."""
from pathlib import Path
import runpy
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

TOOLS = Path(__file__).resolve().parents[1]/'tools'
sys.path.insert(0, str(TOOLS))
import release


class ReleaseTests(unittest.TestCase):
    def test_inspection_does_not_build_or_require_runtime_download(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root/'tools').mkdir()
            script = root/'tools/release.py'
            shutil.copyfile(TOOLS/'release.py', script)
            runpy.run_path(str(script))
            self.assertFalse((root/'build').exists())

    def test_all_loaded_lua_python_and_dynamic_icons_must_ship(self):
        release.validate_sources(release.ROOT)
        for missing in ('src/ring.lua', 'tools/backup_control.py', 'assets/palbox-bonus.png'):
            with self.subTest(missing=missing), patch.object(
                    release, 'RUNTIME', [p for p in release.RUNTIME if p != missing]):
                with self.assertRaisesRegex(ValueError, 'Loaded at runtime'):
                    release.validate_sources(release.ROOT)

    def test_allowlist_and_both_archive_formats_are_reproducible(self):
        # Tiny runtime fixture tests the package recipe; a real pinned-runtime
        # build remains a separate validation, not a claim about these bytes.
        runtime = {'backup/python/python.exe': b'fixture-exe',
                   'backup/python/LICENSE.txt': b'fixture-license'}
        with tempfile.TemporaryDirectory() as folder, patch.object(
                release.backup_runtime, 'entries', return_value=runtime):
            build = Path(folder)
            first = release.build_release(build=build)
            before = {item['file']: (build/item['file']).read_bytes() for item in first['archives']}
            second = release.build_release(build=build)
            self.assertEqual(first, second)
            expected = set(release.RUNTIME+release.DOCS) | set(runtime) | {'backup/runtime-provenance.json'}
            for item in second['archives']:
                self.assertEqual((build/item['file']).read_bytes(), before[item['file']])
                with zipfile.ZipFile(build/item['file']) as z:
                    if item['file'].endswith('-workshop.zip'):
                        self.assertEqual(set(z.namelist()), expected | {'Info.json', 'thumbnail.png'})
                    else:
                        self.assertEqual(set(z.namelist()), {'BaseRangeGrowth/'+n for n in expected})
            rules = release.workshop_info()['InstallRule']
            self.assertEqual([r.get('IsServer', False) for r in rules], [False, True])
            self.assertFalse(second['workshop_deployment_verified'])


if __name__ == '__main__':
    unittest.main()

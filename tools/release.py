"""Create deterministic, allowlisted release archives for manual and Workshop use."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import zipfile
import backup_runtime

ROOT = Path(__file__).resolve().parents[1]
VERSION = '0.2.0-beta'
RUNTIME = [
    'enabled.txt', 'config.lua', 'Scripts/main.lua',
    'src/backups.lua', 'backup-version.txt',
    'tools/save_backup.py', 'tools/backup_policy.py', 'tools/backup_control.py',
    'tools/backup_win32.py', 'tools/backup_windows.py',
    'tools/backup_session.py', 'tools/backup_setup.py',
    'src/range.lua', 'src/runtime.lua', 'src/ui.lua',
    'src/settings.lua', 'src/world_settings.lua',
    'src/storage.lua', 'src/palbox.lua', 'src/chest_ui.lua',
    'src/preview.lua', 'src/objects.lua', 'src/changes.lua',
    'src/motion.lua', 'src/boundary.lua', 'src/ring.lua', 'src/ribbon.lua', 'src/wave.lua',
    'src/texts.lua', 'src/language.lua',
    'assets/base-range.svg', 'assets/base-range.png',
    'assets/chest-bonus.svg', 'assets/chest-bonus.png',
    'assets/palbox-bonus.svg', 'assets/palbox-bonus.png',
    'assets/contour-gradient.svg', 'assets/contour-gradient.png',
    'assets/ground-wave.svg', 'assets/ground-wave.png',
]
DOCS = ['INSTALL.txt', 'LICENSE.txt', 'README.md', 'BACKUPS.txt']
BUILD = ROOT / 'build'
BUILD.mkdir(exist_ok=True)


def archive(name, entries):
    output = BUILD / name
    with zipfile.ZipFile(output, 'w') as z:
        for dest, data in sorted(entries.items()):
            entry = zipfile.ZipInfo(dest, (2026, 11, 8, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            z.writestr(entry, data)
    with zipfile.ZipFile(output) as z:
        assert z.testzip() is None
        assert set(z.namelist()) == set(entries)
        for name, data in entries.items():
            assert z.read(name) == data
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(f'{digest}  {output.name}\n')
    print(output.name, digest)
    return {'file': output.name, 'sha256': digest, 'files': len(entries)}


# Reject accidental reintroduction of developer keyboard controls.
for name in RUNTIME:
    if name.endswith('.lua'):
        assert 'RegisterKeyBind' not in (ROOT / name).read_text(), name
assert VERSION in (ROOT / 'Scripts/main.lua').read_text()
assert (ROOT/'backup-version.txt').read_text().strip() == VERSION
# Every module and image the runtime loads must ship: one left out breaks the mod at load.
loaded = set()
for name in RUNTIME:
    if name.endswith('.lua'):
        loaded.update(re.findall(r"'((?:src|assets)/[\w-]+\.(?:lua|png))'", (ROOT / name).read_text()))
missing = sorted(loaded - set(RUNTIME))
assert not missing, f'loaded at runtime but not in the archive: {missing}'

files = {name: (ROOT / name).read_bytes() for name in RUNTIME + DOCS}
files.update(backup_runtime.entries())
files['backup/runtime-provenance.json'] = (json.dumps(backup_runtime.provenance(), indent=2)+'\n').encode()
manual = {'BaseRangeGrowth/'+name: data for name, data in files.items()}
receipts = [archive(f'Growing-Grounds-{VERSION}.zip', manual)]

# Both rules are required: the dedicated server uses IsServer=true rules.
# Verify the dependency package name in the installed UE4SS Workshop Info.json
# before upload; the Steam route has not been tested on this development setup.
targets = ['./Scripts', './src', './assets', './tools', './backup',
           './config.lua', './enabled.txt', './backup-version.txt']
info = {
    'ModName': 'Growing Grounds', 'PackageName': 'BaseRangeGrowth',
    'Thumbnail': 'thumbnail.png', 'Version': VERSION, 'DebugMode': False,
    'MinRevision': 102999, 'Author': 'lelorax',
    'Dependencies': ['UE4SSExperimentalPW'],
    'Tags': ['UE4SS', 'Gameplay', 'User Interface'],
    'InstallRule': [
        {'Type': 'Lua', 'Targets': targets},
        {'Type': 'Lua', 'IsServer': True, 'Targets': targets},
    ],
}
workshop = dict(files)
workshop['Info.json'] = (json.dumps(info, indent=2) + '\n').encode()
workshop['thumbnail.png'] = (ROOT / 'assets/screenshots/base-range-level8.png').read_bytes()
stage = BUILD / f'workshop-{VERSION}'
if stage.exists():
    shutil.rmtree(stage)
stage.mkdir()
for name, data in workshop.items():
    path = stage / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
for rule in info['InstallRule']:
    assert all((stage / target).exists() for target in rule['Targets'])
receipts.append(archive(f'Growing-Grounds-{VERSION}-workshop.zip', workshop))
(BUILD / 'release-manifest.json').write_text(json.dumps({
    'version': VERSION, 'archives': receipts,
    'workshop_deployment_verified': False,
    'runtime_sha256': {name: hashlib.sha256(data).hexdigest()
                       for name, data in files.items() if name not in DOCS},
    'backup_runtime': backup_runtime.provenance(),
}, indent=2) + '\n')

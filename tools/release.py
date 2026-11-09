"""Create deterministic, allowlisted alpha archives for manual and Workshop use."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '0.1.4-alpha'
RUNTIME = [
    'enabled.txt', 'config.lua', 'Scripts/main.lua',
    'src/range.lua', 'src/runtime.lua', 'src/ui.lua',
    'src/settings.lua', 'src/world_settings.lua',
    'src/storage.lua',
    'src/preview.lua', 'src/objects.lua', 'src/changes.lua',
    'src/motion.lua', 'src/boundary.lua', 'src/ring.lua', 'src/ribbon.lua', 'src/wave.lua',
    'assets/base-range.svg', 'assets/base-range.png',
    'assets/contour-gradient.svg', 'assets/contour-gradient.png',
    'assets/ground-wave.svg', 'assets/ground-wave.png',
]
DOCS = ['INSTALL.txt', 'LICENSE.txt', 'README.md']
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

manual = {f'BaseRangeGrowth/{name}': (ROOT / name).read_bytes()
          for name in RUNTIME + DOCS}
receipts = [archive(f'Growing-Grounds-{VERSION}.zip', manual)]

# Both rules are required: the dedicated server uses IsServer=true rules.
# Verify the dependency package name in the installed UE4SS Workshop Info.json
# before upload; the Steam route has not been tested on this development setup.
targets = ['./Scripts', './src', './assets', './config.lua', './enabled.txt']
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
workshop = {name: (ROOT / name).read_bytes() for name in RUNTIME + DOCS}
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
    'runtime_sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                       for name in RUNTIME},
}, indent=2) + '\n')

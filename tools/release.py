"""Create deterministic, allowlisted release archives for manual and Workshop use."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '0.2.1-beta'
RUNTIME = [
    'enabled.txt', 'config.lua', 'Scripts/main.lua',
    'src/range.lua', 'src/runtime.lua', 'src/ui.lua',
    'src/settings.lua', 'src/world_settings.lua',
    'src/storage.lua', 'src/palbox.lua', 'src/chest_ui.lua',
    'src/preview.lua', 'src/objects.lua', 'src/changes.lua',
    'src/motion.lua', 'src/boundary.lua', 'src/ring.lua', 'src/ribbon.lua', 'src/wave.lua',
    'src/texts.lua', 'src/language.lua',
    'assets/base-range.svg', 'assets/base-range.png',
    'assets/gg-mark.svg', 'assets/gg-mark.png',
    'assets/chest-bonus.svg', 'assets/chest-bonus.png',
    'assets/palbox-bonus.svg', 'assets/palbox-bonus.png',
    'assets/contour-gradient.svg', 'assets/contour-gradient.png',
    'assets/ground-wave.svg', 'assets/ground-wave.png',
]
DOCS = ['INSTALL.txt', 'LICENSE.txt', 'README.md']
BUILD = ROOT / 'build'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def archive(build, name, entries):
    output = build / name
    with zipfile.ZipFile(output, 'w') as z:
        for dest, data in sorted(entries.items()):
            entry = zipfile.ZipInfo(dest, (2026, 11, 8, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            z.writestr(entry, data)
    with zipfile.ZipFile(output) as z:
        require(z.testzip() is None, 'Archive CRC verification failed')
        require(set(z.namelist()) == set(entries), 'Archive entries differ from the allowlist')
        for name, data in entries.items():
            require(z.read(name) == data, 'Archive content mismatch: '+name)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(f'{digest}  {output.name}\n')
    print(output.name, digest)
    return {'file': output.name, 'sha256': digest, 'files': len(entries)}


def validate_sources(root):
    require(len(set(RUNTIME+DOCS)) == len(RUNTIME+DOCS), 'Duplicate allowlist entry')
    require(VERSION in (root/'Scripts/main.lua').read_text(), 'Bootstrap version mismatch')
    loaded = set()
    for name in RUNTIME:
        if name.endswith('.lua'):
            source = (root/name).read_text()
            require('RegisterKeyBind' not in source, 'Developer keyboard control in '+name)
            loaded.update(re.findall(r"'((?:src|assets)/[\w-]+\.(?:lua|png))'", source))
            # Reward icons are assembled from assets/ and each row specification.
            loaded.update('assets/'+icon for icon in re.findall(r"icon='([\w-]+\.png)'", source))
    missing = sorted(loaded-set(RUNTIME))
    require(not missing, f'Loaded at runtime but not in the archive: {missing}')


def workshop_info():
    # Both rules are required: the dedicated server uses IsServer=true rules.
    # Verify the loader dependency before upload; Workshop installation is untested.
    targets = ['./Scripts', './src', './assets', './config.lua', './enabled.txt']
    return {
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


def build_release(root=ROOT, build=BUILD):
    validate_sources(root)
    files = {name: (root/name).read_bytes() for name in RUNTIME+DOCS}
    build.mkdir(parents=True, exist_ok=True)
    manual = {'BaseRangeGrowth/'+name: data for name, data in files.items()}
    receipts = [archive(build, f'Growing-Grounds-{VERSION}.zip', manual)]

    info = workshop_info()
    workshop = dict(files)
    workshop['Info.json'] = (json.dumps(info, indent=2)+'\n').encode()
    workshop['thumbnail.png'] = (root/'assets/screenshots/base-range-level8.png').read_bytes()
    stage = build/f'workshop-{VERSION}'
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir()
    for name, data in workshop.items():
        path = stage/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    for rule in info['InstallRule']:
        require(all((stage/target).exists() for target in rule['Targets']), 'Missing Workshop target')
    receipts.append(archive(build, f'Growing-Grounds-{VERSION}-workshop.zip', workshop))
    receipt = {
        'version': VERSION, 'archives': receipts,
        'workshop_deployment_verified': False,
        'runtime_sha256': {name: hashlib.sha256(data).hexdigest()
                           for name, data in files.items() if name not in DOCS},
    }
    (build/'release-manifest.json').write_text(json.dumps(receipt, indent=2)+'\n')
    return receipt


if __name__ == '__main__':
    build_release()

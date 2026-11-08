"""Build only original mod source/assets; never include extracted game data."""
from pathlib import Path
import hashlib
import zipfile

root = Path(__file__).resolve().parents[1]
output = root / 'build' / 'BaseRangeGrowth-0.1.1-alpha.zip'
output.parent.mkdir(parents=True, exist_ok=True)
files = [root / name for name in ('enabled.txt', 'config.lua', 'INSTALL.txt')]
files += sorted((root / 'Scripts').glob('*.lua'))
files += sorted((root / 'src').glob('*.lua'))
files += [root / name for name in ('assets/base-range.svg', 'assets/base-range.png',
                                  'assets/contour-gradient.svg', 'assets/contour-gradient.png')]
files += sorted((root / 'tests').glob('*.lua'))
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in files:
        archive.write(path, Path('BaseRangeGrowth') / path.relative_to(root))
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
digest = hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix('.zip.sha256').write_text(digest + '  ' + output.name + '\n')
print(output.name, len(files), 'files;', output.stat().st_size, 'bytes;', digest)

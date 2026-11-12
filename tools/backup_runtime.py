"""Reproducible private CPython runtime. Fetch only with an explicit --fetch."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '3.14.10'
URL = 'https://www.python.org/ftp/python/3.14.10/python-3.14.10-embeddable-amd64.zip'
SHA256 = 'b553e7dac884469b40e0740bb527271c3378f700b427e0485835f1bb6424361c'
MANIFEST = 'https://www.python.org/ftp/python/3.14.10/windows-3.14.10.json'
CACHE = ROOT/'build/python-embedded.zip'


def entries():
    if not CACHE.is_file():
        raise RuntimeError('Missing pinned runtime; run python3 tools/backup_runtime.py --fetch')
    if hashlib.sha256(CACHE.read_bytes()).hexdigest() != SHA256:
        raise ValueError('Embedded Python archive SHA256 does not match the official release manifest')
    with zipfile.ZipFile(CACHE) as z:
        names = z.namelist()
        if len(names) != len(set(names)) or not {'python.exe', 'pythonw.exe', 'LICENSE.txt'} <= set(names):
            raise ValueError('Incomplete/duplicate runtime entries')
        result = {}
        for name in names:
            if '/' in name or '\\' in name or name in ('.', '..'):
                raise ValueError('Unexpected runtime archive path')
            result['backup/python/'+name] = z.read(name)
        return result


def provenance():
    return {'component': 'CPython embeddable x64', 'version': VERSION, 'url': URL,
            'sha256': SHA256, 'official_manifest': MANIFEST,
            'license': 'backup/python/LICENSE.txt', 'system_installation': False}


def main():
    p = argparse.ArgumentParser(description=__doc__);p.add_argument('--fetch', action='store_true')
    args = p.parse_args()
    CACHE.parent.mkdir(exist_ok=True)
    if args.fetch and not CACHE.exists():
        with urllib.request.urlopen(URL, timeout=45) as response:
            data = response.read(32*1024*1024)
        if hashlib.sha256(data).hexdigest() != SHA256:
            raise ValueError('Downloaded runtime SHA256 mismatch')
        temporary = CACHE.with_suffix('.partial');temporary.write_bytes(data);temporary.replace(CACHE)
    for name, data in entries().items():
        target = ROOT/'build'/name;target.parent.mkdir(parents=True, exist_ok=True);target.write_bytes(data)
    print(json.dumps(provenance(), indent=2))


if __name__ == '__main__':
    main()

"""GG archive core. The caller must supply a stopped, consistent world save.

This is an offline development tool, not an automatic UE4SS runtime feature.
Python standard library only; archives can also be opened with ordinary ZIP tools.
"""
import argparse
from contextlib import contextmanager, nullcontext
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import tempfile
import uuid
import zipfile

FORMAT = 'growing-grounds-save/1'
SETTINGS = ('config.lua', 'world-settings.ini', 'world-settings.ini.bak')
CHUNK = 1024 * 1024
MAX_FILES = 100000
MAX_BYTES = 64 * 1024**3


class LimitedFile:
    """Bound ZIP writes, including headers written after the payload."""
    def __init__(self, raw, limit):
        self.raw, self.limit = raw, limit

    def __getattr__(self, name):
        return getattr(self.raw, name)

    def write(self, data):
        require(self.raw.tell()+len(data) <= self.limit, 'Archive storage budget exceeded')
        return self.raw.write(data)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(stream):
    h, size = hashlib.sha256(), 0
    while data := stream.read(CHUNK):
        h.update(data)
        size += len(data)
    return {'size': size, 'sha256': h.hexdigest()}


def safe_name(name):
    parts = PurePosixPath(name).parts
    require(parts and not name.startswith('/') and '\\' not in name,
            'Invalid archive path')
    require('/'.join(parts) == name and all(p not in ('.', '..') for p in parts),
            'Non-canonical archive path')
    require(all(not any(ord(c) < 32 or c in ':<>"|?*' for c in p)
                and not p.endswith((' ', '.'))
                and p.split('.')[0].upper() not in
                {'CON', 'PRN', 'AUX', 'NUL', *('COM'+str(i) for i in range(1, 10)),
                 *('LPT'+str(i) for i in range(1, 10))} for p in parts),
            'Archive path is not portable')
    require(parts[0] == 'world' or (len(parts) == 2 and parts[0] == 'settings'
                                   and parts[1] in SETTINGS), 'Unexpected archive content')
    require(len(parts) >= 2, 'Invalid archive file')


def regular(path):
    s = path.lstat()
    require(stat.S_ISREG(s.st_mode), 'Only regular files can be archived: '+str(path))
    return (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns)


def inventory(world, mod):
    files = {}
    def unreadable(error):
        raise error
    for directory, dirs, names in os.walk(world, followlinks=False, onerror=unreadable):
        folder = Path(directory)
        if folder == world and 'backup' in dirs:
            dirs.remove('backup')  # Do not recursively archive the game's rotations.
        for name in dirs:
            require(not (folder/name).is_symlink(), 'Save directory contains a symbolic link')
        for name in names:
            p = folder/name
            rel = 'world/'+p.relative_to(world).as_posix()
            safe_name(rel)
            files[rel] = (p, regular(p))
    for name in SETTINGS:
        p = mod/name
        if p.exists() or p.is_symlink():
            files['settings/'+name] = (p, regular(p))
    require('world/Level.sav' in files and 'world/LevelMeta.sav' in files,
            'A complete world needs Level.sav and LevelMeta.sav; a client cache is insufficient')
    require('settings/config.lua' in files, 'GG config.lua is required')
    require(all(files[k][1][2] > 0 for k in ('world/Level.sav', 'world/LevelMeta.sav')),
            'World save files are empty')
    require(len(files) <= MAX_FILES and sum(v[1][2] for v in files.values()) <= MAX_BYTES,
            'Save exceeds archive limits')
    require(len({k.casefold() for k in files}) == len(files), 'Case-colliding save paths')
    return files


@contextmanager
def locked(folder):
    lock = folder/'.gg-backup.lock'
    fd = os.open(lock, os.O_CREAT | os.O_RDWR | getattr(os, 'O_NOFOLLOW', 0), 0o600)
    with os.fdopen(fd, 'r+b') as stream:
        if os.name == 'nt':
            import msvcrt
            if not os.fstat(stream.fileno()).st_size:
                stream.write(b'\0'); stream.flush()
            stream.seek(0)
            msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        # The OS releases the lock even after a killed worker; do not unlink
        # this inode and risk another process locking a different file.
        yield


def verify(archive):
    with zipfile.ZipFile(archive) as z:
        infos = z.infolist()
        names = [i.filename for i in infos]
        require(len(names) <= MAX_FILES+1 and len(set(names)) == len(names),
                'Too many or duplicate archive entries')
        require(len({n.casefold() for n in names}) == len(names), 'Case-colliding entries')
        require('manifest.json' in names and z.getinfo('manifest.json').file_size <= 32*1024**2,
                'Missing or oversized manifest')
        m = json.loads(z.read('manifest.json'))
        require(isinstance(m, dict), 'Invalid manifest')
        require(m.get('format') == FORMAT and isinstance(m.get('world_id'), str)
                and re.fullmatch('[0-9A-F]{32}', m['world_id']),
                'Unsupported archive manifest')
        require(m.get('kind') in ('baseline', 'rolling'), 'Unknown backup kind')
        require(m.get('consistency') == 'source-stopped', 'Unverified save consistency')
        require(isinstance(m.get('created_utc'), str), 'Invalid timestamp')
        timestamp = datetime.fromisoformat(m['created_utc'])
        require(timestamp.tzinfo is not None, 'Missing timestamp timezone')
        files = m['files']
        require(isinstance(files, dict) and set(names) == set(files) | {'manifest.json'},
                'Manifest does not match archive contents')
        require({'world/Level.sav', 'world/LevelMeta.sav', 'settings/config.lua'} <= set(files),
                'Incomplete save archive')
        require(sum(i.file_size for i in infos) <= MAX_BYTES, 'Archive exceeds size limit')
        for name, expected in files.items():
            safe_name(name)
            info = z.getinfo(name)
            mode = info.external_attr >> 16
            require(not info.is_dir() and (not stat.S_IFMT(mode) or stat.S_ISREG(mode)),
                    'Non-regular archive entry')
            require(isinstance(expected, dict) and info.file_size == expected.get('size'),
                    'Archive size mismatch: '+name)
            with z.open(name) as f:
                require(digest(f) == expected, 'Archive checksum mismatch: '+name)
    return m


def sync_directory(folder):
    if os.name != 'nt':
        fd = os.open(folder, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)


def create(world, mod, destination, *, kind='rolling', keep=5, version='unknown',
           reason='manual', stopped=False, max_archive_bytes=MAX_BYTES, _lock_held=False):
    require(stopped, 'Stop the game/server first and explicitly confirm source-stopped')
    require(kind in ('baseline', 'rolling') and 1 <= keep <= 100, 'Invalid backup policy')
    world, mod, destination = map(lambda p: Path(p).resolve(), (world, mod, destination))
    world_id = world.name.upper()
    require(re.fullmatch('[0-9A-F]{32}', world_id), 'World folder must be its 32-character ID')
    require(world.is_dir() and mod.is_dir(), 'Save or mod folder not found')
    require(not destination.is_relative_to(world) and not destination.is_relative_to(mod),
            'Keep backups outside the world and mod folders')
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    warnings, removed = [], []
    with nullcontext() if _lock_held else locked(destination):
        if kind == 'baseline':
            require(not list(destination.glob(f'gg-{world_id}-baseline-*.zip')),
                    'A protected baseline already exists; it will not be overwritten')
        before = inventory(world, mod)
        stamp = datetime.now(timezone.utc)
        output = destination/f'gg-{world_id}-{kind}-{stamp:%Y%m%dT%H%M%SZ}-{uuid.uuid4().hex[:12]}.zip'
        temporary = output.with_suffix('.partial')
        manifest = {'format': FORMAT, 'world_id': world_id, 'kind': kind,
                    'created_utc': stamp.isoformat(), 'mod_version': version,
                    'reason': reason,
                    'consistency': 'source-stopped', 'files': {}}
        try:
            with temporary.open('xb') as raw:
                with zipfile.ZipFile(LimitedFile(raw, max_archive_bytes), 'w',
                                     compression=zipfile.ZIP_DEFLATED, compresslevel=1) as z:
                    for name, (path, fingerprint) in sorted(before.items()):
                        require(regular(path) == fingerprint, 'Source changed during backup')
                        h, size = hashlib.sha256(), 0
                        with path.open('rb') as source, z.open(name, 'w', force_zip64=True) as target:
                            while data := source.read(CHUNK):
                                target.write(data)
                                h.update(data)
                                size += len(data)
                        require(regular(path) == fingerprint, 'Source changed during backup')
                        manifest['files'][name] = {'size': size, 'sha256': h.hexdigest()}
                    require(inventory(world, mod) == before, 'Save file set changed during backup')
                    # Re-read the source as well as the archive; do not trust size alone.
                    for name, (path, _) in before.items():
                        with path.open('rb') as f:
                            require(digest(f) == manifest['files'][name], 'Source changed during backup')
                    require(inventory(world, mod) == before, 'Source changed during verification')
                    z.writestr('manifest.json', json.dumps(manifest, indent=2)+'\n')
                raw.flush()
                os.fsync(raw.fileno())
            verify(temporary)
            # Unique name plus an exclusive folder lock; never replace a previous archive.
            require(not output.exists(), 'Archive name already exists')
            os.rename(temporary, output)
            sync_directory(destination)
        finally:
            temporary.unlink(missing_ok=True)
        # Only a successfully verified rolling archive can rotate older rolling copies.
        if kind == 'rolling':
            candidates = []
            for p in destination.glob(f'gg-{world_id}-rolling-*.zip'):
                try:
                    m = verify(p)
                    require(m['world_id'] == world_id and m['kind'] == 'rolling', 'Mismatched backup identity')
                    candidates.append((datetime.fromisoformat(m['created_utc']), p))
                except (ValueError, OSError, zipfile.BadZipFile, KeyError) as e:
                    warnings.append(f'Left unverified archive untouched: {p.name}: {e}')
            for _, old in sorted(candidates)[:-keep]:
                old.unlink()
                removed.append(old.name)
            sync_directory(destination)
    return {'archive': str(output), 'files': len(manifest['files']), 'removed': removed, 'warnings': warnings}


def restore_copy(archive, destination):
    """Extract to a NEW review folder. Never overwrite a live world or execute config."""
    m = verify(archive)
    destination = Path(destination).absolute()
    require(not destination.exists(), 'Restore destination must not exist')
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix='.gg-restore-', dir=destination.parent))
    try:
        with zipfile.ZipFile(archive) as z:
            for name, expected in m['files'].items():
                p = staging/name
                p.parent.mkdir(parents=True, exist_ok=True)
                with z.open(name) as source, p.open('xb') as target:
                    shutil.copyfileobj(source, target, CHUNK)
                    target.flush()
                    os.fsync(target.fileno())
                with p.open('rb') as f:
                    require(digest(f) == expected, 'Restored file checksum mismatch')
        (staging/'manifest.json').write_text(json.dumps(m, indent=2)+'\n', encoding='utf-8')
        # Reserve the destination so a concurrent process cannot have its files replaced.
        destination.mkdir()
        marker = destination/'RESTORE-INCOMPLETE.txt'
        marker.write_text('Restore did not finish. Do not use this copy.\n')
        try:
            for name in ('world', 'settings', 'manifest.json'):
                os.rename(staging/name, destination/name)
        except BaseException:
            # Leave the marked partial restore for diagnosis; never remove a user's folder.
            raise
        marker.unlink()
        sync_directory(destination)
        sync_directory(destination.parent)
        return {'restored_copy': str(destination), 'world_id': m['world_id'], 'files': len(m['files'])}
    finally:
        shutil.rmtree(staging)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    backup = commands.add_parser('create')
    for name in ('world', 'mod', 'destination'):
        backup.add_argument('--'+name, required=True, type=Path)
    backup.add_argument('--kind', choices=('baseline', 'rolling'), default='rolling')
    backup.add_argument('--keep', type=int, default=5)
    backup.add_argument('--version', required=True)
    backup.add_argument('--reason', default='manual')
    backup.add_argument('--source-stopped', action='store_true')
    check = commands.add_parser('verify')
    check.add_argument('archive', type=Path)
    restore = commands.add_parser('restore-copy')
    restore.add_argument('archive', type=Path)
    restore.add_argument('destination', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'create':
            result = create(args.world, args.mod, args.destination, kind=args.kind,
                            keep=args.keep, version=args.version, reason=args.reason,
                            stopped=args.source_stopped)
        elif args.command == 'verify':
            m = verify(args.archive)
            result = {'verified': str(args.archive), 'world_id': m['world_id'], 'files': len(m['files'])}
        else:
            result = restore_copy(args.archive, args.destination)
        print(json.dumps(result, indent=2))
    except (ValueError, OSError, KeyError, zipfile.BadZipFile) as e:
        parser.exit(1, 'Backup failed: '+str(e)+'\n')


if __name__ == '__main__':
    main()

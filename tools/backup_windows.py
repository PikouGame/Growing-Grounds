"""Automatic Windows companion. It sleeps on the game handle until a clean exit."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

# The private embedded interpreter ignores ambient Python/site paths.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import backup_policy
from backup_control import Cancelled, cancellable
from backup_win32 import Win32

QUIET_SECONDS = 120


def atomic(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')
    os.replace(temporary, path)


def read(path):
    if path.stat().st_size > 64*1024:
        raise ValueError('Backup state is too large')
    return json.loads(path.read_text(encoding='utf-8'))


def identity(save_root):
    return hashlib.sha256(str(Path(save_root).resolve()).casefold().encode('utf-8')).hexdigest()[:24]


def event_name(job):
    return 'Local\\GGBackupCancel_'+job['token']


def gate_name(job):
    return 'Local\\GGBackupFiles_'+identity(job['save_root'])


def current(path, token):
    try:
        return read(path)['token'] == token
    except FileNotFoundError:
        return False


def status(path, job, value):
    if current(path, job['token']):
        value = dict(value, token=job['token'], time=time.time())
        atomic(path.parent/'status.json', value)
        if value['status'] in ('idle', 'error', 'unclean-exit-no-backup'):
            atomic(path.parent/'last-result.json', value)


def worlds(save_root):
    import re
    # Solo/account/world and dedicated/0/world. Remote-client caches have no Level.sav.
    result = []
    for level in sorted(Path(save_root).glob('*/*/Level.sav')):
        world = level.parent
        if re.fullmatch(r'[0-9A-Fa-f]{32}', world.name) and (world/'LevelMeta.sav').is_file():
            result.append(world)
    return result


def paths(game, mod):
    if game.name.lower().startswith('palserver-'):
        saved = game.parents[2]/'Saved'
    else:
        saved = Path(os.environ['LOCALAPPDATA'])/'Pal'/'Saved'
    saved = saved.resolve()
    return saved/'SaveGames', saved/'GrowingGroundsBackups', saved/'GrowingGroundsBackupState'


def arm(mod):
    win = Win32();mod = Path(mod).resolve()
    if not (mod/'config.lua').is_file():
        raise ValueError('Missing GG configuration')
    pid, game = win.game_parent(mod)
    save_root, destination, state = paths(game, mod)
    state.mkdir(parents=True, exist_ok=True)
    h = win.open_process(pid)
    try:
        job = {'token': uuid.uuid4().hex, 'pid': pid, 'created': win.created(h),
               'game': str(game), 'mod': str(mod), 'save_root': str(save_root),
               'destination': str(destination), 'quiet_seconds': QUIET_SECONDS,
               'version': (mod/'backup-version.txt').read_text().strip()}
    finally:
        win.close(h)
    path = state/'job.json';old_event = None
    try:
        if path.exists():
            old = read(path)
            if not isinstance(old.get('token'), str) or len(old['token']) != 32:
                raise ValueError('Invalid prior backup state')
            old_event = win.event(event_name(old));win.cancel(old_event)
        # Cancel first, then wait until the old worker has closed all save/archive files.
        # Only a short, cancellable operation can be in progress at mod startup.
        with win.gate(gate_name(job)):
            atomic(path, job)
            status(path, job, {'status': 'arming', 'archive_work': False})
            flags = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
            args = [sys.executable, '-I', str(Path(__file__).resolve()), 'watch', str(path), job['token']]
            try:
                child = subprocess.Popen(args, close_fds=True, creationflags=flags | 0x01000000)
            except OSError:
                child = subprocess.Popen(args, close_fds=True, creationflags=flags)
            deadline = time.monotonic()+5
            while time.monotonic() < deadline:
                ready = state/'ready.json'
                if ready.exists() and read(ready).get('token') == job['token']:
                    return 0
                if child.poll() is not None:
                    raise RuntimeError('Backup companion stopped during startup')
                time.sleep(0.025)
            raise TimeoutError('Backup companion did not acknowledge startup')
    finally:
        win.close(old_event)


def watch(path, token, win=None):
    win = win or Win32();path = Path(path);job = read(path)
    if job['token'] != token:
        return 'superseded'
    parent = cancel = None
    try:
        parent = win.open_process(job['pid'])
        if win.created(parent) != job['created'] or str(win.image(parent)) != job['game']:
            raise ValueError('Game process identity changed')
        cancel = win.event(event_name(job))
        win.background()
        status(path, job, {'status': 'session-running', 'archive_work': False})
        atomic(path.parent/'ready.json', {'token': token})
        # No directory scans, timers, hashing or compression while this game is active.
        if win.wait([cancel, parent], 0xFFFFFFFF) == 0:
            return 'cancelled'
        if win.exit_code(parent) != 0:
            status(path, job, {'status': 'unclean-exit-no-backup', 'archive_work': False})
            return 'unclean'
        status(path, job, {'status': 'waiting-for-quiet', 'archive_work': False})
        if win.wait([cancel], int(job['quiet_seconds']*1000)) == 0:
            return 'cancelled'
        with win.gate(gate_name(job)):
            last_check = 0
            def check():
                nonlocal last_check
                if win.wait([cancel], 0) == 0 or not current(path, token):
                    raise Cancelled('Game relaunched')
                now = time.monotonic()
                if now-last_check >= 0.25:
                    if win.game_running():
                        raise Cancelled('A Palworld process started')
                    last_check = now
            with cancellable(check):
                results = []
                for world in worlds(job['save_root']):
                    check()
                    results.append(backup_policy.automatic_once(world, job['mod'], job['destination'],
                        stopped=True, version=job['version']))
                status(path, job, {'status': 'idle', 'archive_work': False, 'results': results})
        return 'idle'
    except Cancelled:
        status(path, job, {'status': 'cancelled-for-relaunch', 'archive_work': False})
        return 'cancelled'
    except Exception as exc:
        status(path, job, {'status': 'error', 'archive_work': False, 'error': str(exc)[:2000]})
        raise
    finally:
        win.close(parent);win.close(cancel)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('arm', 'watch'))
    p.add_argument('path', type=Path)
    p.add_argument('token', nargs='?')
    args = p.parse_args()
    if args.action == 'arm':
        return arm(args.path)
    watch(args.path, args.token)
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        if sys.stderr:
            print('GG backup: '+str(exc), file=sys.stderr)
        raise SystemExit(1)

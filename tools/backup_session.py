"""Linux/Proton session adapter: archive only after a clean, quiet shutdown.

The launcher and worker share an OS lock. Relaunch cancels the pending worker
before starting the game, so archive work never overlaps the managed session.
"""
import argparse
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

import backup_policy


def load_profile(path):
    p = json.loads(Path(path).read_text())
    for key in ('session_unit', 'backup_unit'):
        if not re.fullmatch(r'[A-Za-z0-9_-]+', p[key]):
            raise ValueError('Invalid systemd unit name')
    if p['session_unit'] == p['backup_unit']:
        raise ValueError('Session and backup need separate units')
    for key in ('state', 'destination', 'mod'):
        p[key] = Path(p[key]).resolve()
    p['worlds'] = [Path(w).resolve() for w in p.get('worlds', [])]
    if 'save_root' in p:
        p['save_root'] = Path(p['save_root']).resolve()
    if (not p['worlds'] and 'save_root' not in p) or len(set(p['worlds'])) != len(p['worlds']):
        raise ValueError('Profile needs authoritative world paths or a SaveGames root')
    quiet = p.get('quiet_seconds', 120)
    if not isinstance(quiet, int) or not 2 <= quiet <= 3600:
        raise ValueError('Invalid quiet period')
    p['quiet_seconds'] = quiet
    p['state'].mkdir(parents=True, exist_ok=True, mode=0o700)
    return p


def worlds(profile):
    result = set(profile['worlds'])
    if 'save_root' in profile:
        for level in profile['save_root'].glob('*/*/Level.sav'):
            if re.fullmatch(r'[0-9a-fA-F]{32}', level.parent.name):
                result.add(level.parent.resolve())
    return sorted(result)


def baselines_before_first_launch(profile):
    # One-time disk work happens BEFORE the game process starts, never while playing.
    cache_path = profile['state']/'baselines.json'
    try:
        cache = json.loads(cache_path.read_text())
    except FileNotFoundError:
        cache = {}
    for world in worlds(profile):
        existing = sorted(profile['destination'].glob(f'gg-{world.name.upper()}-baseline-*.zip'))
        if not existing:
            result = backup_policy.automatic_once(
                world, profile['mod'], profile['destination'], stopped=True,
                version=profile['version'], policy=profile.get('policy'))
            if result['status'] != 'created':
                raise RuntimeError('Cannot protect initial save: '+json.dumps(result))
            existing = [Path(result['archive'])]
        baseline = existing[0]
        fingerprint = list(backup_policy.archive.regular(baseline))
        if cache.get(str(baseline)) != fingerprint:
            manifest = backup_policy.archive.verify(baseline)
            if manifest['world_id'] != world.name.upper() or manifest['kind'] != 'baseline':
                raise ValueError('Baseline identity mismatch')
            if list(backup_policy.archive.regular(baseline)) != fingerprint:
                raise ValueError('Baseline changed during verification')
            cache[str(baseline)] = fingerprint
    temporary = cache_path.with_suffix('.tmp')
    temporary.write_text(json.dumps(cache)+'\n')
    os.replace(temporary, cache_path)


def write_state(profile, value):
    value = dict(value, time=time.time())
    path = profile['state']/'status.json'
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(value, indent=2)+'\n')
    os.replace(temp, path)
    print('[GG Backup] '+json.dumps(value), flush=True)


def systemctl(*args):
    return subprocess.run(['systemctl', '--user', *args], text=True, capture_output=True)


def inactive(profile):
    result = systemctl('show', profile['session_unit']+'.service', '--property=ActiveState', '--value')
    # A collected transient unit is reported as inactive. Unknown errors fail closed.
    return result.returncode == 0 and result.stdout.strip() in ('inactive', 'failed')


@contextmanager
def session_lock(profile, blocking=False):
    with (profile['state']/'session.lock').open('a+b') as f:
        fcntl.flock(f, fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB))
        try:
            yield
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)


def cancel_pending(profile):
    # Stop timer first, then the worker; systemctl waits for the worker to exit.
    systemctl('stop', profile['backup_unit']+'.timer')
    systemctl('stop', profile['backup_unit']+'.service')


def schedule(profile, profile_path):
    subprocess.run([
        'systemd-run', '--user', '--collect', '--quiet',
        '--unit='+profile['backup_unit'], '--on-active='+str(profile['quiet_seconds'])+'s',
        '--timer-property=AccuracySec=1s', '--property=Nice=19',
        '--property=IOSchedulingClass=idle', '--property=CPUQuota=20%',
        '--property=MemoryMax=256M', '--property=TimeoutStopSec=15s',
        sys.executable, str(Path(__file__).resolve()), 'worker', str(Path(profile_path).resolve()),
    ], check=True)


def launch(profile_path, command):
    profile = load_profile(profile_path)
    if not command:
        raise ValueError('Missing session command')
    cancel_pending(profile)
    with session_lock(profile, blocking=True):
        # A second launcher cannot overlap this profile's managed game.
        baselines_before_first_launch(profile)
        write_state(profile, {'status': 'session-running', 'archive_work': False})
        child, interrupted = None, False
        previous = {}
        def forward(sig, _frame):
            nonlocal interrupted
            interrupted = True
            if child is not None and child.poll() is None:
                child.send_signal(sig)
        for sig in (signal.SIGINT, signal.SIGTERM):
            previous[sig] = signal.signal(sig, forward)
        try:
            child = subprocess.Popen(command)
            code = child.wait()
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)
        if code == 0 and not interrupted:
            write_state(profile, {'status': 'waiting-for-quiet', 'clean_exit': True,
                                  'eligible_at': time.time()+profile['quiet_seconds']})
            schedule(profile, profile_path)
        else:
            write_state(profile, {'status': 'unclean-exit-no-backup', 'clean_exit': False,
                                  'exit_code': code, 'interrupted': interrupted})
        return code


def worker(profile_path):
    profile = load_profile(profile_path)
    def cancelled(_sig, _frame):
        raise InterruptedError('Backup cancelled for session restart')
    old = signal.signal(signal.SIGTERM, cancelled)
    try:
        try:
            with session_lock(profile):
                previous = json.loads((profile['state']/'status.json').read_text())
                if (previous.get('status') != 'waiting-for-quiet'
                        or previous.get('clean_exit') is not True
                        or time.time() < previous.get('eligible_at', float('inf'))
                        or not inactive(profile)):
                    return {'status': 'not-eligible'}
                results = []
                for world in worlds(profile):
                    if not inactive(profile):
                        raise InterruptedError('Managed session became active')
                    results.append(backup_policy.automatic_once(
                        world, profile['mod'], profile['destination'], stopped=True,
                        version=profile['version'], policy=profile.get('policy')))
                write_state(profile, {'status': 'idle', 'results': results})
                return {'status': 'idle', 'results': results}
        except BlockingIOError:
            return {'status': 'session-active'}
        except InterruptedError:
            return {'status': 'cancelled'}
    finally:
        signal.signal(signal.SIGTERM, old)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('launch', 'worker'))
    parser.add_argument('profile', type=Path)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        if args.action == 'launch':
            command = args.command[1:] if args.command[:1] == ['--'] else args.command
            return launch(args.profile, command)
        print(json.dumps(worker(args.profile)))
        return 0
    except Exception as e:
        print('[GG Backup] '+str(e), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())

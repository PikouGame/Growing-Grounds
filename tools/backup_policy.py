"""Persistent bounded retention shared by the Windows and Linux companions."""
from datetime import datetime, timezone
from pathlib import Path
import shutil
import zipfile

import save_backup as archive
from backup_control import checkpoint

DEFAULTS = {'interval_seconds': 1800, 'recent': 3, 'daily': 7,
            'max_bytes': 1024**3, 'reserve_bytes': 1024**3}


def scan(destination):
    records, unknown = [], []
    for path in sorted(destination.glob('gg-*.zip')):
        checkpoint()
        try:
            archive.require(not path.is_symlink(), 'Linked archive')
            m = archive.verify(path)
            archive.require(path.name.startswith(f"gg-{m['world_id']}-{m['kind']}-"),
                            'Archive name and manifest disagree')
            records.append({'path': path, 'manifest': m,
                            'time': datetime.fromisoformat(m['created_utc']),
                            'bytes': path.stat().st_size})
        except (ValueError, OSError, KeyError, zipfile.BadZipFile):
            unknown.append(path)
    return records, unknown


def protected(records):
    """Every baseline and the most recent healthy backup of every world survive."""
    keep, latest = set(), {}
    for record in records:
        world = record['manifest']['world_id']
        if record['manifest']['kind'] == 'baseline':
            keep.add(record['path'])
        if world not in latest or record['time'] > latest[world]['time']:
            latest[world] = record
    keep.update(record['path'] for record in latest.values())
    return keep


def retained(records, now, policy):
    keep = protected(records)
    worlds = {r['manifest']['world_id'] for r in records}
    for world in worlds:
        rolling = sorted((r for r in records if r['manifest']['world_id'] == world
                          and r['manifest']['kind'] == 'rolling'), key=lambda r: r['time'], reverse=True)
        keep.update(r['path'] for r in rolling[:policy['recent']])
        days = set()
        for r in rolling:
            age = (now.date() - r['time'].astimezone(timezone.utc).date()).days
            day = r['time'].astimezone(timezone.utc).date()
            if 1 <= age <= policy['daily'] and day not in days:
                keep.add(r['path'])
                days.add(day)
    return keep


def source_files(world, mod):
    result = {}
    for name, (path, _) in archive.inventory(world, mod).items():
        with path.open('rb') as f:
            result[name] = archive.digest(f)
    return result


def automatic_once(world, mod, destination, *, stopped=False, version='unknown',
                   policy=None, now=None):
    """Evaluate one eligible, consistent checkpoint. No timer or game hook here.

    Cooldown and change detection use verified manifests, so restarting this
    process does not reset them. All worlds must share this destination to
    share its storage budget. The session adapter establishes a stopped source.
    """
    archive.require(stopped, 'Automatic trigger must first establish a consistent, stopped source')
    policy = dict(DEFAULTS, **(policy or {}))
    archive.require(all(isinstance(v, int) and v >= 0 for v in policy.values())
                    and policy['recent'] >= 1 and 0 < policy['max_bytes'] <= 1024**3,
                    'Invalid automatic backup policy')
    now = now or datetime.now(timezone.utc)
    archive.require(now.tzinfo is not None, 'Policy clock must include a timezone')
    world, mod, destination = map(lambda p: Path(p).resolve(), (world, mod, destination))
    archive.require(not destination.is_relative_to(world) and not destination.is_relative_to(mod),
                    'Keep archives outside save and mod folders')
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    # Manual and automatic operations share one lock from planning to pruning.
    with archive.locked(destination):
        records, unknown = scan(destination)
        own = [r for r in records if r['manifest']['world_id'] == world.name.upper()]
        if any(p.name.startswith(f'gg-{world.name.upper()}-baseline-') for p in unknown):
            return {'status': 'baseline-needs-attention', 'archive_created': False}
        kind = 'rolling' if any(r['manifest']['kind'] == 'baseline' for r in own) else 'baseline'
        latest = max(own, key=lambda r: r['time']) if own else None
        if latest:
            elapsed = (now-latest['time']).total_seconds()
            if elapsed < 0:
                return {'status': 'clock-moved-backwards', 'archive_created': False}
            if kind == 'rolling' and elapsed < policy['interval_seconds']:
                return {'status': 'cooldown', 'archive_created': False,
                        'retry_after_seconds': policy['interval_seconds']-int(elapsed)}
        current = source_files(world, mod)
        # A rolling copy cannot substitute for the protected initial baseline.
        if kind == 'rolling' and latest and current == latest['manifest']['files']:
            return {'status': 'unchanged', 'archive_created': False}
        # Conservative upper bound for DEFLATE overhead, ZIP headers and manifest.
        estimate = sum(v['size'] for v in current.values()) * 101 // 100 + len(current)*4096 + 65536
        used = sum(p.stat().st_size for p in destination.iterdir() if p.is_file())
        free = shutil.disk_usage(destination).free
        safe = protected(records)
        eligible = sorted((r for r in records if r['path'] not in safe), key=lambda r: r['time'])
        planned = []
        for r in eligible:
            if used+estimate <= policy['max_bytes'] and free-estimate >= policy['reserve_bytes']:
                break
            planned.append(r)
            used -= r['bytes']
            free += r['bytes']
        if used+estimate > policy['max_bytes'] or free-estimate < policy['reserve_bytes']:
            return {'status': 'storage-limit', 'archive_created': False,
                    'required_peak_bytes': used+estimate, 'max_bytes': policy['max_bytes']}
        # The baseline and last VERIFIED copy are never candidates, including on failure.
        for r in planned:
            checkpoint()
            r['path'].unlink()
        result = archive.create(world, mod, destination, kind=kind, keep=None, version=version,
                                reason='automatic-policy', stopped=True, _lock_held=True,
                                max_archive_bytes=min(policy['max_bytes']-used,
                                                      free-policy['reserve_bytes']))
        remaining, unknown = scan(destination)
        keep = retained(remaining, now, policy)
        removed = [r['path'].name for r in planned]
        for r in remaining:
            if r['path'] not in keep:
                checkpoint()
                r['path'].unlink()
                removed.append(r['path'].name)
        result.update(status='created', archive_created=True, removed=removed,
                      untouched_unverified=[p.name for p in unknown])
        archive.sync_directory(destination)
        return result

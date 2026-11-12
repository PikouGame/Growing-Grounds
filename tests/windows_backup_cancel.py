"""Cancel an actual Win32 writer by starting a new fake game through the real arm path."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from backup_win32 import Win32
import save_backup


def wait_for(test,seconds=20):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        if test():return
        time.sleep(0.01)
    raise RuntimeError('Timed out waiting for active-write cancellation')


def main():
    fixture=Path(sys.argv[1]).resolve();state=fixture/'appdata/Pal/Saved/GrowingGroundsBackupState'
    job_path=state/'job.json';job=json.loads(job_path.read_text());world=Path(job['save_root'])/'account'/('A'*32)
    dest=Path(job['destination']);baseline=next(dest.glob('*.zip'));before=baseline.read_bytes()
    # Real incompressible data creates a sufficiently long write; only this disposable fixture changes.
    (world/'Level.sav').write_bytes(os.urandom(32*1024*1024))
    win=Win32();dummy=subprocess.Popen([sys.executable,'-I','-c','import time;time.sleep(2)'])
    handle=win.open_process(dummy.pid)
    job.update(token=uuid.uuid4().hex,pid=dummy.pid,created=win.created(handle),game=str(win.image(handle)),quiet_seconds=0)
    win.close(handle)
    # Permit a rolling copy immediately in the fixture by changing only baseline timestamp,
    # without weakening the worker's production1800s policy.
    import zipfile
    with zipfile.ZipFile(baseline) as z:entries={n:z.read(n) for n in z.namelist()}
    manifest=json.loads(entries['manifest.json']);manifest['created_utc']='2026-01-01T00:00:00+00:00'
    entries['manifest.json']=(json.dumps(manifest)+'\n').encode()
    with zipfile.ZipFile(baseline,'w',zipfile.ZIP_DEFLATED) as z:
        for n,b in entries.items():z.writestr(n,b)
    before=baseline.read_bytes()
    job_path.write_text(json.dumps(job));watcher=subprocess.Popen([sys.executable,'-I',str(ROOT/'tools/backup_windows.py'),'watch',str(job_path),job['token']])
    dummy.wait(timeout=10)
    wait_for(lambda:any(p.stat().st_size>1024*1024 for p in dest.glob('*.partial')))
    started=time.monotonic()
    game=fixture/'game/Pal/Binaries/Win64/Palworld-Win64-Shipping.exe'
    # Nonzero exit avoids scheduling another checkpoint after the cancellation proof.
    script=fixture/'fake_game_cancel.py';original=(fixture/'fake_game.py').read_text()
    script.write_text(original.replace('time.sleep(3)','raise SystemExit(3)'))
    new=subprocess.Popen([str(game),'-I',str(script)],env=dict(os.environ,LOCALAPPDATA=str(fixture/'appdata')))
    wait_for(lambda:json.loads(job_path.read_text())['token']!=job['token'])
    assert watcher.wait(timeout=10)==0
    assert new.wait(timeout=15)==3
    assert not list(dest.glob('*.partial')) and baseline.read_bytes()==before
    assert len(list(dest.glob('*.zip')))==1
    receipt={'active_write_cancelled':True,'last_healthy_unchanged':True,'partial_removed':True,
             'relaunch_seconds':round(time.monotonic()-started,3),'native_windows_api_under_wine':True}
    (fixture/'cancellation-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt),flush=True)

if __name__=='__main__':main()

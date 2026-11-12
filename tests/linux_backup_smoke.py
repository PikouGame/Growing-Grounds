"""Exercise the shipped setup and launcher with disposable native processes/worlds."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from backup_setup import setup
import save_backup


def wait_for(test,seconds=15):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        if test():return
        time.sleep(0.05)
    raise RuntimeError('Linux launcher fixture timed out')


def main():
    root=Path(sys.argv[1]).resolve();assert not root.exists();root.mkdir()
    saves=root/'Saved/SaveGames';world=saves/'account'/('A'*32);world.mkdir(parents=True)
    (world/'Level.sav').write_bytes(b'initial-world');(world/'LevelMeta.sav').write_bytes(b'meta')
    launcher,profile=setup(ROOT,saves)
    p=json.loads(profile.read_text());dest=Path(p['destination'])
    # Separate fixture policy only; the shipped setup defaults are checked first.
    assert p['quiet_seconds']==120 and 'policy' not in p
    p['quiet_seconds']=2;p['policy']={'interval_seconds':0};profile.write_text(json.dumps(p))
    script=root/'session.py'
    script.write_text('import os,time\nfrom pathlib import Path\nassert os.environ["GG_BACKUP_MANAGED"]=="1"\nassert os.environ["GG_FIXTURE_ENV"]=="value with spaces"\np=Path('+repr(str(world/'Level.sav'))+')\np.write_bytes(p.read_bytes()+b"-changed")\nPath('+repr(str(root/'running'))+').write_text("yes")\ntime.sleep(3)\n')
    def launch():return subprocess.Popen([str(launcher),sys.executable,str(script)],env=dict(os.environ,GG_FIXTURE_ENV='value with spaces'))
    first=launch();wait_for(lambda:(root/'running').exists())
    assert first.poll() is None
    baseline=list(dest.glob('*.zip'));assert len(baseline)==1
    assert not list(dest.glob('*rolling*')),'No rolling archive while game active'
    assert first.wait(timeout=15)==0
    (root/'running').unlink();second=launch();wait_for(lambda:(root/'running').exists())
    assert not list(dest.glob('*rolling*')),'Quick relaunch cancels pending timer'
    assert second.wait(timeout=15)==0
    wait_for(lambda:len(list(dest.glob('*rolling*.zip')))==1,15)
    rolling=next(dest.glob('*rolling*.zip'));save_backup.verify(rolling)
    restored=root/'restored';save_backup.restore_copy(rolling,restored)
    assert (restored/'world/Level.sav').read_bytes()==(world/'Level.sav').read_bytes()
    receipt={'shipped_setup_and_launcher':True,'baseline_before_session':True,
             'no_archives_while_active':True,'quick_relaunch_cancelled':True,
             'environment_preserved':True,'restored_copy_matches':True,
             'fixture_only_quiet_seconds':2,'production_quiet_seconds':120}
    (root/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))

if __name__=='__main__':main()

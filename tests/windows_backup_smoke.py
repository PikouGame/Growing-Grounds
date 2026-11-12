"""Native Win32 companion proof in a disposable Wine prefix; never a real game/save."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from backup_win32 import Win32
import save_backup


def wait_for(test, seconds=15):
    end = time.monotonic()+seconds
    while time.monotonic()<end:
        if test():return
        time.sleep(0.05)
    raise RuntimeError('Fixture timed out')


def main():
    fixture = Path(sys.argv[1]).resolve()
    assert not fixture.exists(), 'Use a new disposable fixture'
    fixture.mkdir(parents=True)
    runtime = ROOT/'build/backup/python'
    game_dir = fixture/'game/Pal/Binaries/Win64';shutil.copytree(runtime, game_dir)
    game = game_dir/'Palworld-Win64-Shipping.exe';shutil.copy2(game_dir/'python.exe', game)
    mod = game_dir/'ue4ss/Mods/BaseRangeGrowth';mod.mkdir(parents=True)
    (mod/'config.lua').write_text('return {automaticBackups=true}')
    (mod/'backup-version.txt').write_text('portable-smoke')
    localappdata = fixture/'appdata';saved = localappdata/'Pal/Saved'
    world = saved/'SaveGames/account'/('A'*32);world.mkdir(parents=True)
    (world/'Level.sav').write_bytes(b'fixture-world\x00'*5000)
    (world/'LevelMeta.sav').write_bytes(b'fixture-meta')
    (world/'Players').mkdir();(world/'Players/player.sav').write_bytes(b'fixture-palbox-extra-slots')
    state = saved/'GrowingGroundsBackupState';dest = saved/'GrowingGroundsBackups'
    # Use the same quoted cmd.exe arm path as the Lua bootstrap.
    command = '""'+str(runtime/'pythonw.exe')+'" -I "'+str(ROOT/'tools/backup_windows.py')+'" arm "'+str(mod)+'""'
    script = fixture/'fake_game.py'
    script.write_text('import os,time\nassert os.system('+repr(command)+')==0\ntime.sleep(3)\n')
    env = dict(os.environ, LOCALAPPDATA=str(localappdata))
    def play():return subprocess.Popen([str(game), '-I', str(script)], env=env)
    first = play()
    wait_for(lambda:(state/'ready.json').exists())
    assert first.poll() is None and not list(dest.glob('*.zip')), 'No archive during active session'
    job1 = json.loads((state/'job.json').read_text())
    assert first.wait(timeout=15)==0
    wait_for(lambda:json.loads((state/'status.json').read_text())['status']=='waiting-for-quiet')
    second = play()
    wait_for(lambda:json.loads((state/'job.json').read_text())['token']!=job1['token'])
    job2 = json.loads((state/'job.json').read_text())
    wait_for(lambda:json.loads((state/'ready.json').read_text())['token']==job2['token'])
    assert second.poll() is None and not list(dest.glob('*.zip')), 'Quick relaunch must leave no archive'
    assert second.wait(timeout=15)==0
    stopped = time.monotonic()
    wait_for(lambda:json.loads((state/'status.json').read_text())['status']=='waiting-for-quiet')
    # The production120s quiet period, not a shortened policy override.
    while time.monotonic()-stopped < 118:
        assert not list(dest.glob('*.zip')), 'Archive created before quiet period elapsed'
        time.sleep(0.5)
    wait_for(lambda:json.loads((state/'status.json').read_text())['status']=='idle', 30)
    archives = list(dest.glob('*.zip'));assert len(archives)==1
    manifest = save_backup.verify(archives[0]);assert manifest['kind']=='baseline'
    restored = fixture/'restored';save_backup.restore_copy(archives[0], restored)
    for name in manifest['files']:
        folder, rel = name.split('/',1);src = (world if folder=='world' else mod)/rel
        assert src.read_bytes()==(restored/name).read_bytes()
    receipt = {'parent_active_no_archives':True,'quick_relaunch_cancelled':True,
               'quiet_seconds':120,'archive_count':len(archives),'archive_bytes':archives[0].stat().st_size,
               'archive_sha256':hashlib.sha256(archives[0].read_bytes()).hexdigest(),
               'restored_copy_matches':True,'gameplay_test':False,'platform':'Win32 under isolated Wine'}
    (fixture/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt),flush=True)


if __name__=='__main__':main()

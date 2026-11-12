local root=assert(arg[1]);local logs,commands={},{}
local getenv,execute,open=os.getenv,os.execute,io.open
local env={root=root,config={},log=function(s) logs[#logs+1]=s end}
local variables={};os.getenv=function(k) return variables[k] end
os.execute=function(cmd) commands[#commands+1]=cmd;return true,'exit',0 end
io.open=function(path,mode) assert(path:find('/backup/python/pythonw.exe',1,true) and mode=='rb');return {close=function() end} end
local B=dofile(root..'src/backups.lua')(env)
env.config.automaticBackups=false;B.install();assert(#commands==0 and #logs==0)
env.config.automaticBackups=true;variables.GG_BACKUP_MANAGED='1';B.install();assert(#commands==0)
variables.GG_BACKUP_MANAGED=nil;variables.STEAM_COMPAT_DATA_PATH='prefix';B.install();assert(#commands==0)
variables.STEAM_COMPAT_DATA_PATH=nil;variables.WINEPREFIX='prefix';B.install();assert(#commands==0)
variables.WINEPREFIX=nil;env.root='C:\\Game Files\\ue4ss\\Mods\\BaseRangeGrowth\\';B.install()
assert(#commands==1 and commands[1]:find('pythonw.exe" -I',1,true))
assert(commands[1]:find('arm "C:\\Game Files\\ue4ss\\Mods\\BaseRangeGrowth""',1,true))
for _,bad in ipairs({'%PATH%', 'bad!name', 'bad"name', 'bad\nname'}) do
 env.root='C:\\'..bad..'\\';local ok=pcall(B.install);assert(not ok and #commands==1)
end
os.getenv,os.execute,io.open=getenv,execute,open
print('PASS: opt-out, no duplicate Proton companion, quoted paths, unsafe command paths rejected')

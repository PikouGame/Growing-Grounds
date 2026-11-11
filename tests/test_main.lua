local root=assert(arg[1],'pass root with trailing slash')
local realDofile=dofile
local function run()
    local loops,hooks,timers={},{},{}
    local counters={runtime=0,ui=0,storage=0,palbox=0}
    local config={resetToVanilla=false}
    local noop=function() end
    local function count(key) return function() counters[key]=counters[key]+1 end end
    local objects={install=noop,all=function() return {} end}
    dofile=function(path)
        local name=assert(path:match('([^/]+)%.lua$'))
        if name=='config' then return config end
        if name=='range' or name=='motion' or name=='texts' then return {} end
        return function(env)
            if name=='objects' then return objects end
            if name=='language' then return noop end
            if name=='settings' then return {key=noop,get=noop} end
            if name=='boundary' then return {} end
            if name=='runtime' then return {refresh=count('runtime')} end
            if name=='ui' or name=='world_settings' then
                assert(env.texts==noop,'the rows are built after the language reader exists')
            end
            if name=='ui' then return {refresh=count('ui')} end
            if name=='preview' then return {} end
            if name=='world_settings' then return {refresh=noop,installHooks=noop} end
            if name=='palbox' then return {refresh=count('palbox')} end
            if name=='storage' then return {refresh=count('storage'),changed=noop} end
            if name=='changes' then return {install=noop} end
            error('unexpected dependency '..path)
        end
    end
    RegisterKeyBind=function() error('No release may register keyboard shortcuts') end
    local function unsafe() error('GG must not schedule Lua on the async thread') end
    ExecuteWithDelay=unsafe;LoopAsync=unsafe;ExecuteInGameThread=unsafe
    ExecuteInGameThreadWithDelay=function(delay,callback)
        timers[delay]=timers[delay] or {};table.insert(timers[delay],callback)
    end
    LoopInGameThreadWithDelay=function(delay,callback) loops[delay]=callback end
    RegisterHook=function(path,_,post) hooks[path]=post end
    NotifyOnNewObject=noop
    assert(loadfile(root..'Scripts/main.lua'))()
    assert(loops[5000],'public reconciliation must still run')
    assert(#timers[1000]==1,'initial world discovery is still scheduled')
    loops[5000]()
    for _=1,20 do hooks['/Script/Pal.PalBaseCampModel:OnRep_Level_InGuildProperty']() end
    assert(#timers[0]==1 and counters.runtime==0,'overlapping events coalesce until the next game tick')
    table.remove(timers[0],1)()
    hooks['/Script/Pal.PalBaseCampModel:OnRep_Level_InGuildProperty']()
    table.remove(timers[0],1)()
    assert(counters.runtime==2 and counters.ui==2 and counters.storage==2 and counters.palbox==2,'an upgrade event refreshes runtime, ui and storage once each')
    dofile=realDofile
end
run()
for _,api in ipairs({'ExecuteInGameThreadWithDelay','LoopInGameThreadWithDelay'}) do
    local previous=_G[api];_G[api]=nil
    local ok,message=pcall(assert(loadfile(root..'Scripts/main.lua')))
    assert(not ok and message:find('requires UE4SS game%-thread timers'), 'unsupported loader fails before initializing the mod')
    _G[api]=previous
end
print('PASS: native timers only; coalesced upgrade/reconciliation; missing-API guard; no release hotkeys')

local root=assert(arg[1],'pass root with trailing slash')
local realDofile=dofile
local function run(development)
    local loops,hooks={},{}
    local counters={runtime=0,ui=0}
    local config={debug=development,resetToVanilla=false}
    local noop=function() end
    local function count(key) return function() counters[key]=counters[key]+1 end end
    local objects={install=noop,all=function() return {} end}
    dofile=function(path)
        local name=assert(path:match('([^/]+)%.lua$'))
        if name=='config' then return config end
        if name=='range' or name=='motion' then return {} end
        return function(env)
            if name=='objects' then return objects end
            if name=='settings' then return {key=noop,get=noop} end
            if name=='boundary' then return {} end
            if name=='runtime' then return {refresh=count('runtime')} end
            if name=='ui' then return {refresh=count('ui')} end
            if name=='preview' then return {} end
            if name=='world_settings' then return {refresh=noop,installHooks=noop} end
            if name=='changes' then return {install=noop} end
            error('unexpected dependency '..path)
        end
    end
    RegisterKeyBind=function() error('No release may register keyboard shortcuts') end
    ExecuteInGameThread=function(callback) callback() end
    ExecuteWithDelay=function() end
    LoopAsync=function(delay,callback) loops[delay]=callback end
    RegisterHook=function(path,_,post) hooks[path]=post end
    NotifyOnNewObject=noop
    assert(loadfile(root..'Scripts/main.lua'))()
    assert(loops[5000],'public reconciliation must still run')
    loops[5000]()
    hooks['/Script/Pal.PalBaseCampModel:OnRep_Level_InGuildProperty']()
    assert(counters.runtime==2 and counters.ui==2,'normal upgrade refresh is independent of debug')
    dofile=realDofile
end
run(false);run(true)
print('PASS: no keyboard shortcuts with debug on or off; native upgrades and reconciliation remain active')

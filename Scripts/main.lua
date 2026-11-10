-- BaseRangeGrowth 0.1.6-alpha: prompt change detection and a Palbox-to-boundary wave.
local script = debug.getinfo(1, 'S').source:gsub('^@', '')
local root = assert(script:match('^(.*[/\\])Scripts[/\\]main%.lua$'), 'Cannot resolve mod folder')
assert(type(ExecuteInGameThreadWithDelay)=='function' and type(LoopInGameThreadWithDelay)=='function',
    'Growing Grounds requires UE4SS game-thread timers (tested Palworld fork 2281fa31)')
local Range = dofile(root .. 'src/range.lua')
local Config = dofile(root .. 'config.lua')
local logOnce = {}
local function log(message) print('[BaseRangeGrowth] ' .. tostring(message) .. '\n') end
local function guard(label, fn)
    local ok, result = pcall(fn)
    if not ok and not logOnce[label] then
        logOnce[label] = true
        log(label .. ': ' .. tostring(result))
    end
    return ok, result
end
local function valid(object) return object and object:IsValid() end
local env = {root=root, range=Range, config=Config, log=log, guard=guard, valid=valid}
env.objects=dofile(root..'src/objects.lua')(env)
env.settings = dofile(root .. 'src/settings.lua')(root, Range, Config, nil, log)
env.worldId = function()
    local instance = env.objects.first('PalGameInstance')
    if not valid(instance) then return end
    local value = instance:GetSelectedWorldSaveDirectoryName()
    return env.settings.key(type(value)=='string' and value or value:ToString())
end
env.policy = function() return env.settings.get(env.worldId()) end
env.boundary = dofile(root .. 'src/boundary.lua')(env,dofile(root .. 'src/motion.lua'))
local Runtime = dofile(root .. 'src/runtime.lua')(env)
env.runtime=Runtime
env.preview=dofile(root .. 'src/preview.lua')(env)
local UI = dofile(root .. 'src/ui.lua')(env, Runtime)
local WorldSettings = dofile(root .. 'src/world_settings.lua')(env)
local Storage = dofile(root .. 'src/storage.lua')(env)
local pending = false
local function refresh()
    if pending then return end
    pending = true
    ExecuteInGameThreadWithDelay(0,function()
        guard('runtime refresh', Runtime.refresh)
        guard('storage refresh', Storage.refresh)
        guard('UI refresh', UI.refresh)
        guard('World Settings refresh', WorldSettings.refresh)
        pending = false
    end)
end

-- The native function exists in the installed build and is also used for
-- guild-wide level updates. A post-hook sees the newly committed level.
guard('level hook', function()
    RegisterHook('/Script/Pal.PalBaseCampModel:ReflectLevel_InGuildProperty_Internal', function() end, refresh)
end)
guard('client level hook', function()
    RegisterHook('/Script/Pal.PalBaseCampModel:OnRep_Level_InGuildProperty', function() end, refresh)
end)
env.objects.install(function(name)
    if name=='PalBaseCampModel' then ExecuteInGameThreadWithDelay(500,refresh)
    elseif name=='BP_BuildObject_PalBoxV2_C' or name=='WBP_IngameMenu_Mission_C' then
        ExecuteInGameThreadWithDelay(100,refresh)
    elseif name=='PalMapObjectItemChestModel' or name=='PalGroupGuild' then
        Storage.changed()
    end
end)
-- Keep the slow reconciliation, but do not make a real upgrade wait for it.
-- No terrain work or full runtime refresh occurs while level/radius are stable.
dofile(root..'src/changes.lua')(env).install(refresh)
guard('world settings notification', function()
    NotifyOnNewObject('/Script/Pal.PalUIWorldSettingBase', function()
        guard('World Settings hooks',WorldSettings.installHooks)
    end)
end)
guard('World Settings hooks',WorldSettings.installHooks)
-- A low-frequency reconciliation also handles late join, load order, streamed
-- Palboxes and radius replication arriving after the base-level notification.
-- Keep all Lua timers on the game thread. Async scheduling shares the loader's
-- Lua state with these callbacks and can corrupt its registry during execution.
LoopInGameThreadWithDelay(5000,refresh)
ExecuteInGameThreadWithDelay(1000,refresh)
log('v0.1.6-alpha loaded; tracked base changes every 250ms; Palbox wave; range bonus cap up to +300%; server owns gameplay; reset=' .. tostring(Config.resetToVanilla))

-- BaseRangeGrowth 0.1.3-alpha: prompt change detection and a Palbox-to-boundary wave.
local script = debug.getinfo(1, 'S').source:gsub('^@', '')
local root = assert(script:match('^(.*[/\\])Scripts[/\\]main%.lua$'), 'Cannot resolve mod folder')
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
env.settings = dofile(root .. 'src/settings.lua')(root, Range, Config)
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
local pending = false
local function refresh()
    if pending then return end
    pending = true
    ExecuteInGameThread(function()
        guard('runtime refresh', Runtime.refresh)
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
    if name=='PalBaseCampModel' then ExecuteWithDelay(500,refresh)
    elseif name=='BP_BuildObject_PalBoxV2_C' or name=='WBP_IngameMenu_Mission_C' then
        ExecuteWithDelay(100,refresh)
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
LoopAsync(5000, function() refresh(); return false end)
ExecuteWithDelay(1000, refresh)
log('v0.1.3-alpha loaded; tracked base changes every 250ms; Palbox wave; radius capped at 200%; server owns gameplay; reset=' .. tostring(Config.resetToVanilla))

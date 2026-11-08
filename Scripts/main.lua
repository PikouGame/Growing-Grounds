-- BaseRangeGrowth 0.1.0: Windows Palworld/PalServer, UE4SS Palworld fork.
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
local Runtime = dofile(root .. 'src/runtime.lua')(env)
local UI = dofile(root .. 'src/ui.lua')(env, Runtime)
local pending = false
local function refresh()
    if pending then return end
    pending = true
    ExecuteInGameThread(function()
        guard('runtime refresh', Runtime.refresh)
        guard('UI refresh', UI.refresh)
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
guard('base creation notification', function()
    NotifyOnNewObject('/Script/Pal.PalBaseCampModel', function()
        ExecuteWithDelay(500, refresh)
    end)
end)
guard('UI creation notification', function()
    NotifyOnNewObject('/Script/Pal.PalUIBaseCampTaskBase', function()
        ExecuteWithDelay(100, refresh)
    end)
end)
-- A low-frequency reconciliation also handles late join, load order, streamed
-- Palboxes and radius replication arriving after the base-level notification.
LoopAsync(5000, function() refresh(); return false end)
ExecuteWithDelay(1000, refresh)
RegisterKeyBind(Key.F10, {ModifierKey.CONTROL, ModifierKey.SHIFT}, function()
    refresh()
    ExecuteInGameThread(function() guard('diagnostic', Runtime.report) end)
end)
log('v0.1.0 loaded; server owns gameplay, clients read replicated radius; reset=' .. tostring(Config.resetToVanilla))

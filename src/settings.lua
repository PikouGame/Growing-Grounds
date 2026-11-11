-- Per-world settings sidecar. Data only: never execute a downloaded/save file.
-- Keep this file beside config.lua when updating or moving the installation.
return function(root, Range, defaults, filesystem, log, clock)
    local fs = filesystem or {open=io.open, rename=os.rename, remove=os.remove}
    local path = root .. 'world-settings.ini'
    local worlds, loaded, loadError = {}, false, nil
    -- An unreadable file is reported once and tried again at most every five seconds.
    -- Reads recover; saving stays refused until restart, because a menu draft
    -- taken meanwhile holds config.lua values, not this world's saved ones.
    local RETRY_SECONDS, lastTry, reported, everUnreadable = 5, nil, false, false
    clock = clock or os.time
    local S = {}
    local function key(value)
        -- Palworld world directory names are GUIDs. Reject traversal/newlines.
        if type(value)=='string' and #value==32 and value:match('^%x+$') then
            return value:upper()
        end
    end
    S.key = key
    local function load()
        if loaded then return end
        if loadError then
            local now = clock()
            -- A clock set back must not postpone the next attempt.
            if lastTry and now >= lastTry and now - lastTry < RETRY_SECONDS then return end
        end
        local file, err, code = fs.open(path, 'r')
        if not file and code == 2 then
            -- Recover if power was lost between the two Windows renames.
            file, err, code = fs.open(path..'.bak', 'r')
        end
        if not file then
            if code and code ~= 2 then
                loadError, lastTry, everUnreadable = err, clock(), true
                if log and not reported then
                    reported = true
                    log('Cannot read world-settings.ini, using config.lua values: '..tostring(err))
                end
            else
                loaded, loadError = true, nil
            end
            return
        end
        loaded, loadError, reported = true, nil, false
        worlds = {}
        local section
        for line in file:lines() do
            local heading = line:match('^%[([^%]]+)%]$')
            if heading then
                section = key(heading)
                if section then worlds[section] = {} end
            elseif section then
                local name, value = line:match('^(%w+)%s*=%s*([%d%.%-]+)%s*$')
                if name=='growthPercentPerLevel' or name=='maxRangeBonusPercent'
                    or name=='maxRangePercent' or name=='maxChestBonusSlots' then
                    worlds[section][name] = tonumber(value)
                end
            end
        end
        file:close()
    end
    local function normalize(values)
        local merged = {}
        for k,v in pairs(Range.settings(defaults)) do merged[k]=v end
        -- Prefer this world's legacy cap over the installation default.
        if values and values.maxRangeBonusPercent==nil and values.maxRangePercent~=nil then
            merged.maxRangeBonusPercent=nil
        end
        for k,v in pairs(values or {}) do merged[k]=v end
        return Range.settings(merged)
    end
    function S.get(world)
        load()
        return normalize(worlds[key(world)])
    end
    function S.save(world, values)
        local id = assert(key(world), 'World settings require a valid world ID')
        load()
        assert(not loadError, 'Cannot read existing world settings: '..tostring(loadError))
        assert(not everUnreadable, 'World settings were unreadable earlier in this session; restart before saving')
        local nextWorlds = {}
        for k,v in pairs(worlds) do nextWorlds[k] = v end
        nextWorlds[id] = normalize(values)
        local ids, lines = {}, {'; Growing Grounds per-world settings. Keep when updating.\n'}
        for k in pairs(nextWorlds) do ids[#ids+1] = k end
        table.sort(ids)
        for _,k in ipairs(ids) do
            local value = normalize(nextWorlds[k])
            lines[#lines+1] = string.format('[%s]\nmaxRangeBonusPercent=%.6g\nmaxChestBonusSlots=%d\n',
                k, value.maxRangeBonusPercent, value.maxChestBonusSlots)
        end
        local temp, backup = path..'.tmp', path..'.bak'
        local file = assert(fs.open(temp, 'w'))
        local ok, err = file:write(table.concat(lines, '\n'))
        local closed, closeErr = file:close()
        assert(ok and closed, err or closeErr or 'Cannot write world settings')
        -- Windows cannot rename over an existing file. Retain a recoverable
        -- backup and restore it if the second rename fails.
        local old = fs.open(path, 'r')
        if old then
            old:close()
            fs.remove(backup)
            assert(fs.rename(path, backup))
        end
        local moved, moveErr = fs.rename(temp, path)
        if not moved then
            if old then fs.rename(backup, path) end
            error(moveErr or 'Cannot commit world settings')
        end
        worlds = nextWorlds
        return S.get(id)
    end
    return S
end

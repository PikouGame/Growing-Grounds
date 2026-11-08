-- Per-world settings sidecar. Data only: never execute a downloaded/save file.
-- Keep this file beside config.lua when updating or moving the installation.
return function(root, Range, defaults, filesystem)
    local fs = filesystem or {open=io.open, rename=os.rename, remove=os.remove}
    local path = root .. 'world-settings.ini'
    local worlds, loaded, loadError = {}, false, nil
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
        loaded = true
        local file, err, code = fs.open(path, 'r')
        if not file and code == 2 then
            -- Recover if power was lost between the two Windows renames.
            file, err, code = fs.open(path..'.bak', 'r')
        end
        if not file then
            if code and code ~= 2 then loadError = err end
            return
        end
        local section
        for line in file:lines() do
            local heading = line:match('^%[([^%]]+)%]$')
            if heading then
                section = key(heading)
                if section then worlds[section] = {} end
            elseif section then
                local name, value = line:match('^(%w+)%s*=%s*([%d%.%-]+)%s*$')
                if name=='growthPercentPerLevel' or name=='maxRangePercent' then
                    worlds[section][name] = tonumber(value)
                end
            end
        end
        file:close()
    end
    function S.get(world)
        load()
        return Range.settings(worlds[key(world)] or defaults)
    end
    function S.save(world, values)
        local id = assert(key(world), 'World settings require a valid world ID')
        load()
        assert(not loadError, 'Cannot read existing world settings: '..tostring(loadError))
        local nextWorlds = {}
        for k,v in pairs(worlds) do nextWorlds[k] = v end
        nextWorlds[id] = Range.settings(values)
        local ids, lines = {}, {'; Growing Grounds per-world settings. Keep when updating.\n'}
        for k in pairs(nextWorlds) do ids[#ids+1] = k end
        table.sort(ids)
        for _,k in ipairs(ids) do
            local value = Range.settings(nextWorlds[k])
            lines[#lines+1] = string.format('[%s]\ngrowthPercentPerLevel=%.6g\nmaxRangePercent=%.6g\n',
                k, value.growthPercentPerLevel, value.maxRangePercent)
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

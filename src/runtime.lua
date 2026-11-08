return function(E)
    local R = {}
    local baselines, seen, ringTargets = {}, {}, {}
    local function utility() return StaticFindObject('/Script/Pal.Default__PalUtility') end
    local function guid(g) return table.concat({g.A, g.B, g.C, g.D}, ':') end
    local function zeroGuid(g) return g.A == 0 and g.B == 0 and g.C == 0 and g.D == 0 end
    local function positive(n) return type(n) == 'number' and n == n and n > 0 and n < math.huge end
    function R.baseline(model)
        local settings = utility():GetGameSetting(model)
        assert(E.valid(settings), 'Game settings unavailable')
        local key = settings:GetFullName()
        if not baselines[key] then
            local radius = settings.BaseCampAreaRange
            assert(positive(radius), 'Invalid original base radius')
            baselines[key] = radius
        end
        return baselines[key]
    end
    function R.isAuthority(model) return utility():IsServer(model) end
    function R.maxLevel()
        local data = FindFirstOf('PalMasterDataTableAccess_BaseCampLevelData')
        assert(E.valid(data), 'Base-level table not loaded')
        local maximum = data:GetMaxLevel()
        assert(type(maximum) == 'number' and maximum >= 1 and maximum % 1 == 0, 'Invalid max base level')
        return maximum
    end
    function R.snapshot(model)
        local baseline, level = R.baseline(model), model:GetLevel()
        local radius, maximum = model:GetRange(), R.maxLevel()
        assert(positive(radius), 'Base radius not replicated yet')
        assert(level >= 1 and level <= maximum, 'Base level not ready')
        local expected = E.range.radius(baseline, level)
        local authority = R.isAuthority(model)
        -- Clients display the actual replicated current value. A mismatched
        -- curve never advertises the configured upgrade as a server fact.
        local followsCurve = math.abs(radius - expected) < 0.5
        local nextKnown = authority or (level > 1 and followsCurve)
        return {
            level=level, maximum=maximum, radius=radius, baseline=baseline,
            currentPercent=radius / baseline * 100,
            nextPercent=nextKnown and not E.config.resetToVanilla
                and E.range.percent(math.min(level + 1, maximum)) or nil,
            atMaximum=level >= maximum, authority=authority,
        }
    end
    local function reassociate(model, oldRadius, radius)
        if radius <= oldRadius then return end
        local manager = utility():GetBaseCampManager(model)
        if not E.valid(manager) then return end
        local group, base = guid(model:GetGroupIdBelongTo()), guid(model:GetId())
        local changed = 0
        -- Only unassigned structures in this guild are candidates. The game's
        -- own containment check resolves overlaps; existing base ownership wins.
        for _, object in ipairs(FindAllOf('PalMapObjectModel') or {}) do
            if E.valid(object) and zeroGuid(object.BaseCampIdBelongTo)
                    and guid(object.GroupIdBelongTo) == group then
                local location = object.WorkableBounds.Location
                local target = manager:GetInRangedBaseCamp(location, 0)
                if E.valid(target) and guid(target:GetId()) == base then
                    manager:OnCreateMapObjectModelInServer(object, location)
                    changed = changed + 1
                end
            end
        end
        E.log('rechecked ' .. changed .. ' unassigned guild structures inside expanded base')
    end
    function R.apply(model)
        if not E.valid(model) or not model:IsAvailable() or not R.isAuthority(model) then return false end
        -- Temporary raid arenas use a different lifetime and are excluded.
        if model.bTemporary then return false end
        local baseline, level = R.baseline(model), model:GetLevel()
        if level < 1 or level > R.maxLevel() then return false end
        local target = E.config.resetToVanilla and baseline or E.range.radius(baseline, level)
        local current = model:GetRange()
        if math.abs(current - target) < 0.1 then return false end
        model.AreaRange = target
        assert(math.abs(model:GetRange() - target) < 0.1, 'Server radius write did not stick')
        E.log(string.format('authority base %s: level %d, %.2f -> %.2f cm', guid(model:GetId()), level, current, target))
        E.guard('worker status refresh', function()
            local director = model.WorkerDirector
            if E.valid(director) then director:OnUpdateOwnerBaseCampStatus_ServerInternal(model) end
        end)
        E.guard('building membership refresh', function() reassociate(model, current, target) end)
        return true
    end
    function R.updateRing(actor, byId)
        if not E.valid(actor) then return end
        local mapModel = actor:GetModel()
        if not E.valid(mapModel) then return end
        local concrete = mapModel:GetConcreteModel(false)
        if not E.valid(concrete) or concrete.bForRaidBossArea then return end
        local base = byId[guid(concrete.BaseCampId)]
        if not E.valid(base) then return end
        local radius = base:GetRange()
        if not positive(radius) then return end
        -- Installed game's Cylinder mesh is 100 cm across. Its two authored
        -- rings are 70 and 70.01 XY at the original 3500 cm radius. Preserve Z.
        for _, field in ipairs({'AreaRange', 'AreaRange1'}) do
            local component = actor[field]
            if E.valid(component) then
                local desired = radius / 50 + (field == 'AreaRange1' and 0.01 or 0)
                local scale = component.RelativeScale3D
                if math.abs(scale.X - desired) > 0.001 or math.abs(scale.Y - desired) > 0.001 then
                    component:SetRelativeScale3D({X=desired, Y=desired, Z=scale.Z})
                end
                local key = component:GetFullName()
                if ringTargets[key] ~= radius then
                    ringTargets[key] = radius
                    if E.config.debug then E.log(string.format('boundary %s = %.2f cm', field, radius)) end
                end
            end
        end
    end
    function R.refresh()
        local byId, live = {}, {}
        for _, model in ipairs(FindAllOf('PalBaseCampModel') or {}) do
            E.guard('base sync', function()
                if not E.valid(model) or not model:IsAvailable() then return end
                local id = guid(model:GetId())
                byId[id] = model
                live[id] = true
                if not seen[id] then
                    seen[id] = true
                    E.log(string.format('base ready: role=%s level=%d radius=%.2f cm',
                        R.isAuthority(model) and 'authority' or 'client', model:GetLevel(), model:GetRange()))
                end
                R.apply(model)
            end)
        end
        for id in pairs(seen) do if not live[id] then seen[id] = nil end end
        if next(byId) then
            for _, actor in ipairs(FindAllOf('BP_BuildObject_PalBoxV2_C') or {}) do
                E.guard('boundary sync', function() R.updateRing(actor, byId) end)
            end
        end
    end
    function R.report()
        for _, model in ipairs(FindAllOf('PalBaseCampModel') or {}) do
            if E.valid(model) then
                local s = R.snapshot(model)
                E.log(string.format('CHECK role=%s level=%d radius=%.2f baseline=%.2f percent=%.2f max=%d',
                    s.authority and 'authority' or 'client', s.level, s.radius, s.baseline, s.currentPercent, s.maximum))
            end
        end
    end
    return R
end

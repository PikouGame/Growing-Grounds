return function(E)
    local R = {}
    local scale=dofile(E.root..'src/ring.lua')(E)
    local baselines, seen, originalSpacing = {}, {}, {}
    local function find(path)
        if E.objects then return E.objects.find(path) end
        return StaticFindObject(path)
    end
    local function all(name) return E.objects and E.objects.all(name) or FindAllOf(name) or {} end
    local function first(name)
        if E.objects then return E.objects.first(name) end
        return FindFirstOf(name)
    end
    local function utility() return find('/Script/Pal.Default__PalUtility') end
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
    function R.policy(model)
        return E.range.settings(E.policy and E.policy(model) or E.config)
    end
    function R.bonuses(model)
        local policy=R.policy(model)
        return {rangeEnabled=not E.config.resetToVanilla and policy.maxRangeBonusPercent>0 and policy.growthPercentPerLevel>0,
            chestCap=E.config.resetToVanilla and 0 or policy.maxChestBonusSlots}
    end
    function R.updatePlacement(context)
        local settings = utility():GetGameSetting(context)
        assert(E.valid(settings), 'Placement settings unavailable')
        local key = settings:GetFullName()
        local policy = R.policy(context)
        local required = E.range.placementDistance(R.baseline(context), policy)
        -- Native placement validation uses these PvE/PvP settings. Keep any
        -- stronger existing restriction, and never modify the baseline radius.
        if not originalSpacing[key] then
            originalSpacing[key] = {
                BaseCampNeighborMinimumDistance=settings.BaseCampNeighborMinimumDistance,
                BaseCampNeighborMinimumDistance_PVP=settings.BaseCampNeighborMinimumDistance_PVP,
            }
        end
        for field, original in pairs(originalSpacing[key]) do
            assert(type(original)=='number' and original==original and original>=0
                and original<math.huge, 'Invalid native placement distance')
            local target = not R.bonuses(context).rangeEnabled and original or math.max(original, required)
            if settings[field] ~= target then
                settings[field] = target
                assert(math.abs(settings[field]-target)<0.1, 'Placement setting write did not stick')
                E.log(string.format('%s = %.2f cm',field,target))
            end
        end
    end
    function R.targets(models, nextGroup, nextLevel, fullGrowth)
        local entries, byId = {}, {}
        for _, model in ipairs(models) do
            if E.valid(model) and model:IsAvailable() and not model.bTemporary then
                local baseline = R.baseline(model)
                local policy = R.policy(model)
                local level = model:GetLevel()
                if nextGroup and guid(model:GetGroupIdBelongTo()) == nextGroup then level = nextLevel end
                local position = model:GetTransform().Translation
                local maximum=E.config.resetToVanilla and baseline or baseline * (1 + policy.maxRangeBonusPercent / 100)
                entries[#entries+1] = {
                    id=guid(model:GetId()), baseline=baseline, x=position.X, y=position.Y,
                    desired=fullGrowth and maximum or (E.config.resetToVanilla and baseline or E.range.radius(baseline, level, policy)),
                    maximum=maximum,
                }
            end
        end
        local values, conflicts = E.range.separate(entries)
        for i, entry in ipairs(entries) do byId[entry.id] = values[i] end
        if #conflicts > 0 and not seen.vanillaOverlap then
            seen.vanillaOverlap = true
            E.log('existing vanilla-sized bases overlap; growth stopped for those bases; no bases moved or removed')
        end
        return byId
    end
    function R.maxLevel()
        local data = first('PalMasterDataTableAccess_BaseCampLevelData')
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
        local authority = R.isAuthority(model)
        -- A matching current radius cannot establish a remote server's cap,
        -- growth settings or nearby-base limits. Use a server-authored preview.
        local nextRadius
        local nextPercent
        local bonuses
        if authority then
            bonuses=R.bonuses(model)
            local models = all('PalBaseCampModel')
            if #models == 0 then models = {model} end
            nextRadius = R.targets(models, guid(model:GetGroupIdBelongTo()), math.min(level+1,maximum))[guid(model:GetId())]
            nextPercent=not E.config.resetToVanilla and nextRadius and nextRadius/baseline*100 or nil
        elseif E.preview then
            nextPercent,bonuses=E.preview.read(model,baseline,level,radius)
        end
        return {
            level=level, maximum=maximum, radius=radius, baseline=baseline,
            currentPercent=radius / baseline * 100,
            nextPercent=nextPercent,
            rangeEnabled=bonuses and bonuses.rangeEnabled,
            chestCurrent=bonuses and bonuses.chestCap and bonuses.chestCap>0 and math.min(level-1,bonuses.chestCap) or nil,
            chestNext=bonuses and bonuses.chestCap and bonuses.chestCap>0 and math.min(level,bonuses.chestCap) or nil,
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
    function R.apply(model, planned, changed)
        if not E.valid(model) or not model:IsAvailable() or not R.isAuthority(model) then return false end
        -- Temporary raid arenas use a different lifetime and are excluded.
        if model.bTemporary then return false end
        local baseline, level = R.baseline(model), model:GetLevel()
        if level < 1 or level > R.maxLevel() then return false end
        local targets = planned
        if not targets then
            local models = all('PalBaseCampModel')
            if #models == 0 then models = {model} end
            targets = R.targets(models)
        end
        local target = targets[guid(model:GetId())]
        assert(positive(target), 'Safe radius plan unavailable')
        local current = model:GetRange()
        if math.abs(current - target) < 0.1 then return false end
        model.AreaRange = target
        assert(math.abs(model:GetRange() - target) < 0.1, 'Server radius write did not stick')
        E.log(string.format('authority base %s: level %d, %.2f -> %.2f cm', guid(model:GetId()), level, current, target))
        E.guard('worker status refresh', function()
            local director = model.WorkerDirector
            if E.valid(director) then director:OnUpdateOwnerBaseCampStatus_ServerInternal(model) end
        end)
        if changed then
            changed[#changed+1] = {model=model, previous=current, target=target}
        else
            E.guard('building membership refresh', function() reassociate(model, current, target) end)
        end
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
        if E.preview and R.isAuthority(base) then
            E.guard('server preview',function()
                E.preview.publish(actor,base,E.previewValues and E.previewValues[guid(concrete.BaseCampId)])
            end)
        end
        if E.boundary then
            local ok = E.guard('boundary presentation',function()
                E.boundary.update(actor,base,guid(concrete.BaseCampId),radius)
            end)
            if ok then return end -- unsupported presentation API: exact old path below
        end
        scale(actor,radius)
    end
    function R.refresh()
        if E.boundary then E.boundary.beginRefresh() end
        if E.preview then E.guard('preview discovery',E.preview.refresh) end
        local byId, live = {}, {}
        local models = all('PalBaseCampModel')
        local context = models[1] or first('PalGameInstance')
        if E.valid(context) then E.guard('base placement distance', function() R.updatePlacement(context) end) end
        -- Plan every radius before mutating any, so enumeration order never
        -- gives one guild priority or makes the result oscillate across ticks.
        local planned = R.targets(models)
        if E.preview and E.valid(context) and R.isAuthority(context) then
            E.guard('preview values',function()
            E.previewValues={}
            -- Maximum proximity budgets are independent of levels; calculate
            -- once for all bases instead of an O(n^3) per-base prediction pass.
            local limits=R.targets(models,nil,nil,true)
            for _,model in ipairs(models) do
                if E.valid(model) and model:IsAvailable() and not model.bTemporary and R.isAuthority(model)
                        and not E.config.resetToVanilla then
                    local id=guid(model:GetId())
                    local baseline=R.baseline(model)
                    local future=E.range.radius(baseline,math.min(model:GetLevel()+1,R.maxLevel()),R.policy(model))
                    E.previewValues[id]=math.min(limits[id],future)/baseline*100
                end
            end
            end)
        end
        -- Shrink first, then expand; native containment must never see an
        -- expansion against a neighbour that still has its previous radius.
        local ordered, changed = {}, {}
        for _,model in ipairs(models) do
            if E.valid(model) and model:IsAvailable() and not model.bTemporary then ordered[#ordered+1]=model end
        end
        table.sort(ordered,function(a,b)
            local da = planned[guid(a:GetId())] - a:GetRange()
            local db = planned[guid(b:GetId())] - b:GetRange()
            return da < db
        end)
        for _, model in ipairs(ordered) do
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
                R.apply(model, planned, changed)
            end)
        end
        for _,change in ipairs(changed) do
            E.guard('building membership refresh',function()
                reassociate(change.model,change.previous,change.target)
            end)
        end
        for id in pairs(seen) do if id ~= 'vanillaOverlap' and not live[id] then seen[id] = nil end end
        if next(byId) then
            for _, actor in ipairs(all('BP_BuildObject_PalBoxV2_C')) do
                E.guard('boundary sync', function() R.updateRing(actor, byId) end)
            end
        end
        if E.boundary then E.boundary.endRefresh() end
        if E.preview then E.guard('preview cleanup',E.preview.finish) end
    end
    return R
end

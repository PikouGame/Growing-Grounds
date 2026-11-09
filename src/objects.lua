-- One initial lookup for these small sets; construction notifications add new
-- objects and validity/name checks remove destroyed or recycled wrappers.
-- This module is local to Growing Grounds and never replaces UE4SS globals.
return function(E)
    local O={}
    local definitions={
        PalBaseCampModel='/Script/Pal.PalBaseCampModel',
        BP_BuildObject_PalBoxV2_C='/Game/Pal/Blueprint/MapObject/BuildObject/BP_BuildObject_PalBoxV2.BP_BuildObject_PalBoxV2_C',
        WBP_IngameMenu_Mission_C='/Game/Pal/Blueprint/UI/UserInterface/IngameMenu/Task/WBP_IngameMenu_Mission.WBP_IngameMenu_Mission_C',
        PalGameInstance='/Script/Pal.PalGameInstance',
        PalMasterDataTableAccess_BaseCampLevelData='/Script/Pal.PalMasterDataTableAccess_BaseCampLevelData',
        PalMapObjectItemChestModel='/Script/Pal.PalMapObjectItemChestModel',
        PalGroupGuild='/Script/Pal.PalGroupGuild',
    }
    local sets,paths={},{}
    local function current(record)
        return record and E.valid(record.object) and record.object:GetFullName()==record.name
    end
    function O.find(path)
        local record=paths[path]
        if current(record) then return record.object end
        local object=StaticFindObject(path)
        paths[path]=E.valid(object) and {object=object,name=object:GetFullName()} or nil
        return object
    end
    local function state(name)
        if not sets[name] then sets[name]={seeded=false,watched=false,records={},pending={}} end
        return sets[name]
    end
    local function add(s,object)
        if E.valid(object) and not object:HasAnyFlags(0x30) then
            local name=object:GetFullName()
            s.records[name]={object=object,name=name}
        end
    end
    function O.all(name)
        if not definitions[name] then return FindAllOf(name) or {} end
        local s=state(name)
        -- If a notification could not be registered, preserve correctness with
        -- the original lookup; never silently freeze membership at startup.
        if not s.seeded or not s.watched then
            s.records={}
            for _,object in ipairs(FindAllOf(name) or {}) do add(s,object) end
            s.seeded=true
        end
        for _,object in ipairs(s.pending) do add(s,object) end
        s.pending={}
        local result={}
        for name,record in pairs(s.records) do
            if current(record) then result[#result+1]=record.object
            else s.records[name]=nil end
        end
        return result
    end
    function O.first(name) return O.all(name)[1] end
    -- Frequent observers must never activate the global-search fallback. The
    -- ordinary reconciliation seeds this set and remains responsible for
    -- discovery if construction notifications are unavailable.
    function O.tracked(name)
        local s=sets[name]
        if not s or not s.seeded or not s.watched then return end
        return O.all(name)
    end
    function O.install(onCreated)
        for name,path in pairs(definitions) do
            local s=state(name)
            if not s.watched then
                local ok=E.guard('object notifications '..name,function()
                    NotifyOnNewObject(path,function(object)
                        -- Defer inspection until the next game-thread refresh:
                        -- the constructed object may still be initializing.
                        s.pending[#s.pending+1]=object
                        if onCreated then onCreated(name,object) end
                    end)
                end)
                s.watched=ok
            end
        end
    end
    return O
end

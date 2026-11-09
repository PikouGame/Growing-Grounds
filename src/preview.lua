-- Server-authored UI data on a mod-owned native SceneComponent. It replicates
-- through the existing Palbox actor channel; a standalone TargetPoint was not
-- delivered to the live client. No game component is repurposed.
-- X/Y are hundredths of current/next percent. Z carries a version marker, level,
-- range-enabled flag and chest cap as exact integers. No extra replicated object.
return function(E)
    local P = {}
    local marker, records, reported = {}, {}, {}
    local MAGIC, LEGACY, MAX_LEVEL = 400000, 232000, 1000
    local componentPath='/Script/Engine.SceneComponent'
    local function find(path)
        if E.objects then return E.objects.find(path) end
        return StaticFindObject(path)
    end
    local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
    local function guid(g) return table.concat({g.A,g.B,g.C,g.D},':') end
    local function authority(actor)
        return find('/Script/Pal.Default__PalUtility'):IsServer(actor)
    end
    local function decode(location)
        if not location then return end
        local x,y,z=location.X,location.Y,location.Z
        if not finite(x) or not finite(y) or not finite(z) then return end
        local payload=z-MAGIC
        local level,rangeEnabled,chestCap
        if payload>=1 then
            local flags=math.floor(payload/(MAX_LEVEL+1))
            if flags<0 or flags>81 then return end
            level=payload-flags*(MAX_LEVEL+1)
            rangeEnabled,chestCap=flags%2==1,math.floor(flags/2)
        else
            level=z-LEGACY -- older servers provide radius preview only
        end
        if level<1 or level>MAX_LEVEL or math.abs(level-math.floor(level+0.5))>0.01 then return end
        level=math.floor(level+0.5)
        if x<9999 or x>40001 or (y~=-100 and (y<9999 or y>40001)) then return end
        return {level=level,current=x/100,nextPercent=y~=-100 and y/100 or nil,
            rangeEnabled=rangeEnabled,chestCap=chestCap}
    end
    local function ownerBase(actor)
        local owner=actor:GetOwner()
        if not E.valid(owner) then return end
        if not owner:IsA(find('/Script/Pal.PalBuildObjectBaseCampPoint')) then return end
        local model=owner:GetModel()
        if not E.valid(model) then return end
        local concrete=model:GetConcreteModel(false)
        if not E.valid(concrete) or concrete.bForRaidBossArea then return end
        return guid(concrete.BaseCampId),owner
    end
    local function ours(component)
        if not E.valid(component) then return end
        -- Only our bare scene component may carry this protocol, never one of
        -- the game's meshes or a component belonging to another actor type.
        if component:GetClass():GetFullName()~='Class '..componentPath then return end
        return decode(component.RelativeLocation)
    end
    function P.read(model,baseline,level,radius)
        local record=records[guid(model:GetId())]
        if not record or not E.valid(record.actor) then return end
        -- Read the latest native transform: level/radius can replicate before
        -- or after the preview. Never show a value belonging to another state.
        local value=ours(record.actor)
        if not value or value.level~=level or math.abs(value.current-radius/baseline*100)>0.05 then return end
        if record.actor:GetFullName()~=record.path then return end
        local id=guid(model:GetId())
        if ownerBase(record.actor)~=id then return end
        local signature=table.concat({level,value.current,tostring(value.nextPercent)},':')
        if reported[id]~=signature then
            reported[id]=signature
            E.log(string.format('received server preview: level=%d current=%.2f next=%s',
                level,value.current,tostring(value.nextPercent)))
        end
        return value.nextPercent,value
    end
    function P.refresh()
        records={}
        local boxes=E.objects and E.objects.all('BP_BuildObject_PalBoxV2_C') or FindAllOf('BP_BuildObject_PalBoxV2_C') or {}
        local class=find(componentPath)
        if E.valid(class) then
            for _,box in ipairs(boxes) do
                if E.valid(box) then
                    -- UE4SS 2281fa31 returns a Lua array of RemoteUnrealParam here,
                    -- unlike a reflected TArray property with a ForEach method.
                    for _,item in ipairs(box:K2_GetComponentsByClass(class)) do
                        local component=item:get()
                        if ours(component) then
                            local id=ownerBase(component)
                            if id then
                                records[id]={actor=component,path=component:GetFullName()}
                            end
                        end
                    end
                end
            end
        end
        for _,state in pairs(marker) do state.live=false end
    end
    function P.publish(palbox,model,nextPercent)
        if not authority(model) then return end
        local id=guid(model:GetId())
        local baseline=E.runtime.baseline(model)
        local bonuses=E.runtime.bonuses(model)
        local location={X=model:GetRange()/baseline*10000,
            Y=nextPercent and nextPercent*100 or -100,
            Z=MAGIC+model:GetLevel()+(MAX_LEVEL+1)*(bonuses.chestCap*2+(bonuses.rangeEnabled and 1 or 0))}
        assert(decode(location),'Invalid server preview')
        local state=marker[id]
        local actor=state and state.actor
        if not E.valid(actor) or actor:GetFullName()~=state.path then
            -- Reuse our own native marker after a Lua reload when possible.
            local old=records[id]
            actor=old and old.actor
            if not E.valid(actor) then
                assert(palbox.bReplicates,'Palbox actor is not replicated')
                local class=find(componentPath)
                assert(E.valid(class),'Native preview component class unavailable')
                -- Wake the existing channel before creating or modifying its
                -- replicated subobject. Do not change the Palbox's dormancy policy.
                palbox:FlushNetDormancy()
                actor=palbox:AddComponentByClass(class,true,{
                    Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1},
                },false)
                assert(E.valid(actor),'Native preview component creation failed')
                local ok,err=pcall(function()
                    actor:SetMobility(2)
                    actor:SetComponentTickEnabled(false)
                    actor:SetVisibility(false,false)
                    actor:SetHiddenInGame(true,false)
                    actor:K2_SetRelativeLocation(location,false,{},true)
                    actor:SetIsReplicated(true)
                    assert(ours(actor),'Preview component setup did not stick')
                end)
                if not ok then actor:K2_DestroyComponent(palbox);error(err) end
                palbox:ForceNetUpdate()
                E.log('server upgrade preview component created on Palbox channel')
            end
            state={actor=actor,path=actor:GetFullName()}
            marker[id]=state
        end
        state.live=true
        local old=actor.RelativeLocation
        if math.abs(old.X-location.X)>0.01 or math.abs(old.Y-location.Y)>0.01 or old.Z~=location.Z then
            palbox:FlushNetDormancy()
            actor:K2_SetRelativeLocation(location,false,{},true)
            palbox:ForceNetUpdate()
        end
    end
    function P.finish()
        for id,state in pairs(marker) do
            if not state.live then
                if E.valid(state.actor) and state.actor:GetFullName()==state.path then
                    local owner=state.actor:GetOwner()
                    if E.valid(owner) and authority(owner) then
                        owner:FlushNetDormancy()
                        state.actor:K2_DestroyComponent(owner)
                        owner:ForceNetUpdate()
                    end
                end
                marker[id]=nil
            end
        end
    end
    return P
end

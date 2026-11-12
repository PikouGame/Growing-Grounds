-- Server-authored UI data on a mod-owned native SceneComponent. It replicates
-- through the existing Palbox actor channel; a standalone TargetPoint was not
-- delivered to the live client. No game component is repurposed.
-- X/Y are hundredths of current/next percent. Z carries a version marker, level,
-- range-enabled flag and chest cap as exact integers. No extra replicated object.
-- Legacy scale stores a maximum radius and repeated radius/policy stamp.
-- Total-cap scale stores maximum radius, packed start/end and a repeated revision.
-- Split replication never borrows the client's own settings.
return function(E)
    local P = {}
    local marker, records, reported = {}, {}, {}
    local MAGIC, LEGACY, MAX_LEVEL = 400000, 232000, 1000
    -- Fixed wire radix: 7 bits hold chest cap + range flag; Palbox cap follows.
    -- The largest encoded position stays below 2^24 (exact float integers).
    local PALBOX_MAGIC, FLAGS_RADIX = 1000000, 128
    -- Version 4 uses a negative stamp (old clients reject it). Scale.Y packs
    -- start/total; scale.Z repeats the stamp so split property updates are hidden.
    -- A 7-bit revision changes with either policy or preview. All stamps < 2^24.
    local TOTAL_RADIX, REVISIONS = 97, 128
    local componentPath='/Script/Engine.SceneComponent'
    local function find(path) return E.objects.find(path) end
    local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
    local function guid(g) return table.concat({g.A,g.B,g.C,g.D},':') end
    local function authority(actor)
        return find('/Script/Pal.Default__PalUtility'):IsServer(actor)
    end
    local function decode(location)
        if not location then return end
        local x,y,z=location.X,location.Y,location.Z
        if not finite(x) or not finite(y) or not finite(z) then return end
        local limits=E.range.limits
        local payload=z-MAGIC
        local level,rangeEnabled,chestCap,palboxCap,revision
        if z<0 then
            if z%1~=0 then return end
            payload=-z-1
            local packed=math.floor(payload/(MAX_LEVEL+1))
            local flags=packed%FLAGS_RADIX
            revision=math.floor(packed/FLAGS_RADIX)
            level=payload-packed*(MAX_LEVEL+1)
            if revision>=REVISIONS or flags>limits.maxChestBonusSlots*2+1 then return end
            rangeEnabled,chestCap=flags%2==1,math.floor(flags/2)
        elseif z>=PALBOX_MAGIC then
            payload=z-PALBOX_MAGIC
            local packed=math.floor(payload/(MAX_LEVEL+1))
            palboxCap=math.floor(packed/FLAGS_RADIX)
            local flags=packed%FLAGS_RADIX
            if palboxCap>64 or flags>limits.maxChestBonusSlots*2+1 then return end
            level=payload-packed*(MAX_LEVEL+1)
            rangeEnabled,chestCap=flags%2==1,math.floor(flags/2)
        elseif payload>=1 then
            local flags=math.floor(payload/(MAX_LEVEL+1))
            if flags<0 or flags>limits.maxChestBonusSlots*2+1 then return end
            level=payload-flags*(MAX_LEVEL+1)
            rangeEnabled,chestCap=flags%2==1,math.floor(flags/2)
        else
            level=z-LEGACY -- older servers provide radius preview only
        end
        if level<1 or level>MAX_LEVEL or math.abs(level-math.floor(level+0.5))>0.01 then return end
        level=math.floor(level+0.5)
        local maxPercent=(100+limits.maxRangeBonusPercent)*100+1
        if x<9999 or x>maxPercent or (y~=-100 and (y<9999 or y>maxPercent)) then return end
        return {level=level,current=x/100,nextPercent=y~=-100 and y/100 or nil,
            rangeEnabled=rangeEnabled,chestCap=chestCap,palboxCap=palboxCap,totalRevision=revision}
    end
    local function ownerBase(component)
        local owner=component:GetOwner()
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
    local function state(model)
        local id=guid(model:GetId())
        local record=records[id]
        if not record or not E.valid(record.component) then return end
        if record.component:GetFullName()~=record.path then return end
        -- P.refresh proved the owner and class when it recorded this component;
        -- the 250 ms watcher only needs the identity and the current value.
        local location=record.component.RelativeLocation
        local value=decode(location)
        local scale=record.component.RelativeScale3D
        if value and value.totalRevision~=nil then
            if scale and finite(scale.X) and finite(scale.Y) and scale.Z==location.Z
                    and scale.Y%1==0 and scale.Y>=0 and scale.Y<TOTAL_RADIX*TOTAL_RADIX then
                local start,maximum=scale.Y%TOTAL_RADIX,math.floor(scale.Y/TOTAL_RADIX)
                if start>=1 and maximum>=start and maximum<=E.range.limits.maxPalboxBoxes then
                    value.palboxStart,value.palboxMaximum=start,maximum
                end
                if scale.X>=9999 and scale.X<=(100+E.range.limits.maxRangeBonusPercent)*100+1 then
                    value.maximumPercent=scale.X/100
                end
            end
        elseif value and scale and finite(scale.X) and finite(scale.Y) and finite(scale.Z)
                and math.abs(scale.Y-location.X)<=0.01 and scale.Z==location.Z
                and scale.X>=9999 and scale.X<=(100+E.range.limits.maxRangeBonusPercent)*100+1 then
            value.maximumPercent=scale.X/100
        end
        return value
    end
    function P.revision(model)
        local value=state(model)
        if not value then return end
        return table.concat({value.level,value.current,tostring(value.nextPercent),
            tostring(value.rangeEnabled),tostring(value.chestCap),tostring(value.palboxCap),
            tostring(value.maximumPercent),tostring(value.palboxStart),tostring(value.palboxMaximum)},':')
    end
    function P.read(model,baseline,level,radius)
        -- Policy remains server-authored during split replication. The UI must
        -- wait for a coherent level/radius/preview before replacing its values.
        local value=state(model)
        if not value or value.level~=level or math.abs(value.current-radius/baseline*100)>0.05 then
            return nil,value,true
        end
        local id=guid(model:GetId())
        local signature=table.concat({level,value.current,tostring(value.nextPercent),tostring(value.maximumPercent),tostring(value.palboxStart),tostring(value.palboxMaximum)},':')
        if reported[id]~=signature then
            reported[id]=signature
            E.log(string.format('received server preview: level=%d current=%.2f next=%s maximum=%s Palbox=%s..%s',
                level,value.current,tostring(value.nextPercent),tostring(value.maximumPercent),tostring(value.palboxStart),tostring(value.palboxMaximum)))
        end
        return value.nextPercent,value
    end
    function P.refresh()
        records={}
        local boxes=E.objects.all('BP_BuildObject_PalBoxV2_C')
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
                                records[id]={component=component,path=component:GetFullName()}
                            end
                        end
                    end
                end
            end
        end
        for _,state in pairs(marker) do state.live=false end
    end
    function P.publish(palbox,model,nextPercent,maximumPercent)
        if not authority(model) then return end
        local id=guid(model:GetId())
        local baseline=E.runtime.baseline(model)
        local bonuses=E.runtime.bonuses(model)
        local location={X=model:GetRange()/baseline*10000,
            Y=nextPercent and nextPercent*100 or -100,
            Z=MAGIC+model:GetLevel()+(MAX_LEVEL+1)*(bonuses.chestCap*2+(bonuses.rangeEnabled and 1 or 0))}
        if bonuses.palboxCap~=nil then
            location.Z=PALBOX_MAGIC+model:GetLevel()+(MAX_LEVEL+1)*
                (bonuses.palboxCap*FLAGS_RADIX+bonuses.chestCap*2+(bonuses.rangeEnabled and 1 or 0))
        end
        local previous=marker[id] or records[id]
        local previousComponent=previous and previous.component
        local prior=E.valid(previousComponent) and decode(previousComponent.RelativeLocation)
        local priorScale=E.valid(previousComponent) and previousComponent.RelativeScale3D
        local totalPolicy=bonuses.totalPolicy or bonuses.palboxStart~=nil
        local packedTotal=0
        if totalPolicy and bonuses.palboxStart~=nil then
            local start,maximum=bonuses.palboxStart,bonuses.palboxMaximum
            assert(finite(start) and finite(maximum) and start%1==0 and maximum%1==0
                and start>=1 and start<=maximum and maximum<=E.range.limits.maxPalboxBoxes,'Invalid Palbox totals')
            packedTotal=start+TOTAL_RADIX*maximum
        end
        if totalPolicy then
            local revision=prior and prior.totalRevision or 0
            if prior and (prior.totalRevision==nil or prior.level~=model:GetLevel()
                    or math.abs(prior.current*100-location.X)>0.01
                    or math.abs((prior.nextPercent and prior.nextPercent*100 or -100)-location.Y)>0.01
                    or prior.rangeEnabled~=bonuses.rangeEnabled or prior.chestCap~=bonuses.chestCap
                    or not priorScale or priorScale.Y~=packedTotal
                    or math.abs(priorScale.X-(maximumPercent and maximumPercent*100 or 0))>0.01) then
                revision=(revision+1)%REVISIONS
            end
            location.Z=-(1+model:GetLevel()+(MAX_LEVEL+1)*
                (revision*FLAGS_RADIX+bonuses.chestCap*2+(bonuses.rangeEnabled and 1 or 0)))
        end
        assert(decode(location),'Invalid server preview')
        local scale={X=1,Y=1,Z=1}
        if maximumPercent then
            assert(finite(maximumPercent) and maximumPercent>=100 and
                maximumPercent<=100+E.range.limits.maxRangeBonusPercent+0.0001,'Invalid maximum preview')
            scale={X=maximumPercent*100,Y=location.X,Z=location.Z}
        end
        if totalPolicy then scale={X=maximumPercent and maximumPercent*100 or 0,Y=packedTotal,Z=location.Z} end
        local state=marker[id]
        local component=state and state.component
        if not E.valid(component) or component:GetFullName()~=state.path then
            -- Reuse our own native marker after a Lua reload when possible.
            local old=records[id]
            component=old and old.component
            if not E.valid(component) then
                assert(palbox.bReplicates,'Palbox actor is not replicated')
                local class=find(componentPath)
                assert(E.valid(class),'Native preview component class unavailable')
                -- Wake the existing channel before creating or modifying its
                -- replicated subobject. Do not change the Palbox's dormancy policy.
                palbox:FlushNetDormancy()
                component=palbox:AddComponentByClass(class,true,{
                    Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1},
                },false)
                assert(E.valid(component),'Native preview component creation failed')
                local ok,err=pcall(function()
                    component:SetMobility(2)
                    component:SetComponentTickEnabled(false)
                    component:SetVisibility(false,false)
                    component:SetHiddenInGame(true,false)
                    component:K2_SetRelativeLocation(location,false,{},true)
                    component:SetRelativeScale3D(scale)
                    component:SetIsReplicated(true)
                    assert(ours(component),'Preview component setup did not stick')
                end)
                if not ok then component:K2_DestroyComponent(palbox);error(err) end
                palbox:ForceNetUpdate()
                E.log('server upgrade preview component created on Palbox channel')
            end
            state={component=component,path=component:GetFullName()}
            marker[id]=state
        end
        state.live=true
        local old=component.RelativeLocation
        local oldScale=component.RelativeScale3D
        if math.abs(old.X-location.X)>0.01 or math.abs(old.Y-location.Y)>0.01 or old.Z~=location.Z
                or not oldScale or math.abs(oldScale.X-scale.X)>0.01
                or math.abs(oldScale.Y-scale.Y)>0.01 or oldScale.Z~=scale.Z then
            palbox:FlushNetDormancy()
            component:K2_SetRelativeLocation(location,false,{},true)
            component:SetRelativeScale3D(scale)
            palbox:ForceNetUpdate()
        end
    end
    function P.finish()
        for id,state in pairs(marker) do
            if not state.live then
                if E.valid(state.component) and state.component:GetFullName()==state.path then
                    local owner=state.component:GetOwner()
                    if E.valid(owner) and authority(owner) then
                        owner:FlushNetDormancy()
                        state.component:K2_DestroyComponent(owner)
                        owner:ForceNetUpdate()
                    end
                end
                marker[id]=nil
            end
        end
    end
    return P
end

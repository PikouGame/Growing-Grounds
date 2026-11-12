-- Personal, ordinary Palbox storage. Guild level supplies one bonus per player;
-- neither the number of bases nor the account-wide Global Palbox participates.
-- Only the authority edits native slots. PageNum and SlotArray replicate normally.
return function(E)
    local P={}
    local retained,failed,reported={},{},{}
    local dimensions={}
    local jobs,cursor,pending={},1,false
    local function find(path) return E.objects.find(path) end
    local function integer(n) return type(n)=='number' and n>=0 and n<math.huge and n%1==0 end
    local function identity(a,b)
        return E.valid(a) and E.valid(b) and a:GetAddress()==b:GetAddress()
    end
    -- Native load clamps storage to PalBoxPageNum. Reserve the supported
    -- ceiling before loading a player, then apply their earned personal size.
    -- Keep the original dimensions separately; never treat our ceiling as base.
    function P.prepare(context)
        if not E.valid(context) or not E.runtime.isAuthority(context) then return end
        local settings=find('/Script/Pal.Default__PalUtility'):GetGameSetting(context)
        if not E.valid(settings) then return end
        local name=settings:GetFullName()
        local record=dimensions[name]
        if not record then
            local pages,size=settings.PalBoxPageNum,settings.PalBoxSlotNumInPage
            assert(integer(pages) and pages>0 and pages<=1024 and integer(size) and size>0 and size<=100,
                'Invalid native Palbox page dimensions')
            record={pages=pages,size=size,settings=settings}
            dimensions[name]=record
        end
        local ceiling=math.max(record.pages+64,E.range.limits.maxPalboxBoxes)
        if settings.PalBoxPageNum==record.pages then
            settings.PalBoxPageNum=ceiling
            E.log(string.format('Palbox load capacity reserved: %d pages (%d native)',ceiling,record.pages))
        end
        assert(settings.PalBoxPageNum==ceiling and settings.PalBoxSlotNumInPage==record.size,
            'Another mod changed Palbox dimensions')
        return record
    end
    local function replication(record,player)
        local component=record.component
        if #record.slots==0 then
            if E.valid(component) then component:K2_DestroyComponent(record.controller) end
            record.component=nil;return
        end
        local controller=player and player:GetOwner() or record.controller
        if not E.valid(controller) then return end
        assert(controller:IsA('/Script/Engine.PlayerController'),'Palbox replication requires its owning player controller')
        if not E.valid(component) or not identity(controller,record.controller) then
            if E.valid(component) then component:K2_DestroyComponent(record.controller) end
            local class=find('/Script/Pal.PalObjectReplicatorComponent')
            assert(E.valid(class),'Palbox object replicator unavailable')
            component=controller:AddComponentByClass(class,true,{
                Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1},
            },false)
            assert(E.valid(component),'Cannot create Palbox object replicator')
            record.component,record.controller=component,controller
            component:SetComponentTickEnabled(false)
        end
        local objects={}
        for _,entry in ipairs(record.slots) do objects[#objects+1]=entry.object end
        component.ReplicateObject=objects
        component:SetIsReplicated(true)
        controller:ForceNetUpdate()
    end
    local function release(record,from)
        local remove,keep={},{}
        for _,entry in ipairs(record.slots) do
            if not from or entry.index>=from then remove[entry.object:GetAddress()]=true
            else keep[#keep+1]=entry end
        end
        if next(remove) and E.valid(record.owner) then
            local refs,survivors=record.owner.ReferencedObjects,{}
            for i=1,#refs do
                local ref=refs[i]
                local address=ref:GetAddress()
                if remove[address] then remove[address]=nil else survivors[#survivors+1]=ref end
            end
            record.owner.ReferencedObjects=survivors
        end
        record.slots=keep
        replication(record)
    end
    local function prune()
        for name,record in pairs(retained) do
            local live=E.valid(record.owner) and E.valid(record.manager) and E.valid(record.container)
                and record.owner:GetWorld():GetAddress()==record.world
            if live then live=identity(record.manager:GetContainer(record.id),record.container) end
            if not live then release(record);retained[name]=nil
            elseif record.count~=record.container:Num() then
                record.count=record.container:Num();release(record,record.count)
            end
        end
    end
    local function lifetime(container)
        local name=container:GetFullName()
        if retained[name] then return retained[name] end
        local owner=find('/Script/Engine.Default__GameplayStatics'):GetGameInstance(container)
        local manager,id=container:GetOuter(),container:GetId()
        assert(E.valid(owner) and E.valid(manager) and identity(manager:GetContainer(id),container),
            'Palbox container has no registered lifetime owner')
        local record={owner=owner,manager=manager,id=id,container=container,
            world=owner:GetWorld():GetAddress(),count=container:Num(),slots={}}
        retained[name]=record
        return record
    end
    local function context(player)
        if not E.valid(player) or player:HasAnyFlags(0x30) or not E.runtime.isAuthority(player) then return end
        local guild=player.GuildBelongTo
        if not E.valid(guild) then return end -- join/travel may not have delivered guild data yet
        local level=guild:GetBaseCampLevel()
        if not integer(level) or level<1 then return end
        local storage=player:GetPalStorage()
        if not E.valid(storage) or not E.valid(storage.TargetContainer) then return end
        local container=storage.TargetContainer
        local original=P.prepare(player)
        if not original then return end
        local native,size=original.pages,original.size
        assert(storage.SlotNumInPage==size,'Another mod changed the Palbox page size')
        local before=container:Num()
        if before==0 then return end
        assert(integer(before) and before%size==0,'Palbox slots do not form complete pages')
        local policy=E.runtime.policy(player)
        local levels=E.runtime.levels()
        local total=E.config.resetToVanilla and native or E.range.palboxTotal(level,policy,levels)
        return {player=player,storage=storage,container=container,native=native,size=size,
            before=before,desired=total*size,level=level,
            name=container:GetFullName(),signature=table.concat({level,policy.startingPalboxBoxes,policy.maxPalboxBoxes,tostring(levels),tostring(E.config.resetToVanilla)},':')}
    end
    local function announce(job,target)
        local storage,container=job.storage,job.container
        storage.PageNum=target/job.size
        assert(storage:GetPageNum()==target/job.size,'Palbox page count update failed')
        container.OnUpdateSlotsDelegate:Broadcast(container)
        if E.valid(storage.SlotObserver) then storage.SlotObserver:OnUpdateContainerSize(container) end
        container.OnUpdateContentsDelegate:Broadcast(container)
        storage:OnUpdateCharacterContainer_InServer()
        job.player:ForceNetUpdate()
    end
    local function apply(job)
        local container,storage=job.container,job.storage
        local before,desired,size=job.before,job.desired,job.size
        -- Do not cut down an expansion beyond anything GG could have added.
        if before>math.max(job.native+64,E.range.limits.maxPalboxBoxes)*size then
            if reported[job.name]~='external' then E.log('Palbox: larger external expansion left unchanged') end
            reported[job.name]='external';return
        end
        if before==desired and storage:GetPageNum()==before/size then reported[job.name]=nil;return end
        local slots=container.SlotArray
        assert(#slots==before,'Palbox container and slot array disagree')
        local target=desired
        if before>desired then
            local last=-1
            -- Inspect before mutation. Never move, copy or delete a Pal; trim
            -- empty trailing pages only. Locked slots also retain their page.
            for index=0,before-1 do
                local slot=container:Get(index)
                assert(E.valid(slot) and slot:GetSlotIndex()==index,'Invalid Palbox slot ordering')
                if not slot:IsEmpty() or slot:IsLocked() then last=index end
            end
            target=math.max(desired,math.ceil((last+1)/size)*size)
            -- Keep a page currently being synchronized to this player. The
            -- following reconciliation can trim it once they switch away.
            local viewing=storage.SyncPageIndex
            if integer(viewing) and viewing<before/size then target=math.max(target,(viewing+1)*size) end
            if target>desired and reported[job.name]~=target then
                E.log(string.format('Palbox keeps %d pages instead of %d until extra pages are empty and closed',target/size,desired/size))
            end
            reported[job.name]=target>desired and target or nil
        end
        if target==before then
            if storage:GetPageNum()~=before/size then announce(job,before) end
            return
        end
        if target>before then
            -- One page per game-thread yield also bounds the cost of applying
            -- a bonus to an existing high-level character for the first time.
            target=before+size
            local class=find('/Script/Pal.PalIndividualCharacterSlot')
            assert(E.valid(class),'Native Palbox slot class unavailable')
            local previous=container:Get(before-1)
            assert(E.valid(previous) and previous:GetSlotIndex()==before-1,'Invalid last Palbox slot')
            local record=lifetime(container)
            local original,extended={},{}
            for index=0,before-1 do
                local slot=container:Get(index)
                assert(E.valid(slot) and slot:GetSlotIndex()==index,'Invalid Palbox slot ordering')
                original[index+1],extended[index+1]=slot,slot
            end
            -- Construct and initialize all new slots before publishing any.
            local ok,err=pcall(function()
                for index=before,target-1 do
                    local slot=StaticConstructObject(class,container,FName('GG_PalboxSlot_'..index))
                    assert(E.valid(slot),'Cannot construct native Palbox slot')
                    slot:Setup(index,container:GetId())
                    slot.PermissionTribeID=previous.PermissionTribeID
                    slot.bIsReplicateCharacterParameter=previous.bIsReplicateCharacterParameter
                    assert(slot:IsEmpty() and slot:GetSlotIndex()==index,'Palbox slot initialization failed')
                    local refs=record.owner.ReferencedObjects;refs[#refs+1]=slot
                    record.slots[#record.slots+1]={object=slot,index=index}
                    extended[index+1]=slot
                end
                -- Publish a complete page. A per-slot append that fails halfway
                -- would leave a partial page invisible to the native UI.
                container.SlotArray=extended
                assert(container:Num()==target,'Palbox page assignment failed')
            end)
            if not ok then
                if container:Num()~=before then container.SlotArray=original end
                assert(container:Num()==before,'Palbox page rollback failed: '..tostring(err))
                release(record,before);error(err)
            end
            record.count=target
            -- SlotArray alone replicates unresolved references for runtime
            -- additions. Native proof requires this owner-only subobject channel.
            replication(record,job.player)
        else
            local kept={}
            for index=0,target-1 do kept[index+1]=container:Get(index) end
            container.SlotArray=kept
            local record=retained[job.name]
            if record then release(record,target);record.count=target end
        end
        assert(container:Num()==target,'Palbox resize did not stick')
        announce(job,target)
        E.log(string.format('Palbox level %d: %d -> %d pages (%d native)',job.level,before/size,target/size,job.native))
        return target<desired
    end
    local function pump()
        if pending or cursor>#jobs then return end
        pending=true
        ExecuteInGameThreadWithDelay(1,function()
            pending=false
            local player=jobs[cursor];cursor=cursor+1
            if E.valid(player) then
                E.guard('Palbox capacity '..player:GetFullName(),function()
                    local job=context(player)
                    if not job or failed[job.name]==job.signature then return end
                    local ok,more=pcall(apply,job)
                    if not ok then failed[job.name]=job.signature;error(more) end
                    failed[job.name]=nil
                    if more then jobs[#jobs+1]=player end
                end)
            end
            pump()
        end)
    end
    function P.refresh()
        -- Dedicated worlds have bases before players join. The join pre-hook
        -- below also primes the setting before a player initializes storage.
        for _,base in ipairs(E.objects.all('PalBaseCampModel')) do
            if E.valid(base) and E.runtime.isAuthority(base) then P.prepare(base);break end
        end
        prune()
        if pending or cursor<=#jobs then return end
        jobs={};cursor=1
        for _,player in ipairs(E.objects.all('PalPlayerState')) do jobs[#jobs+1]=player end
        pump()
    end
    E.guard('Palbox load hook',function()
        RegisterHook('/Script/Pal.PalPlayerState:RequestJoinPlayer_ToServer',function(context)
            E.guard('Palbox load capacity',function() P.prepare(context:get()) end)
        end)
    end)
    return P
end

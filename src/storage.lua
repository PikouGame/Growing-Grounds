-- Server-owned chest capacity. Baselines come from native chest parameters,
-- never from a previously expanded container. Guild storage is handled once.
return function(E)
    local S={dirty=true}
    local signature,jobs,cursor,pending=nil,{},1,false
    local overflow,failed,retained={},{},{}
    local function object(path)return E.objects.find(path)end
    local function guid(id)return table.concat({id.A,id.B,id.C,id.D},':')end
    local function integer(n)return type(n)=='number' and n>=0 and n<math.huge and n%1==0 end
    local function current(job)
        return E.valid(job.container) and job.container:GetFullName()==job.name
            and E.valid(job.base) and job.base:IsAvailable() and not job.base.bTemporary
            and E.runtime.isAuthority(job.base)
    end
    local function release(record,count)
        local remove,remaining={},{}
        for _,entry in ipairs(record.slots) do
            if count and entry.index<count then remaining[#remaining+1]=entry
            else remove[entry.object:GetAddress()]=true end
        end
        if next(remove) and E.valid(record.owner) then
            local refs,keep=record.owner.ReferencedObjects,{}
            for i=1,#refs do
                local item=refs[i]
                local address=item:GetAddress()
                -- Remove only our reference, preserving other registrations.
                if remove[address] then remove[address]=nil else keep[#keep+1]=item end
            end
            record.owner.ReferencedObjects=keep
        end
        record.slots=remaining
        if #remaining==0 then retained[record.name]=nil end
    end
    local function prune()
        for _,record in pairs(retained) do
            local live=E.valid(record.owner) and E.valid(record.manager)
                and E.valid(record.container)
                and record.owner:GetWorld():GetAddress()==record.world
            if live then
                local registered=record.manager:GetContainer(record.id)
                live=E.valid(registered) and registered:GetAddress()==record.container:GetAddress()
            end
            if not live then release(record)
            elseif record.container:Num()~=record.count then
                record.count=record.container:Num();release(record,record.count)
            end
        end
    end
    local function lifetime(job)
        if retained[job.name] then return retained[job.name] end
        local container=job.container
        local owner=object('/Script/Engine.Default__GameplayStatics'):GetGameInstance(container)
        local manager,id=container:GetOuter(),container:GetId()
        assert(E.valid(owner) and E.valid(manager),'Native inventory lifetime owner unavailable')
        assert(manager:GetContainer(id):GetAddress()==container:GetAddress(),'Inventory is not registered')
        local record={name=job.name,owner=owner,manager=manager,id=id,container=container,
            world=owner:GetWorld():GetAddress(),count=container:Num(),slots={}}
        retained[job.name]=record
        return record
    end
    local function capacity(model)
        local actor=model:GetActor()
        if not E.valid(actor) then return end
        local class=object('/Script/Pal.PalMapObjectItemChestParameterComponent')
        if not E.valid(class) then return end
        for _,entry in ipairs(actor:K2_GetComponentsByClass(class)) do
            local n=entry:get().SlotNum
            if integer(n) and n>0 then return n,actor end
        end
    end
    local function resize(job)
        if not current(job) then return end
        local container=job.container
        local before=container:Num()
        assert(integer(before) and before>0,'Invalid native chest capacity')
        -- Do not cut back an unrelated storage expansion that exceeds our
        -- entire supported bonus. Its own mod remains responsible for it.
        if before>job.baseline+40 then return end
        local policy=E.runtime.policy(job.base)
        local bonus=E.config.resetToVanilla and 0 or E.range.storageBonus(job.base:GetLevel(),policy)
        local desired=job.baseline+bonus
        if before==desired then overflow[job.name]=nil;return end
        local target=desired
        if before>desired then
            local last=container:GetLastNotEmptyIndex()
            assert(type(last)=='number' and last>=-1 and last<before and last%1==0,'Invalid occupied slot index')
            target=math.max(desired,last+1)
        end
        overflow[job.name]=target>desired and job or nil
        if target==before then return end
        local slots=container.ItemSlotArray
        assert(#slots==before,'Native container/slot counts disagree')
        if target>before then
            local class=object('/Script/Pal.PalItemSlot')
            assert(E.valid(class),'Native item-slot class unavailable')
            local id,permission=container:GetId(),container:GetPermission()
            local record=lifetime(job)
            for index=before,target-1 do
                local slot=StaticConstructObject(class,container,FName('None'))
                assert(E.valid(slot),'Cannot construct a native chest slot')
                slot.SlotIndex=index
                slot.ContainerId=id
                slot.Permission=permission
                assert(slot:IsEmpty(),'New native chest slot must be empty')
                slot.OnUpdateSlotContentDelegate:Add(container,FName('OnUpdateSlotContent'))
                -- Native tests show ItemSlotArray alone does not retain slots
                -- appended at runtime. Use the game's reference list, and
                -- release our entries on shrink, inventory removal or travel.
                local refs=record.owner.ReferencedObjects
                refs[#refs+1]=slot
                record.slots[#record.slots+1]={object=slot,index=index}
                record.count=-1 -- also prune a failed append on the next refresh
                slots[index+1]=slot
                assert(container:Num()==index+1,'Native slot append failed')
                record.count=index+1
            end
        else
            local kept={}
            for index=0,before-1 do
                local slot=container:Get(index)
                assert(E.valid(slot) and slot.SlotIndex==index,'Invalid native slot ordering')
                if index<target then kept[#kept+1]=slot
                else assert(slot:IsEmpty(),'Refusing to remove an occupied slot') end
            end
            -- Existing slot objects, item IDs, counts and dynamic data survive.
            container.ItemSlotArray=kept
            assert(container:Num()==target,'Native slot reduction failed')
            local record=retained[job.name]
            if record then record.count=target;release(record,target) end
        end
        container.OnUpdateContentsDelegate:Broadcast(container)
        if E.valid(job.actor) then job.actor:FlushNetDormancy();job.actor:ForceNetUpdate() end
        E.log(string.format('chest capacity %d -> %d (native %d, bonus cap %d)',
            before,target,job.baseline,policy.maxChestBonusSlots))
    end
    local function pump()
        if pending or cursor>#jobs then return end
        pending=true
        ExecuteWithDelay(1,function() ExecuteInGameThread(function()
            pending=false
            local job=jobs[cursor];cursor=cursor+1
            if job and not failed[job.name] then
                local ok=E.guard('chest capacity '..job.name,function()resize(job)end)
                if not ok then failed[job.name]=true;overflow[job.name]=nil end
            end
            -- At most one container per yield. No scans or terrain work here.
            pump()
        end) end)
    end
    function S.changed()S.dirty=true end
    function S.refresh()
        prune()
        local bases,parts={},{}
        for _,base in ipairs(E.objects.all('PalBaseCampModel')) do
            if E.valid(base) and base:IsAvailable() and not base.bTemporary and E.runtime.isAuthority(base) then
                local id=guid(base:GetGroupIdBelongTo())
                bases[id]=base
                parts[#parts+1]=id..':'..base:GetLevel()
            end
        end
        if next(bases)==nil then jobs={};cursor=1;signature=nil;return end
        table.sort(parts)
        parts[#parts+1]=tostring(E.range.settings(E.policy and E.policy() or E.config).maxChestBonusSlots)
        parts[#parts+1]=tostring(E.config.resetToVanilla)
        local now=table.concat(parts,';')
        if not S.dirty and signature==now then
            if cursor>#jobs then
                jobs={};cursor=1
                for name,job in pairs(overflow) do
                    if current(job) then jobs[#jobs+1]=job else overflow[name]=nil end
                end
                pump()
            end
            return
        end
        S.dirty=false;signature=now;jobs={};cursor=1
        local seen={}
        local function enqueue(container,baseline,base,actor)
            if not E.valid(container) or not integer(baseline) or baseline<1 then return end
            local name=container:GetFullName()
            if seen[name] then return end
            seen[name]=true
            jobs[#jobs+1]={container=container,name=name,baseline=baseline,base=base,actor=actor}
        end
        for _,model in ipairs(E.objects.all('PalMapObjectItemChestModel')) do
            local base=model:GetBaseCampModelBelongTo()
            if E.valid(base) and base:IsAvailable() and not base.bTemporary and E.runtime.isAuthority(base) then
                local module=model:GetItemContainerModule()
                if E.valid(module) then
                    local baseline,actor=capacity(model)
                    enqueue(module:GetContainer(),baseline,base,actor)
                end
            end
        end
        local utility=object('/Script/Pal.Default__PalUtility')
        for _,group in ipairs(E.objects.all('PalGroupGuild')) do
            local base=bases[guid(group:GetId())]
            local storage=group.ItemStorage
            if base and E.valid(storage) then
                local settings=utility:GetGameSetting(base)
                enqueue(storage.ItemContainer,settings.GuildChestSlotNum,base)
            end
        end
        pump()
    end
    -- Models may exist before their actor parameters/shared inventory do.
    -- Construction notifications retry those arrivals without periodic scans.
    for _,name in ipairs({'PalMapObjectItemChestParameterComponent','PalGuildItemStorage'}) do
        E.guard('storage notification '..name,function()
            NotifyOnNewObject('/Script/Pal.'..name,S.changed)
        end)
    end
    return S
end

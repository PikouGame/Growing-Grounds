-- Exercise the inventory adapter and lifecycle without touching a game save.
local root=assert(arg[1])
local Range=dofile(root..'src/range.lua')
local tasks,notifications,errors={}, {}, {}
local allocations,scans=0,{}
local tableLevels=35
local address=0
local function obj(name,t)
    t=t or {};t.alive=true
    address=address+1;t.address=address
    function t:IsValid()return self.alive end
    function t:GetFullName()return name end
    function t:GetAddress()return self.address end
    return t
end
local world,foreign=obj('world'),obj('unrelated reference')
local owner=obj('game instance',{ReferencedObjects={foreign}})
function owner:GetWorld()return world end
local registry={}
local manager=obj('container manager')
function manager:GetContainer(id)return registry[id] end
local function slot(index,container,amount)
    local s=obj('slot'..index,{SlotIndex=index,ContainerId=container.id,amount=amount or 0,
        item={id='original item',dynamic={durability=82}},OnUpdateSlotContentDelegate={}})
    function s:IsEmpty()return self.amount==0 end
    function s.OnUpdateSlotContentDelegate:Add(target,name)
        assert(target==container and name=='OnUpdateSlotContent')
        s.bound=true
    end
    return s
end
local function container(name,count)
    local c=obj(name,{_slots={},id={ID={A=12,B=34,C=56,D=78}},broadcasts=0,
        permission={PermissionTypeA={1},PermissionTypeB={2},PermissionItemStaticIds={'Allowed'}}})
    setmetatable(c,{__index=function(self,k)if k=='ItemSlotArray' then return self._slots end end,
        __newindex=function(self,k,v)if k=='ItemSlotArray' then self._slots=v else rawset(self,k,v) end end})
    for i=0,count-1 do c._slots[i+1]=slot(i,c,i==0 and 3 or 0) end
    function c:Num()return #self._slots end
    function c:Get(i)return self._slots[i+1] end
    function c:GetId()return self.id end
    function c:GetOuter()return manager end
    registry[c.id]=c
    function c:GetPermission()return self.permission end
    function c:GetLastNotEmptyIndex()
        for i=#self._slots,1,-1 do if not self._slots[i]:IsEmpty() then return i-1 end end
        return -1
    end
    c.OnUpdateContentsDelegate={Broadcast=function(_,target)
        assert(target==c);c.broadcasts=c.broadcasts+1
    end}
    return c
end
local base=obj('base',{level=10,authority=true,available=true})
function base:IsAvailable()return self.available end
function base:GetLevel()return self.level end
function base:GetGroupIdBelongTo()return {A=1,B=0,C=0,D=0} end
local function chest(name,c,n)
    local actor=obj(name..'actor',{wakes=0,updates=0})
    function actor:K2_GetComponentsByClass()return {{get=function()return {SlotNum=n}end}}end
    function actor:FlushNetDormancy()self.wakes=self.wakes+1 end
    function actor:ForceNetUpdate()self.updates=self.updates+1 end
    return obj(name,{GetActor=function()return actor end,
        TryGetMapObjectId=function()return {ToString=function()return name end}end,
        GetBaseCampModelBelongTo=function()return base end,
        GetItemContainerModule=function()return obj('module',{GetContainer=function()return c end})end}),actor
end
local wood,metal,guild=container('wood',10),container('metal',24),container('guild',80)
local w,wa=chest('wood model',wood,10)
local m=chest('metal model',metal,24)
local group=obj('guild model',{GetId=function()return base:GetGroupIdBelongTo()end,
    ItemStorage=obj('guild storage',{ItemContainer=guild})})
local lists={PalBaseCampModel={base},PalMapObjectItemChestModel={w,m},PalGroupGuild={group,group}}
local E={range=Range,config={maxChestBonusSlots=20,resetToVanilla=false}}
E.valid=function(o)return o and o:IsValid()end
E.guard=function(_,fn)local ok,err=pcall(fn);if not ok then errors[#errors+1]=err end;return ok end
E.log=function()end
E.runtime={isAuthority=function(b)return b.authority end,policy=function()return Range.settings(E.config)end,
    maxLevel=function()return assert(tableLevels,'Base-level table not loaded')end}
E.objects={all=function(name)scans[name]=(scans[name] or 0)+1;return lists[name]end,
    find=function(path)
        if path:find('GameplayStatics',1,true) then return {GetGameInstance=function()return owner end} end
        if path:find('PalUtility',1,true) then return {GetGameSetting=function()return {GuildChestSlotNum=80}end} end
        return obj(path)
    end}
ExecuteInGameThreadWithDelay=function(delay,fn)assert(delay==1);tasks[#tasks+1]=fn end
ExecuteWithDelay=function()error('Chest work must never schedule asynchronous Lua')end
NotifyOnNewObject=function(path,fn)notifications[path]=fn end
FName=function(v)return v end
StaticConstructObject=function(_,outer,name)
    assert(name=='None');allocations=allocations+1
    return slot(-1,outer,0)
end
local function drain()
    local turns=0
    while #tasks>0 do
        turns=turns+1;assert(turns<1000,'queue must terminate')
        table.remove(tasks,1)()
    end
end
local S=dofile(root..'src/storage.lua')(E)
local original=wood:Get(0)
S.refresh();assert(wood:Num()==10,'writes wait for game-thread work')
drain()
assert(#errors==0,table.concat(errors,'\n'))
assert(wood:Num()==15 and metal:Num()==29 and guild:Num()==85)
assert(allocations==15 and guild.broadcasts==1,'shared guild inventory grows only once')
assert(#owner.ReferencedObjects==16 and owner.ReferencedObjects[1]==foreign,'new slots have native lifetime references')
assert(wood:Get(0)==original and original.amount==3 and original.item.dynamic.durability==82)
for i=10,14 do
    local s=wood:Get(i)
    assert(s.SlotIndex==i and s.ContainerId==wood.id and s.Permission==wood.permission and s.bound and s:IsEmpty())
end
assert(wa.wakes==1 and wa.updates==1)
for i=1,20 do S.refresh();drain() end
assert(scans.PalMapObjectItemChestModel==1 and allocations==15,'stable levels do not enumerate chests or allocate')
-- A process restart gives loaded slots native ownership and a fresh game instance.
owner.ReferencedObjects={foreign}
S=dofile(root..'src/storage.lua')(E);S.refresh();drain()
assert(wood:Num()==15 and allocations==15,'reload uses native baseline, never compounds the previous bonus')
base.level=11;S.refresh();drain()
assert(wood:Num()==16 and metal:Num()==30 and guild:Num()==86)
-- Lowering a cap retains every occupied slot and shrinks after it is emptied.
wood:Get(15).amount=4
local overflowItem=wood:Get(15)
E.config.maxChestBonusSlots=0;S.refresh();drain()
assert(wood:Num()==16 and wood:Get(15)==overflowItem and overflowItem.amount==4)
assert(metal:Num()==24 and guild:Num()==80)
wood:Get(15).amount=0;S.refresh();drain()
assert(wood:Num()==10 and wood:Get(0)==original)
E.config.maxChestBonusSlots=999;base.level=100;S.refresh();drain()
assert(wood:Num()==50 and metal:Num()==64 and guild:Num()==120,'absolute bonus limit40')
E.config.resetToVanilla=true;S.refresh();drain()
assert(wood:Num()==10 and guild:Num()==80)
assert(#owner.ReferencedObjects==1 and owner.ReferencedObjects[1]==foreign,'shrink releases only mod references')
-- Client, unavailable and temporary bases never write inventory.
E.config.resetToVanilla=false;base.authority=false
local count=allocations;S.changed();S.refresh();drain();assert(allocations==count)
base.authority=true;base.bTemporary=true;S.refresh();drain();assert(allocations==count)
base.bTemporary=false;base.available=false;S.refresh();drain();assert(allocations==count)
base.available=true;base.level=10;E.config.maxChestBonusSlots=20
local late=container('late',10);local lateModel,lateActor=chest('late model',late,10)
lateActor.alive=false;lists.PalMapObjectItemChestModel[#lists.PalMapObjectItemChestModel+1]=lateModel
S.changed();S.refresh();drain();assert(late:Num()==10)
lateActor.alive=true;notifications['/Script/Pal.PalMapObjectItemChestParameterComponent']()
S.refresh();drain();assert(late:Num()==15,'late actor parameters retry through creation notifications')
local references=#owner.ReferencedObjects
registry[late.id]=nil
S.refresh();drain()
assert(#owner.ReferencedObjects==references-5,'inventory removal releases its retained slots')
registry[late.id]=late
local external=container('other mod',100);local externalModel=chest('other model',external,10)
lists.PalMapObjectItemChestModel={externalModel}
S.changed();S.refresh();drain();assert(external:Num()==100,'do not remove an unrelated large storage expansion')
-- A constructor failure cannot alter old item objects or retry forever.
local failure=container('failed',10);local failureModel=chest('failed model',failure,10)
lists.PalMapObjectItemChestModel={failureModel}
StaticConstructObject=function()error('simulated allocation failure')end
S.changed();S.refresh();drain()
assert(failure:Num()==10 and failure:Get(0).amount==3 and #errors==1)
S.changed();S.refresh();drain();assert(#errors==1)
-- A real change (a higher base level) earns the failed chest one new attempt.
StaticConstructObject=function(_,outer)allocations=allocations+1;return slot(-1,outer,0)end
S.changed();S.refresh();drain();assert(failure:Num()==10 and #errors==1,'same signature never retries')
base.level=11;S.refresh();drain()
assert(failure:Num()==16 and #errors==1,'a changed signature retries a failed chest')
print('PASS: server-only native baselines, guild dedup, initialized empty slots, item identity, cap/reset overflow safety, bounded jobs, reload, stable no-scan and failure isolation')

-- A world saved by 0.1.6 at level 11 holds 10 extra slots per chest. The spread
-- schedule asks for 6. The surplus takes the same path as a lowered cap:
-- empty slots go, every slot that holds an item stays exactly where it is.
for i=#errors,1,-1 do errors[i]=nil end
StaticConstructObject=function(_,outer,name)
    assert(name=='None');allocations=allocations+1
    return slot(-1,outer,0)
end
base.level=11;E.config.maxChestBonusSlots=20
assert(Range.storageBonus(11,E.config,35)==6)
local function saved(name,count,occupied)
    local c=container(name,count)
    c:Get(0).amount=0
    for _,index in ipairs(occupied) do c:Get(index).amount=7 end
    return c
end
local function contents(c)
    local held={}
    for i=0,c:Num()-1 do
        local s=c:Get(i)
        if not s:IsEmpty() then held[#held+1]={index=i,slot=s,amount=s.amount,item=s.item,dynamic=s.item.dynamic} end
    end
    return held
end
local function intact(c,held,label)
    for _,h in ipairs(held) do
        local s=c:Get(h.index)
        assert(s==h.slot and s.SlotIndex==h.index and s.amount==h.amount and s.item==h.item
            and s.item.dynamic==h.dynamic,label..': an occupied slot was removed, moved or altered')
    end
end
local everySlot={};for i=0,33 do everySlot[#everySlot+1]=i end
local spare=saved('0.1.6 spare',34,{0,5,29})    -- nothing in the 10 old extra slots
local edge=saved('0.1.6 edge',34,{2,31})        -- one item in an extra slot the new schedule drops
local full=saved('0.1.6 full',34,everySlot)     -- every old extra slot in use
local sharedOld=saved('0.1.6 guild',90,{0,89})  -- Guild Chest, last old extra slot in use
local chests={spare,edge,full,sharedOld}
local before={};for i,c in ipairs(chests) do before[i]=contents(c) end
lists.PalMapObjectItemChestModel={chest('spare model',spare,24),chest('edge model',edge,24),(chest('full model',full,24))}
group.ItemStorage.ItemContainer=sharedOld
owner.ReferencedObjects={foreign}
local built=allocations
S=dofile(root..'src/storage.lua')(E);S.refresh();drain()
assert(#errors==0,table.concat(errors,'\n'))
assert(spare:Num()==30,'unused old extra slots shrink to the new schedule')
assert(edge:Num()==32,'trailing empty slots go, the occupied slot and those before it stay')
assert(full:Num()==34 and sharedOld:Num()==90,'a chest whose last old slot is in use keeps every slot')
for i,c in ipairs(chests) do intact(c,before[i],c:GetFullName()) end
assert(allocations==built and #owner.ReferencedObjects==1,'the lower schedule builds nothing and touches no foreign reference')
for _=1,5 do S.refresh();drain() end
assert(edge:Num()==32 and full:Num()==34 and sharedOld:Num()==90 and #errors==0,'occupied overflow is stable across refreshes')
for i,c in ipairs(chests) do intact(c,before[i],c:GetFullName()) end
-- Emptied slots are released on a later refresh, never an occupied one.
edge:Get(31).amount=0;full:Get(33).amount=0;full:Get(32).amount=0;sharedOld:Get(89).amount=0
S.refresh();drain()
assert(edge:Num()==30 and full:Num()==32 and sharedOld:Num()==86 and #errors==0)
for index=0,31 do assert(full:Get(index).amount==7) end
assert(edge:Get(2).amount==7 and sharedOld:Get(0).amount==7)
-- Later upgrades grow again from the new schedule: 6 at level 12, 7 at level 13.
base.level=12;S.refresh();drain();assert(spare:Num()==30 and edge:Num()==30 and full:Num()==32)
base.level=13;S.refresh();drain()
assert(spare:Num()==31 and edge:Num()==31 and full:Num()==32 and sharedOld:Num()==87 and #errors==0)
print('PASS: a 0.1.6 world under the lower schedule keeps every occupied slot, releases emptied ones and grows again')

-- The schedule spans the game's level table. An unreadable table means its
-- known 35 levels; a different table reconciles chests without a level change.
local plain=container('plain',10);plain:Get(0).amount=0
lists.PalMapObjectItemChestModel={(chest('plain model',plain,10))}
tableLevels=nil;base.level=35
S=dofile(root..'src/storage.lua')(E);S.refresh();drain()
assert(plain:Num()==30 and #errors==0,'missing level table falls back to 35 levels')
tableLevels=40;S.refresh();drain()
assert(plain:Num()==27,'level 35 of 40 gives 17 of 20 slots')
base.level=40;S.refresh();drain();assert(plain:Num()==30)
base.level=41;S.refresh();drain();assert(plain:Num()==30 and #errors==0,'a level above the table stays on the cap')
print('PASS: level-table fallback, table change reconciliation and levels above the table')

-- A reset names each chest that still holds items above its native size, once,
-- and says when every chest is back to native size: the signal to remove the mod.
for i=#errors,1,-1 do errors[i]=nil end
local logs={};E.log=function(text)logs[#logs+1]=text end
local function logged(text)
    local n=0
    for _,line in ipairs(logs) do if line:find(text,1,true) then n=n+1 end end
    return n
end
local function census(list)
    local held={}
    for _,c in ipairs(list) do
        for i=0,c:Num()-1 do
            local s=c:Get(i)
            assert(s.SlotIndex==i,'a slot sits at another index than its own')
            if not s:IsEmpty() then assert(not held[s],'a slot appears twice');held[s]=s.amount end
        end
    end
    return held
end
local function same(a,b,label)
    for s,n in pairs(a) do assert(b[s]==n,label..': an item was lost or changed') end
    for s in pairs(b) do assert(a[s],label..': an item appeared') end
end
local function filled(name,count,native,extra)   -- every native slot in use, plus the listed ones
    local c=saved(name,count,extra)
    for index=0,native-1 do c:Get(index).amount=7 end
    return c
end
tableLevels=35;base.level=11;E.config.maxChestBonusSlots=20;E.config.resetToVanilla=false
local busy,tidy=filled('busy',16,10,{12}),saved('tidy',16,{1})
local unnamed,sharedBusy=filled('unnamed',16,10,{11}),filled('guild busy',86,80,{82})
local unnamedModel=chest('unnamed model',unnamed,10)
unnamedModel.TryGetMapObjectId=nil
lists.PalMapObjectItemChestModel={chest('busy model',busy,10),chest('tidy model',tidy,10),unnamedModel}
group.ItemStorage.ItemContainer=sharedBusy
local reset={busy,tidy,unnamed,sharedBusy}
local start=census(reset)
-- A lowered cap reports the slots it keeps, and no reset line.
E.config.maxChestBonusSlots=0
S=dofile(root..'src/storage.lua')(E);S.refresh();drain();S.refresh();drain()
assert(#errors==0,table.concat(errors,'\n'))
assert(logged('busy model keeps 13 slots instead of 10 until the slots above are emptied')==1 and logged('reset ')==0)
E.config.resetToVanilla=true;S.refresh();drain();S.refresh();drain()
assert(#errors==0,table.concat(errors,'\n'))
assert(busy:Num()==13 and tidy:Num()==10 and unnamed:Num()==12 and sharedBusy:Num()==83)
same(start,census(reset),'reset with occupied slots above native size')
assert(logged('busy model keeps 13 slots')==1,'an unchanged chest is not reported again')
assert(logged('Guild Chest keeps 83 slots instead of 80')==1,'the shared chest is named')
assert(logged('chest keeps 12 slots instead of 10')==1,'a chest whose name cannot be read is still reported')
assert(logged('reset waiting: 3 chests still hold items above native size, 0 failed')==1 and logged('reset complete')==0)
local lines=#logs
for _=1,5 do S.refresh();drain() end
assert(#logs==lines,'a waiting reset says so once')
-- Emptying those slots lets each chest shrink; the reset completes with the last one.
busy:Get(12).amount=0;unnamed:Get(11).amount=0;sharedBusy:Get(82).amount=0
S.refresh();drain();S.refresh();drain()
assert(busy:Num()==10 and unnamed:Num()==10 and sharedBusy:Num()==80 and #errors==0)
assert(logged('reset complete: 4 chests at native size')==1)
-- A chest that appears later is counted: the last reset line is the one to trust.
lists.PalMapObjectItemChestModel[4]=chest('newcomer model',saved('newcomer',10,{2}),10)
S.changed();S.refresh();drain();S.refresh();drain()
assert(logged('reset complete: 5 chests at native size')==1 and #errors==0)
-- A chest whose resize fails holds the reset open.
local broken=filled('broken',12,10,{})
function broken:GetLastNotEmptyIndex()error('simulated native failure')end
lists.PalMapObjectItemChestModel={(chest('broken model',broken,10))}
local brokenStart=census({broken})
S.changed();S.refresh();drain();S.refresh();drain()
assert(broken:Num()==12 and #errors==1)
same(brokenStart,census({broken}),'failed resize')
assert(logged('reset waiting: 0 chests still hold items above native size, 1 failed')==1)
assert(logged('reset complete')==2,'a failed chest never reports a complete reset')
print('PASS: a reset names each chest holding items above native size once, waits for them and completes only when all are native')

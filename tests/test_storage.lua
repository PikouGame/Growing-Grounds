-- Exercise the inventory adapter and lifecycle without touching a game save.
local root=assert(arg[1])
local Range=dofile(root..'src/range.lua')
local tasks,notifications,errors={}, {}, {}
local allocations,scans=0,{}
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
E.runtime={isAuthority=function(b)return b.authority end,policy=function()return Range.settings(E.config)end}
E.objects={all=function(name)scans[name]=(scans[name] or 0)+1;return lists[name]end,
    find=function(path)
        if path:find('GameplayStatics',1,true) then return {GetGameInstance=function()return owner end} end
        if path:find('PalUtility',1,true) then return {GetGameSetting=function()return {GuildChestSlotNum=80}end} end
        return obj(path)
    end}
ExecuteWithDelay=function(_,fn)tasks[#tasks+1]=fn end
ExecuteInGameThread=function(fn)fn()end
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
assert(wood:Num()==19 and metal:Num()==33 and guild:Num()==89)
assert(allocations==27 and guild.broadcasts==1,'shared guild inventory grows only once')
assert(#owner.ReferencedObjects==28 and owner.ReferencedObjects[1]==foreign,'new slots have native lifetime references')
assert(wood:Get(0)==original and original.amount==3 and original.item.dynamic.durability==82)
for i=10,18 do
    local s=wood:Get(i)
    assert(s.SlotIndex==i and s.ContainerId==wood.id and s.Permission==wood.permission and s.bound and s:IsEmpty())
end
assert(wa.wakes==1 and wa.updates==1)
for i=1,20 do S.refresh();drain() end
assert(scans.PalMapObjectItemChestModel==1 and allocations==27,'stable levels do not enumerate chests or allocate')
-- A process restart gives loaded slots native ownership and a fresh game instance.
owner.ReferencedObjects={foreign}
S=dofile(root..'src/storage.lua')(E);S.refresh();drain()
assert(wood:Num()==19 and allocations==27,'reload uses native baseline, never compounds the previous bonus')
base.level=11;S.refresh();drain()
assert(wood:Num()==20 and metal:Num()==34 and guild:Num()==90)
-- Lowering a cap retains every occupied slot and shrinks after it is emptied.
wood:Get(19).amount=4
local overflowItem=wood:Get(19)
E.config.maxChestBonusSlots=0;S.refresh();drain()
assert(wood:Num()==20 and wood:Get(19)==overflowItem and overflowItem.amount==4)
assert(metal:Num()==24 and guild:Num()==80)
wood:Get(19).amount=0;S.refresh();drain()
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
S.refresh();drain();assert(late:Num()==19,'late actor parameters retry through creation notifications')
local references=#owner.ReferencedObjects
registry[late.id]=nil
S.refresh();drain()
assert(#owner.ReferencedObjects==references-9,'inventory removal releases its retained slots')
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
print('PASS: server-only native baselines, guild dedup, initialized empty slots, item identity, cap/reset overflow safety, bounded jobs, reload, stable no-scan and failure isolation')

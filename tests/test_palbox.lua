local root=assert(arg[1],'pass mod root with trailing slash')
local Range=dofile(root..'src/range.lua')
local make=dofile(root..'src/palbox.lua')
local serial,created,timers,errors,logs=0,0,{},{},{}
local function obj(name,t)
    serial=serial+1;t=t or {};t.address=serial;t.alive=true;t.name=name..serial
    function t:IsValid() return self.alive end
    function t:GetAddress() return self.address end
    function t:GetFullName() return self.name end
    function t:HasAnyFlags() return self.default or false end
    return t
end
local function valid(o) return o and o:IsValid() end
local world=obj('world')
local owner=obj('instance',{ReferencedObjects={}})
function owner:GetWorld() return world end
local containers={}
local manager=obj('manager')
function manager:GetContainer(id) return containers[id] end
local slotClass=obj('class')
local function slot(index,container)
    local s=obj('slot',{index=index,empty=true,locked=false,PermissionTribeID=7,bIsReplicateCharacterParameter=false})
    function s:GetSlotIndex() return self.index end
    function s:IsEmpty() return self.empty end
    function s:IsLocked() return self.locked end
    function s:Setup(i,id) self.index=i;self.id=id end
    return s
end
local failSetup=false
StaticConstructObject=function(class,container)
    assert(class==slotClass);created=created+1
    local s=slot(-1,container)
    if failSetup then s.Setup=function() error('native setup failed') end end
    return s
end
FName=function(s) return s end
ExecuteInGameThreadWithDelay=function(ms,f) assert(ms==1);timers[#timers+1]=f end
local native=obj('settings',{PalBoxPageNum=32,PalBoxSlotNumInPage=30})
local util={GetGameSetting=function() return native end}
local gameplay={GetGameInstance=function() return owner end}
local players={}
local E={range=Range,config={},valid=valid,
    log=function(s) logs[#logs+1]=s end,
    guard=function(_,fn) local ok,err=pcall(fn);if not ok then errors[#errors+1]=err end;return ok,err end,
    runtime={isAuthority=function(p) return p.server end,policy=function(p) return Range.settings(p.policy) end},
    objects={find=function(p)
        if p=='/Script/Pal.PalIndividualCharacterSlot' then return slotClass end
        if p=='/Script/Engine.Default__GameplayStatics' then return gameplay end
        assert(p=='/Script/Pal.Default__PalUtility');return util
    end,all=function(name) assert(name=='PalPlayerState');return players end}}
local function newPlayer(level,server)
    local guild=obj('guild',{level=level})
    function guild:GetBaseCampLevel() return self.level end
    local c=obj('container',{SlotArray={},updates=0,changes=0})
    function c:GetId() return self.address end
    function c:GetOuter() return manager end
    function c:Num() return #self.SlotArray end
    function c:Get(i) return self.SlotArray[i+1] end
    c.OnUpdateContentsDelegate={Broadcast=function(_,given) assert(given==c);c.updates=c.updates+1 end}
    c.OnUpdateSlotsDelegate={Broadcast=function(_,given) assert(given==c);c.changes=c.changes+1 end}
    containers[c:GetId()]=c
    for i=0,959 do c.SlotArray[i+1]=slot(i,c) end
    local s=obj('storage',{PageNum=32,SlotNumInPage=30,SyncPageIndex=-1,TargetContainer=c})
    function s:GetPageNum() return self.PageNum end
    function s:OnUpdateCharacterContainer_InServer() self.cacheUpdated=(self.cacheUpdated or 0)+1 end
    s.SlotObserver=obj('observer',{OnUpdateContainerSize=function(_,given) assert(given==c) end})
    local p=obj('player',{GuildBelongTo=guild,server=server,policy={},updates=0})
    function p:GetPalStorage() return s end
    function p:ForceNetUpdate() self.updates=self.updates+1 end
    players[#players+1]=p
    return p,s,c,guild
end
local function drain()
    local n=0
    while #timers>0 do n=n+1;assert(n<10000);table.remove(timers,1)() end
end
local P=make(E)
local p,s,c,g=newPlayer(1,true)
local client,cs,cc=newPlayer(35,false)
P.refresh();drain();assert(c:Num()==960 and created==0 and #errors==0)
g.level=2;P.refresh();assert(#timers==1 and c:Num()==960);drain()
assert(c:Num()==990 and s.PageNum==33 and created==30)
for i=960,989 do assert(c:Get(i):GetSlotIndex()==i and c:Get(i).id==c:GetId() and c:Get(i):IsEmpty()) end
assert(#owner.ReferencedObjects==30 and c.updates==1 and s.cacheUpdated==1 and p.updates==1)
assert(cc:Num()==960 and cs.PageNum==32,'clients cannot grant pages')
for _=1,3 do P.refresh();drain() end
assert(created==30 and c.updates==1,'steady state allocates/writes nothing')
-- A Pal in the original area survives every resize as the exact same slot.
local occupied=c:Get(5);occupied.empty=false;occupied.pal='original-pal'
g.level=33;P.refresh();drain()
assert(c:Num()==1920 and s.PageNum==64 and c:Get(5)==occupied)
for _,level in ipairs({34,35}) do g.level=level;local count=created;P.refresh();drain();assert(c:Num()==1920 and created==count) end
-- One page per yield; a new cap does not spread extra pages across 35 levels.
p.policy.maxPalboxBonusPages=64;P.refresh()
table.remove(timers,1)();assert(c:Num()==1950 and #timers==1)
drain();assert(c:Num()==1980 and s.PageNum==66,'at level35 cap64 grants +34, not +64')
-- Lowering/off never deletes occupied or locked slots, and shrinks whole pages.
local extra=c:Get(1979);extra.empty=false;extra.pal='extra-pal'
p.policy.maxPalboxBonusPages=0;P.refresh();drain()
assert(c:Num()==1980 and c:Get(1979)==extra and extra.pal=='extra-pal')
extra.empty=true;extra.locked=true;P.refresh();drain();assert(c:Num()==1980)
extra.locked=false;s.SyncPageIndex=65;P.refresh();drain();assert(c:Num()==1980,'keep an actively synchronized page')
s.SyncPageIndex=0;P.refresh();drain()
assert(c:Num()==960 and s.PageNum==32 and c:Get(5)==occupied and occupied.pal=='original-pal')
assert(#owner.ReferencedObjects==0,'release only our obsolete references')
-- Different guilds grant different personal bonuses; no base-count multiplier.
local p2,s2,c2=newPlayer(3,true)
p.policy.maxPalboxBonusPages=2;P.refresh();drain()
assert(c:Num()==1020 and c2:Num()==1020)
g.level=1;P.refresh();drain();assert(c:Num()==960 and c2:Num()==1020)
-- Missing load state is retried; construction does not permanently miss a player.
local p3,s3,c3=newPlayer(2,true);p3.GetPalStorage=function() return nil end
P.refresh();drain();assert(c3:Num()==960)
p3.GetPalStorage=function() return s3 end;P.refresh();drain();assert(c3:Num()==990)
-- A failed construction publishes no partial page and retains no orphan refs.
local p4,s4,c4=newPlayer(2,true);failSetup=true
local held=#owner.ReferencedObjects
P.refresh();drain();assert(c4:Num()==960 and s4.PageNum==32 and #owner.ReferencedObjects==held and #errors==1)
local count=created;failSetup=false;P.refresh();drain();assert(created==count,'do not hammer a failing native operation')
p4.policy.maxPalboxBonusPages=1;P.refresh();drain();assert(c4:Num()==990,'changed policy allows a fresh attempt')
-- External expansions above GG's entire cap are preserved.
local px,sx,cx=newPlayer(35,true)
for i=960,2999 do cx.SlotArray[i+1]=slot(i,cx) end
sx.PageNum=100;P.refresh();drain();assert(cx:Num()==3000 and sx.PageNum==100)
-- World travel drops only references owned by this module.
local foreign=obj('foreign');owner.ReferencedObjects[#owner.ReferencedObjects+1]=foreign
players={};world=obj('new-world');P.refresh();drain()
assert(#owner.ReferencedObjects==1 and owner.ReferencedObjects[1]==foreign)
assert(#errors==1,table.concat(errors,'\n'))
print('PASS: Palbox authority, level/page progression, bounded work, preserved Pal identity, occupied/locked/open pages, retries, GC ownership and world travel')

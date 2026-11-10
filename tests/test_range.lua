local root = assert(arg[1], 'pass the mod root with trailing slash')
local Range = dofile(root .. 'src/range.lua')
local function near(a,b) assert(math.abs(a-b)<0.00001, tostring(a)..' != '..tostring(b)) end
near(Range.radius(3500,1),3500)
near(Range.radius(3500,2),3640)
near(Range.radius(3500,8),4480)
near(Range.radius(3500,11),4900)
near(Range.radius(3500,25),6860)
near(Range.radius(3500,26),7000)
near(Range.radius(3500,35),7000)
-- The shipped config and the fallback agree on 4%; the 0..20 setting remains.
near(Range.settings().growthPercentPerLevel,4)
near(dofile(root..'config.lua').growthPercentPerLevel,4)
near(Range.settings({growthPercentPerLevel=99}).growthPercentPerLevel,20)
near(Range.settings({growthPercentPerLevel=-1}).growthPercentPerLevel,0)
-- A world that keeps the former 5% keeps the former radii.
near(Range.radius(3500,11,{growthPercentPerLevel=5}),5250)
near(Range.radius(3500,21,{growthPercentPerLevel=5}),7000)
near(Range.percent(35,{maxRangePercent=300}),200)
near(Range.percent(35,{growthPercentPerLevel=0}),100)
near(Range.percent(8,{growthPercentPerLevel=10,maxRangePercent=150}),150)
near(Range.percent(35,{maxRangePercent=0/0,growthPercentPerLevel=math.huge}),200)
near(Range.placementDistance(3500),14000)
for _,bad in ipairs({0,-1,1.5,math.huge,0/0,'8'}) do assert(not pcall(Range.percent,bad)) end
for _,bad in ipairs({0,-1,math.huge,0/0,'3500'}) do assert(not pcall(Range.radius,bad,8)) end

local function valid(o) return o and o:IsValid() end
local function obj(t) t.IsValid=function() return true end; return t end
local zero={A=0,B=0,C=0,D=0}
local baseId={A=1,B=0,C=0,D=0}
local groupId={A=7,B=0,C=0,D=0}
local settings=obj({BaseCampAreaRange=3500,BaseCampNeighborMinimumDistance=8000,
    BaseCampNeighborMinimumDistance_PVP=20000,GetFullName=function() return 'settings' end})
local registered={}
local mapObjects={}
local base
local manager=obj({
    GetInRangedBaseCamp=function(_,loc) return loc.inside and base or nil end,
    OnCreateMapObjectModelInServer=function(_,model) registered[#registered+1]=model end,
})
local util={GetGameSetting=function() return settings end,
    IsServer=function(_,model) return model.authority end,
    GetBaseCampManager=function() return manager end}
StaticFindObject=function() return util end
FindFirstOf=function() return obj({GetMaxLevel=function() return 35 end}) end
FindAllOf=function(class) return class=='PalMapObjectModel' and mapObjects or {} end
local E={root=root,range=Range,config={resetToVanilla=false},valid=valid,log=function() end,
    guard=function(_,fn) fn() end}
local function newBase(level,radius,authority)
    return obj({AreaRange=radius,level=level,authority=authority,bTemporary=false,
        IsAvailable=function() return true end,
        GetLevel=function(self) return self.level end,
        GetRange=function(self) return self.AreaRange end,
        GetId=function() return baseId end,
        GetTransform=function() return {Translation={X=0,Y=0,Z=0}} end,
        GetGroupIdBelongTo=function() return groupId end})
end
local function structure(group,camp,inside)
    return obj({GroupIdBelongTo=group,BaseCampIdBelongTo=camp,WorkableBounds={Location={inside=inside}}})
end
local eligible=structure(groupId,zero,true)
mapObjects={eligible,structure({A=8,B=0,C=0,D=0},zero,true),structure(groupId,baseId,true),structure(groupId,zero,false)}
local Runtime=dofile(root..'src/runtime.lua')(E)
base=newBase(8,3500,true)
assert(Runtime.apply(base)); near(base.AreaRange,4480)
assert(#registered==1 and registered[1]==eligible, 'only unassigned same-guild in-range structure qualifies')
for i=1,20 do assert(not Runtime.apply(base)); near(base.AreaRange,4480) end
base.level=9; assert(Runtime.apply(base)); near(base.AreaRange,4620)
local reloaded=dofile(root..'src/runtime.lua')(E)
assert(not reloaded.apply(base)); near(base.AreaRange,4620)
local second=newBase(2,3500,true); reloaded.apply(second); near(second.AreaRange,3640)
local client=newBase(8,3500,false)
assert(not reloaded.apply(client)); near(client.AreaRange,3500)
assert(reloaded.snapshot(client).nextPercent==nil, 'unmodded server must not advertise 132%')
client.AreaRange=4480; assert(reloaded.snapshot(client).nextPercent==nil,
    'matching current radius cannot prove remote cap or overlap rules')
local levelOne=newBase(1,3500,false)
assert(reloaded.snapshot(levelOne).nextPercent==nil, 'level-one vanilla radius cannot establish server support')
base.bTemporary=true; base.level=10
assert(not reloaded.apply(base)); near(base.AreaRange,4620)
base.bTemporary=false
E.config.resetToVanilla=true; assert(reloaded.apply(base)); near(base.AreaRange,3500)
E.config.resetToVanilla=false
reloaded.updatePlacement(base)
near(settings.BaseCampNeighborMinimumDistance,14000)
near(settings.BaseCampNeighborMinimumDistance_PVP,20000)
near(settings.BaseCampAreaRange,3500)
E.config.maxRangePercent=150
reloaded.updatePlacement(base); near(settings.BaseCampNeighborMinimumDistance,10500)
E.config.resetToVanilla=true
reloaded.updatePlacement(base); near(settings.BaseCampNeighborMinimumDistance,8000)
near(settings.BaseCampNeighborMinimumDistance_PVP,20000)
local rings={}
for _,name in ipairs({'AreaRange','AreaRange1'}) do
    rings[name]=obj({RelativeScale3D={X=70,Y=70,Z=100},
        GetFullName=function() return name end,
        SetRelativeScale3D=function(self,v) self.RelativeScale3D=v end})
end
local concrete=obj({BaseCampId=baseId,bForRaidBossArea=false})
local mapModel=obj({GetConcreteModel=function() return concrete end})
local actor=obj({GetModel=function() return mapModel end,AreaRange=rings.AreaRange,AreaRange1=rings.AreaRange1})
base.AreaRange=4725
reloaded.updateRing(actor,{['1:0:0:0']=base})
near(rings.AreaRange.RelativeScale3D.X,94.5)
near(rings.AreaRange1.RelativeScale3D.X,94.51)
near(rings.AreaRange.RelativeScale3D.Z,100)
reloaded.updateRing(actor,{['1:0:0:0']=base}); near(rings.AreaRange.RelativeScale3D.X,94.5)
print('PASS: growth, reload idempotence, authority, guild ownership, client display, reset, boundary scaling')

local close = {
    {baseline=3500,desired=7000,maximum=7000,x=0,y=0},
    {baseline=3500,desired=7000,maximum=7000,x=10500,y=0},
}
local t=Range.separate(close); near(t[1],5250); near(t[2],5250)
close[2].desired=3500
t=Range.separate(close); near(t[1],5250); near(t[2],3500)
for radius=3500,7000,175 do
    close[2].desired=radius
    t=Range.separate(close);near(t[1],5250)
end
close[2].x=6000
local conflicts
t,conflicts=Range.separate(close)
near(t[1],3500); near(t[2],3500); assert(#conflicts==1,'pre-existing vanilla overlap is reported')
math.randomseed(188)
for trial=1,100 do
    local bases={}
    for i=1,8 do
        bases[i]={baseline=3500,desired=3500+math.random()*3500,maximum=7000,
            x=i*7000,y=math.random()*7000}
    end
    local radii=Range.separate(bases)
    local reversed={}
    for i=#bases,1,-1 do reversed[#reversed+1]=bases[i] end
    local backwards=Range.separate(reversed)
    for i,a in ipairs(bases) do
        near(radii[i],backwards[#bases-i+1])
        assert(radii[i]>=a.baseline and radii[i]<=a.desired)
        for j=i+1,#bases do
            local b=bases[j]
            local d=math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)
            assert(radii[i]+radii[j]<=d+0.00001,'legacy bases cannot expand into each other')
        end
    end
end
print('PASS: legacy 200% ceiling, capped configuration, future placement spacing, symmetric overlap protection')

-- Exercise the engine adapter with two different guilds and both enumeration
-- orders, rather than only testing the geometry helper.
E.config={growthPercentPerLevel=5,maxRangePercent=200}
local a,b=newBase(35,7000,true),newBase(35,7000,true)
b.GetId=function() return {A=2,B=0,C=0,D=0} end
b.GetGroupIdBelongTo=function() return {A=8,B=0,C=0,D=0} end
b.GetTransform=function() return {Translation={X=10500,Y=0,Z=100000}} end
local collection={a,b}
FindAllOf=function(class) return class=='PalBaseCampModel' and collection or {} end
reloaded.refresh();near(a.AreaRange,5250);near(b.AreaRange,5250)
collection={b,a};reloaded.refresh();near(a.AreaRange,5250);near(b.AreaRange,5250)
for i=1,10 do reloaded.refresh() end
near(a.AreaRange,5250);near(b.AreaRange,5250)
b.authority=false;b.AreaRange=7000
reloaded.refresh();near(b.AreaRange,7000)
print('PASS: runtime applies stable proximity limits across guilds, ignores height bypass and never writes client radius')

-- Bonus cap is +300% maximum, not 300% total. Legacy inputs retain old behavior.
near(Range.percent(16,{growthPercentPerLevel=20,maxRangeBonusPercent=300}),400)
near(Range.radius(3500,35,{growthPercentPerLevel=20,maxRangeBonusPercent=999}),14000)
near(Range.placementDistance(3500,{maxRangeBonusPercent=300}),28000)
near(Range.percent(35,{maxRangePercent=999}),200)
near(Range.percent(35,{maxRangePercent=200,maxRangeBonusPercent=50}),150)
near(Range.percent(35,{maxRangeBonusPercent=math.huge}),200)
-- Chest slots: the cap is spread over the game's 35 levels, to the nearest slot.
local function slots(level,cap,max) return Range.storageBonus(level,{maxChestBonusSlots=cap},max) end
for level,expected in pairs({[1]=0,[2]=1,[3]=1,[4]=2,[10]=5,[11]=6,[20]=11,[34]=19,[35]=20}) do
 near(slots(level,20,35),expected)
 near(Range.storageBonus(level),expected) -- default cap, fallback level table
end
for level,expected in pairs({[1]=0,[2]=1,[4]=4,[18]=20,[34]=39,[35]=40}) do near(slots(level,40,35),expected) end
for level=1,45 do near(slots(level,0,35),0) end
-- Above the table maximum the bonus stays on the cap, never beyond it.
for _,level in ipairs({36,45,1000}) do near(slots(level,20,35),20);near(slots(level,40,35),40) end
-- Every cap and table size: starts at 0, ends on the cap, never steps down.
for cap=0,40 do
 for _,max in ipairs({2,35,50}) do
  local previous=0
  for level=1,max+3 do
   local bonus=slots(level,cap,max)
   assert(bonus>=previous and bonus<=cap and bonus%1==0)
   previous=bonus
  end
  near(slots(1,cap,max),0);near(slots(max,cap,max),cap)
 end
end
-- An unreadable level table falls back to the game's 35 levels.
for _,bad in ipairs({0,1,2.5,math.huge,0/0,'35'}) do near(Range.storageBonus(10,nil,bad),5) end
near(Range.storageBonus(10,nil,40),5);near(Range.storageBonus(35,nil,40),17);near(Range.storageBonus(40,nil,40),20)
near(Range.settings({maxChestBonusSlots=999}).maxChestBonusSlots,40)
near(Range.settings({maxChestBonusSlots=-1}).maxChestBonusSlots,0)
near(Range.settings({maxChestBonusSlots=3.9}).maxChestBonusSlots,3)
near(Range.settings({maxChestBonusSlots=0/0}).maxChestBonusSlots,20)
-- Future growth reservation remains non-overlapping even at four times radius.
local large=Range.separate({
 {baseline=3500,desired=14000,maximum=14000,x=0,y=0},
 {baseline=3500,desired=14000,maximum=14000,x=20000,y=0}})
near(large[1],10000);near(large[2],10000)
E.config={growthPercentPerLevel=20,maxRangeBonusPercent=300}
b.authority=true;b.GetTransform=function()return {Translation={X=20000,Y=0,Z=0}}end
reloaded.refresh();near(a.AreaRange,10000);near(b.AreaRange,10000)
print('PASS: bonus cap/migration, fourfold radius and placement, occupied-neighbour protection, slot spread over the level table and cap')

-- Base Upgrade preview: current and next slots, including an unchanged step.
E.config={maxChestBonusSlots=20}
local solo=newBase(2,3640,true)
collection={solo}
local function chestRow(model)
    local shot=reloaded.snapshot(model)
    return shot.chestCurrent,shot.chestNext,shot.atMaximum
end
local function same(model,current,following,maximum)
    local c,n,m=chestRow(model)
    assert(c==current and n==following and m==maximum,
        string.format('level %d: %s -> %s, expected %s -> %s',model.level,tostring(c),tostring(n),tostring(current),tostring(following)))
end
same(solo,1,1,false) -- level 2 -> 3 adds no slot, both values are still reported
solo.level=3;same(solo,1,2,false)
solo.level=10;same(solo,5,6,false)
solo.level=34;same(solo,19,20,false)
solo.level=35;same(solo,20,20,true)
solo.level=1;same(solo,0,1,false)
E.config.maxChestBonusSlots=10;same(solo,0,0,false) -- a small cap starts later, the row stays
E.config.maxChestBonusSlots=0;same(solo,nil,nil,false)
E.config={maxChestBonusSlots=20,resetToVanilla=true};same(solo,nil,nil,false)
-- A client spreads the server-authored cap, never its own configuration.
E.config={maxChestBonusSlots=0}
E.preview={read=function() return 140,{rangeEnabled=true,chestCap=40} end}
local remote=newBase(10,4760,false)
same(remote,11,12,false)
E.preview={read=function() return 140,{rangeEnabled=true} end} -- older server: radius only
same(remote,nil,nil,false)
E.preview=nil
print('PASS: preview rows follow the spread schedule on host and client, unchanged steps, small caps, off and reset')

-- The runtime's maximum must equal Range.radius at the cap for every integer cap,
-- or the separation check rejects the base (cap 57 used to differ by one bit).
local function capRuntime(baseline)
    settings.BaseCampAreaRange=baseline
    settings.GetFullName=function() return 'settings'..baseline end
    return dofile(root..'src/runtime.lua')(E)
end
for _,baselineRadius in ipairs({3500,2700}) do
    local capped=capRuntime(baselineRadius)
    for cap=0,300 do
        E.config={growthPercentPerLevel=20,maxRangeBonusPercent=cap}
        local only=newBase(35,baselineRadius,true)
        collection={only}
        capped.apply(only)
        near(only.AreaRange,baselineRadius*(100+cap)/100)
        only.AreaRange=baselineRadius
        capped.refresh()
        near(only.AreaRange,baselineRadius*(100+cap)/100)
        near(capped.snapshot(only).nextPercent,100+cap)
    end
end
-- Cap 57 with 4% growth crosses the cap between levels 15 and 16.
do
    local capped=capRuntime(3500)
    E.config={growthPercentPerLevel=4,maxRangeBonusPercent=57}
    for level,expected in pairs({[15]=3500*1.56,[16]=3500*1.57,[35]=3500*1.57}) do
        local only=newBase(level,3500,true)
        collection={only}
        capped.apply(only);near(only.AreaRange,expected)
        local shot=capped.snapshot(only)
        near(shot.currentPercent,expected/35)
        near(shot.nextPercent,157)
        only.AreaRange=3500
        capped.refresh();near(only.AreaRange,expected)
    end
end
print('PASS: every integer cap plans and applies its capped radius through apply, snapshot and refresh')

-- Clients plan nothing: a refresh with no authority never separates radii and
-- writes no AreaRange, yet still reports each base and updates its ring.
do
    local boxes,logs,writes,separations={}, {}, 0, 0
    local plain=FindAllOf
    FindAllOf=function(class)
        if class=='PalBaseCampModel' then return collection end
        return class=='BP_BuildObject_PalBoxV2_C' and boxes or {}
    end
    local separate,log=Range.separate,E.log
    Range.separate=function(...) separations=separations+1; return separate(...) end
    E.log=function(message) logs[#logs+1]=message end
    local function watched(model)
        local radius=model.AreaRange
        model.AreaRange=nil
        return setmetatable(model,{
            __index=function(_,key) if key=='AreaRange' then return radius end end,
            __newindex=function(table,key,value)
                if key=='AreaRange' then writes=writes+1; radius=value else rawset(table,key,value) end
            end})
    end
    E.config={growthPercentPerLevel=20,maxRangeBonusPercent=300}
    local watcher=dofile(root..'src/runtime.lua')(E)
    local first=watched(newBase(10,3500,false))
    local second=watched(newBase(20,4200,false))
    second.GetId=function() return {A=2,B=0,C=0,D=0} end
    second.GetTransform=function() return {Translation={X=50000,Y=0,Z=0}} end
    collection={first,second}
    boxes={actor}
    rings.AreaRange.RelativeScale3D={X=1,Y=1,Z=100}
    rings.AreaRange1.RelativeScale3D={X=1,Y=1,Z=100}
    watcher.refresh()
    assert(separations==0 and writes==0, 'a client refresh plans and writes nothing')
    near(first.AreaRange,3500);near(second.AreaRange,4200)
    near(rings.AreaRange.RelativeScale3D.X,3500/50)
    local ready=0
    for _,message in ipairs(logs) do if message:find('base ready: role=client',1,true) then ready=ready+1 end end
    assert(ready==2, 'both client bases are reported once')
    watcher.refresh()
    assert(separations==0 and writes==0)
    -- One authority among clients: the plan is made and only the authority is written.
    first.authority=true
    first.GetTransform=function() return {Translation={X=0,Y=0,Z=0}} end
    watcher.refresh()
    assert(separations==1, 'an authority in the list still plans once')
    assert(writes==1 and first.AreaRange>3500 and second.AreaRange==4200)
    collection={second,first}
    first.AreaRange=3500
    watcher.refresh()
    assert(separations==2 and first.AreaRange>3500 and second.AreaRange==4200)
    Range.separate,E.log,FindAllOf=separate,log,plain
end
print('PASS: a client refresh plans and writes nothing but still reports bases and updates rings')

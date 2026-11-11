local root = assert(arg[1], 'pass the mod root with trailing slash')
local Range = dofile(root .. 'src/range.lua')
local function near(a,b) assert(math.abs(a-b)<0.00001, tostring(a)..' != '..tostring(b)) end
-- The rule, read independently of src/range.lua: the cap spread over the levels
-- of the table, to the nearest unit, the whole cap at the last level and after.
local function ref(level,cap,levels)
    levels=levels or 35
    if level>=levels then return cap end
    return math.min(cap,math.floor(cap*(level-1)/(levels-1)+0.5))
end
-- The default cap, +100%, over the game's 35 levels.
local expectedPercent={[1]=0,[2]=3,[3]=6,[10]=26,[11]=29,[12]=32,[26]=74,[34]=97,[35]=100,[36]=100,[99]=100}
for level,bonus in pairs(expectedPercent) do
    near(Range.percent(level),100+bonus)
    near(Range.percent(level,nil,35),100+bonus)
    near(Range.percent(level,{maxRangeBonusPercent=100},35),100+bonus)
    near(Range.radius(3500,level),3500*(100+bonus)/100)
end
near(Range.radius(3500,1),3500)
near(Range.radius(3500,11),4515)
near(Range.radius(3500,35),7000)
near(Range.radius(3500,36),7000)
-- The shipped config and the fallback agree on +100%; the 0..300 limit remains.
near(Range.settings().maxRangeBonusPercent,100)
near(dofile(root..'config.lua').maxRangeBonusPercent,100)
near(Range.settings({maxRangeBonusPercent=999}).maxRangeBonusPercent,300)
near(Range.settings({maxRangeBonusPercent=-1}).maxRangeBonusPercent,0)
near(Range.settings({maxRangeBonusPercent=0/0}).maxRangeBonusPercent,100)
near(Range.settings({maxRangeBonusPercent=math.huge}).maxRangeBonusPercent,100)
-- The settings are exactly the two caps; the removed growth setting is gone.
do
    local keys={}
    for k in pairs(Range.settings({growthPercentPerLevel=4,maxRangePercent=150,other=1})) do keys[#keys+1]=k end
    table.sort(keys)
    assert(table.concat(keys,',')=='maxChestBonusSlots,maxRangeBonusPercent',table.concat(keys,','))
    keys={}
    for k in pairs(Range.limits) do keys[#keys+1]=k end
    table.sort(keys)
    assert(table.concat(keys,',')=='maxChestBonusSlots,maxRangeBonusPercent',table.concat(keys,','))
end
-- Any cap, any table: nearest whole percent, the whole cap on the last level and after,
-- never above it, never down. A level table of 35, 40, 2 and a missing one.
for _,levels in ipairs({35,40,2,50}) do
    for cap=0,300 do
        local previous=0
        for level=1,levels+4 do
            local bonus=Range.percent(level,{maxRangeBonusPercent=cap},levels)-100
            assert(bonus==ref(level,cap,levels),string.format('cap %d level %d of %d: %s',cap,level,levels,tostring(bonus)))
            assert(bonus>=previous and bonus<=cap and bonus%1==0)
            previous=bonus
        end
        assert(Range.percent(1,{maxRangeBonusPercent=cap},levels)==100)
        assert(Range.percent(levels,{maxRangeBonusPercent=cap},levels)==100+cap)
        assert(Range.percent(levels+1,{maxRangeBonusPercent=cap},levels)==100+cap)
    end
end
for cap=0,300 do
    local previous=0
    for level=1,38 do
        local bonus=Range.percent(level,{maxRangeBonusPercent=cap})-100
        assert(bonus==ref(level,cap) and bonus>=previous and bonus<=cap)
        previous=bonus
    end
    assert(Range.percent(35,{maxRangeBonusPercent=cap})==100+cap,'a missing table ends at 35 levels')
end
-- A fractional cap is reached exactly at the last level and never exceeded before it.
for _,cap in ipairs({0.4,0.9,1,57.3,150,299.9,300}) do
    local previous=100
    for level=1,36 do
        local percent=Range.percent(level,{maxRangeBonusPercent=cap})
        assert(percent<=100+cap and percent>=previous,cap..' level '..level..': '..percent)
        if level>=35 then assert(percent==100+cap,cap..' at level '..level) end
        previous=percent
    end
    near(Range.percent(34,{maxRangeBonusPercent=cap}),100+math.min(cap,math.floor(cap*33/34+0.5)))
    assert(Range.radius(3500,35,{maxRangeBonusPercent=cap})==3500*((100+cap)/100))
end
-- An unreadable level table falls back to the game's 35 levels.
for _,bad in ipairs({0,1,2.5,-3,math.huge,0/0,'35',false}) do
    near(Range.percent(10,nil,bad),126);near(Range.radius(3500,10,nil,bad),3500*1.26)
end
near(Range.percent(10,nil,40),100+ref(10,100,40));near(Range.percent(35,nil,40),100+ref(35,100,40))
near(Range.percent(40,nil,40),200)
-- The bonus is the same cap spread over a table of any size, for each bonus alike.
for level=1,40 do
    assert(Range.percent(level,{maxRangeBonusPercent=18},40)-100==Range.storageBonus(level,{maxChestBonusSlots=18},40))
end
-- Old totals (maxRangePercent) keep the effect they had at the cap; so does growth 0.
near(Range.percent(35,{maxRangePercent=300}),200)
near(Range.percent(8,{maxRangePercent=150}),100+ref(8,50))
near(Range.percent(35,{maxRangePercent=0/0}),200)
near(Range.percent(35,{maxRangePercent=50}),100)
near(Range.placementDistance(3500),14000)
for _,bad in ipairs({0,-1,1.5,math.huge,0/0,'8'}) do assert(not pcall(Range.percent,bad)) end
for _,bad in ipairs({0,-1,math.huge,0/0,'3500'}) do assert(not pcall(Range.radius,bad,8)) end
for _,bad in ipairs({0,-1,1.5,math.huge,0/0,'8'}) do assert(not pcall(Range.storageBonus,bad)) end
-- Legacy growth per level: 0 switched range off and still does; any other value is ignored.
do
    local off={growthPercentPerLevel=0}
    near(Range.settings(off).maxRangeBonusPercent,0)
    near(Range.settings({growthPercentPerLevel=0,maxRangeBonusPercent=100}).maxRangeBonusPercent,0)
    near(Range.settings({growthPercentPerLevel=0,maxRangePercent=175}).maxRangeBonusPercent,0)
    near(Range.settings({growthPercentPerLevel=0,maxRangeBonusPercent=300,maxChestBonusSlots=12}).maxChestBonusSlots,12)
    near(Range.percent(35,off),100);near(Range.radius(3500,35,off),3500)
    for _,growth in ipairs({4,5,20,99,0.5,-1,math.huge,0/0,'0','x'}) do
        near(Range.settings({growthPercentPerLevel=growth}).maxRangeBonusPercent,100)
        near(Range.settings({growthPercentPerLevel=growth,maxRangeBonusPercent=60}).maxRangeBonusPercent,60)
        near(Range.percent(35,{growthPercentPerLevel=growth,maxRangeBonusPercent=60}),160)
    end
    near(Range.percent(8,{growthPercentPerLevel=10,maxRangeBonusPercent=100}),100+ref(8,100))
end

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
E.objects={find=function(p) return StaticFindObject(p) end,all=function(n) return FindAllOf and FindAllOf(n) or {} end,first=function(n) return FindFirstOf and FindFirstOf(n) end}
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
local function at(level,cap,baseline) return (baseline or 3500)*(100+ref(level,cap or 100))/100 end
local Runtime=dofile(root..'src/runtime.lua')(E)
base=newBase(8,3500,true)
assert(Runtime.apply(base)); near(base.AreaRange,at(8))
assert(#registered==1 and registered[1]==eligible, 'only unassigned same-guild in-range structure qualifies')
for i=1,20 do assert(not Runtime.apply(base)); near(base.AreaRange,at(8)) end
base.level=9; assert(Runtime.apply(base)); near(base.AreaRange,at(9))
local reloaded=dofile(root..'src/runtime.lua')(E)
assert(not reloaded.apply(base)); near(base.AreaRange,at(9))
local second=newBase(2,3500,true); reloaded.apply(second); near(second.AreaRange,at(2))
local client=newBase(8,3500,false)
assert(not reloaded.apply(client)); near(client.AreaRange,3500)
assert(reloaded.snapshot(client).nextPercent==nil, 'unmodded server must not advertise 132%')
client.AreaRange=4480; assert(reloaded.snapshot(client).nextPercent==nil,
    'matching current radius cannot prove remote cap or overlap rules')
local levelOne=newBase(1,3500,false)
assert(reloaded.snapshot(levelOne).nextPercent==nil, 'level-one vanilla radius cannot establish server support')
base.bTemporary=true; base.level=10
assert(not reloaded.apply(base)); near(base.AreaRange,at(9))
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
E.config={maxRangeBonusPercent=100}
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
near(Range.percent(16,{maxRangeBonusPercent=300}),100+ref(16,300))
near(Range.percent(35,{maxRangeBonusPercent=300}),400)
near(Range.radius(3500,35,{maxRangeBonusPercent=999}),14000)
near(Range.placementDistance(3500,{maxRangeBonusPercent=300}),28000)
near(Range.percent(35,{maxRangePercent=999}),200)
near(Range.percent(35,{maxRangePercent=200,maxRangeBonusPercent=50}),150)
near(Range.percent(35,{maxRangeBonusPercent=math.huge}),200)
-- Chest slots: the cap is spread over the game's 35 levels, to the nearest slot.
local function slots(level,cap,max) return Range.storageBonus(level,{maxChestBonusSlots=cap},max) end
for level,expected in pairs({[1]=0,[2]=1,[3]=1,[4]=2,[10]=5,[11]=5,[12]=6,[20]=10,[34]=17,[35]=18}) do
 near(slots(level,18,35),expected)
 near(Range.storageBonus(level),expected) -- default cap, fallback level table
end
for level,expected in pairs({[1]=0,[2]=1,[4]=4,[18]=21,[34]=41,[35]=42}) do near(slots(level,42,35),expected) end
for level=1,45 do near(slots(level,0,35),0) end
-- Above the table maximum the bonus stays on the cap, never beyond it.
for _,level in ipairs({36,45,1000}) do near(slots(level,18,35),18);near(slots(level,42,35),42) end
-- Every cap and table size: starts at 0, ends on the cap, never steps down.
for cap=0,42,6 do
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
near(Range.storageBonus(10,nil,40),4);near(Range.storageBonus(35,nil,40),16);near(Range.storageBonus(40,nil,40),18)
near(Range.settings({maxChestBonusSlots=999}).maxChestBonusSlots,42)
near(Range.settings({maxChestBonusSlots=-1}).maxChestBonusSlots,0)
near(Range.settings({maxChestBonusSlots=3.9}).maxChestBonusSlots,6)
near(Range.settings({maxChestBonusSlots=0/0}).maxChestBonusSlots,18)
-- Future growth reservation remains non-overlapping even at four times radius.
local large=Range.separate({
 {baseline=3500,desired=14000,maximum=14000,x=0,y=0},
 {baseline=3500,desired=14000,maximum=14000,x=20000,y=0}})
near(large[1],10000);near(large[2],10000)
E.config={maxRangeBonusPercent=300}
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
solo.level=10;same(solo,5,5,false)
solo.level=11;same(solo,5,6,false)
solo.level=34;same(solo,17,18,false)
solo.level=35;same(solo,18,18,true)
solo.level=1;same(solo,0,1,false)
E.config.maxChestBonusSlots=10;same(solo,0,0,false) -- a small cap starts later, the row stays
E.config.maxChestBonusSlots=0;same(solo,nil,nil,false)
E.config={maxChestBonusSlots=20,resetToVanilla=true};same(solo,nil,nil,false)
-- A client spreads the server-authored cap, never its own configuration.
E.config={maxChestBonusSlots=0}
E.preview={read=function() return 140,{rangeEnabled=true,chestCap=40} end}
local remote=newBase(10,4760,false)
same(remote,11,12,false)
E.preview={read=function() return 140,{rangeEnabled=true,chestCap=20} end}
same(remote,5,6,false) -- do not resnap an older server's cap to 18 on the client
E.preview={read=function() return 140,{rangeEnabled=true,chestCap=42} end}
remote.level=35;same(remote,42,42,true)
E.preview={read=function() return 140,{rangeEnabled=true} end} -- older server: radius only
remote.level=10
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
        E.config={maxRangeBonusPercent=cap}
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
-- Cap 57 spread over 35 levels: 123% at level 15, 125% at level 16, the whole cap at 35.
do
    local capped=capRuntime(3500)
    E.config={maxRangeBonusPercent=57}
    for level,expected in pairs({[15]=3500*1.23,[16]=3500*1.25,[34]=3500*1.55,[35]=3500*1.57}) do
        local only=newBase(level,3500,true)
        collection={only}
        capped.apply(only);near(only.AreaRange,expected)
        local shot=capped.snapshot(only)
        near(shot.currentPercent,expected/35)
        near(shot.nextPercent,100+ref(math.min(level+1,35),57))
        only.AreaRange=3500
        capped.refresh();near(only.AreaRange,expected)
    end
end
-- The planner's maximum and the radius at the last level are the same number, bit for bit,
-- whatever the baseline, cap or size of the level table (Range.separate asserts maximum >= desired).
do
    local table_=35
    local plain=FindFirstOf
    FindFirstOf=function() return obj({GetMaxLevel=function() return table_ end}) end
    for _,levels in ipairs({35,40,12}) do
        table_=levels
        for _,baselineRadius in ipairs({3500,2700,1234.567,10000/3}) do
            local capped=capRuntime(baselineRadius)
            for cap=0,300 do
                E.config={maxRangeBonusPercent=cap}
                local only=newBase(levels,baselineRadius,true)
                collection={only}
                capped.apply(only)
                assert(only.AreaRange==baselineRadius*((100+cap)/100),
                    string.format('table %d baseline %s cap %d: %s',levels,baselineRadius,cap,tostring(only.AreaRange)))
                assert(Range.radius(baselineRadius,levels,{maxRangeBonusPercent=cap},levels)==only.AreaRange)
            end
        end
    end
    FindFirstOf=plain
end
-- The table's size reaches the plan: a base at level 20 gets 20/39 of a 40-level table, not 20/34.
do
    local plain=FindFirstOf
    E.config={maxRangeBonusPercent=100}
    for _,levels in ipairs({35,40}) do
        FindFirstOf=function() return obj({GetMaxLevel=function() return levels end}) end
        local only=newBase(20,3500,true)
        collection={only}
        capRuntime(3500).refresh()
        near(only.AreaRange,3500*(100+ref(20,100,levels))/100)
    end
    assert(ref(20,100,35)~=ref(20,100,40))
    FindFirstOf=plain
end
-- Before the level table loads, planning assumes the known 35 levels instead of failing.
do
    local plain=FindFirstOf
    FindFirstOf=function() return nil end
    E.config={maxRangeBonusPercent=100}
    local only=newBase(11,3500,true)
    collection={only}
    local targets=capRuntime(3500).targets({only})
    near(targets['1:0:0:0'],4515)
    FindFirstOf=plain
end
print('PASS: every integer cap plans and applies its capped radius through apply, snapshot and refresh')

-- The range is on while the cap is above 0. An old config.lua still names the removed growth
-- per level: it is ignored, except 0, which switched range off and still does.
do
    local capped=capRuntime(3500)
    local only=newBase(11,3500,true)
    collection={only}
    for _,case in ipairs({{cap=1,on=true},{cap=100,on=true},{cap=300,on=true},{cap=0,on=false},
            {cap=100,growth=4,on=true},{cap=100,growth=5,on=true},{cap=100,growth=20,on=true},
            {cap=100,growth=0,on=false},{cap=300,growth=0,on=false}}) do
        E.config={maxRangeBonusPercent=case.cap,growthPercentPerLevel=case.growth}
        local label='cap '..case.cap..' growth '..tostring(case.growth)
        assert(capped.bonuses(only).rangeEnabled==case.on,label)
        only.AreaRange=3500
        capped.apply(only);capped.refresh()
        near(only.AreaRange,case.on and 3500*(100+ref(11,case.cap))/100 or 3500)
    end
    near(only.AreaRange,3500)
    E.config={maxRangeBonusPercent=100,growthPercentPerLevel=5,resetToVanilla=true}
    assert(not capped.bonuses(only).rangeEnabled,'reset switches range off')
    E.config={resetToVanilla=false}
end
print('PASS: the range follows its cap alone; an old growth key is ignored, 0 still switches range off')

-- The server's preview of the next radius follows the size of the level table too.
do
    local plainAll,plainFirst=FindAllOf,FindFirstOf
    local levels,got=35,nil
    FindFirstOf=function() return obj({GetMaxLevel=function() return levels end}) end
    local only=newBase(20,3500,true)
    FindAllOf=function(class)
        if class=='PalBaseCampModel' then return {only} end
        return class=='BP_BuildObject_PalBoxV2_C' and {actor} or {}
    end
    E.preview={refresh=function() end,finish=function() end,publish=function(_,_,percent) got=percent end}
    E.config={maxRangeBonusPercent=100}
    for _,size in ipairs({35,40}) do
        levels,got=size,nil
        capRuntime(3500).refresh()
        near(got,100+ref(21,100,size))
    end
    assert(ref(21,100,35)~=ref(21,100,40))
    E.preview=nil
    FindAllOf,FindFirstOf=plainAll,plainFirst
end
print('PASS: the preview of the next radius spreads the cap over the level table')

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
    E.config={maxRangeBonusPercent=300}
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

-- One refresh resolves the policy and the level table once, not once per base;
-- nothing is remembered outside a refresh or after one that threw.
do
    local policyCalls,levelCalls,maxLevel,cap=0,0,35,300
    local plain=FindFirstOf
    FindFirstOf=function() levelCalls=levelCalls+1; return obj({GetMaxLevel=function() return maxLevel end}) end
    E.policy=function() policyCalls=policyCalls+1; return {maxRangeBonusPercent=cap,maxChestBonusSlots=20} end
    E.config={resetToVanilla=false}
    local memoRuntime=dofile(root..'src/runtime.lua')(E)
    local five={}
    for i=1,5 do
        local one=newBase(10,3500,true)
        one.GetId=function() return {A=10+i,B=0,C=0,D=0} end
        one.GetTransform=function() return {Translation={X=i*100000,Y=0,Z=0}} end
        five[i]=one
    end
    collection=five
    memoRuntime.refresh()
    for _,one in ipairs(five) do near(one.AreaRange,Range.radius(3500,10,{maxRangeBonusPercent=300})) end
    assert(policyCalls<=2 and levelCalls<=2, 'policy '..policyCalls..', level table '..levelCalls)
    -- A policy change between refreshes is seen by the second one.
    cap=150
    memoRuntime.refresh()
    for _,one in ipairs(five) do near(one.AreaRange,Range.radius(3500,10,{maxRangeBonusPercent=150})) end
    -- Outside a refresh every call resolves again.
    policyCalls,levelCalls=0,0
    memoRuntime.policy(five[1]);memoRuntime.policy(five[1]);memoRuntime.maxLevel();memoRuntime.maxLevel()
    assert(policyCalls==2 and levelCalls==2)
    -- A refresh that throws midway leaves no memo behind and rethrows its error.
    five[4].GetTransform=function() error('planning failed') end
    cap=300
    local ok,message=pcall(memoRuntime.refresh)
    assert(not ok and tostring(message):find('planning failed',1,true), tostring(message))
    five[4].GetTransform=function() return {Translation={X=400000,Y=0,Z=0}} end
    cap=80;maxLevel=12
    near(memoRuntime.policy(five[1]).maxRangeBonusPercent,80)
    assert(memoRuntime.maxLevel()==12 and memoRuntime.snapshot(five[1]).maximum==12)
    memoRuntime.refresh()
    near(five[4].AreaRange,Range.radius(3500,10,{maxRangeBonusPercent=80},12))
    E.policy,FindFirstOf=nil,plain
end
print('PASS: a refresh resolves policy and level table once, remembers nothing afterwards, even when it throws')

-- The level-table size is public for planning and storage: nil until the table loads.
do
    local plain=FindFirstOf
    local levelRuntime=dofile(root..'src/runtime.lua')(E)
    FindFirstOf=function() return nil end
    assert(levelRuntime.levels()==nil, 'an unloaded level table gives nil, not an error')
    FindFirstOf=function() return obj({GetMaxLevel=function() return 40 end}) end
    assert(levelRuntime.levels()==40, 'a loaded level table gives its size')
    FindFirstOf=function() return obj({GetMaxLevel=function() return 0 end}) end
    assert(levelRuntime.levels()==nil, 'an invalid level table gives nil')
    FindFirstOf=plain
end
print('PASS: the runtime reports the level-table size, or nil until it loads')

-- Shrink before expand: a base that gives room back is written before another
-- base grows, whatever the enumeration order.
do
    local order
    local function recorded(model,name)
        local radius=model.AreaRange
        model.AreaRange=nil
        return setmetatable(model,{
            __index=function(_,key) if key=='AreaRange' then return radius end end,
            __newindex=function(table,key,value)
                if key=='AreaRange' then order[#order+1]=name; radius=value else rawset(table,key,value) end
            end})
    end
    local previous=FindAllOf
    E.config={maxRangeBonusPercent=100}
    for _,shrinkFirst in ipairs({true,false}) do
        order={}
        local grows=recorded(newBase(35,3500,true),'grows')
        local shrinks=recorded(newBase(1,7000,true),'shrinks')
        shrinks.GetId=function() return {A=2,B=0,C=0,D=0} end
        shrinks.GetGroupIdBelongTo=function() return {A=8,B=0,C=0,D=0} end
        shrinks.GetTransform=function() return {Translation={X=50000,Y=0,Z=0}} end
        local list=shrinkFirst and {shrinks,grows} or {grows,shrinks}
        FindAllOf=function(class) return class=='PalBaseCampModel' and list or {} end
        dofile(root..'src/runtime.lua')(E).refresh()
        assert(#order==2 and order[1]=='shrinks' and order[2]=='grows',
            'shrink is written before expand, got '..table.concat(order,','))
        near(shrinks.AreaRange,3500);near(grows.AreaRange,7000)
    end
    FindAllOf=previous
end
print('PASS: a shrinking base is written before an expanding one in either enumeration order')

-- New settings snap to six; legacy server previews keep the cap actually granted.
for _,case in ipairs({{-1,0},{0,0},{2.9999,0},{3,6},{5,6},{18,18},{20,18},{20.9999,18},{21,24},{25,24},{39,42},{40,42},{42,42},{999,42}}) do
    near(Range.settings({maxChestBonusSlots=case[1]}).maxChestBonusSlots,case[2])
end
for cap=0,42,6 do
    near(Range.settings({maxChestBonusSlots=cap}).maxChestBonusSlots,cap)
    near(Range.storageBonus(35,{maxChestBonusSlots=cap},35),cap)
end
near(Range.settings().maxChestBonusSlots,18)
near(54+Range.storageBonus(35),72)
near(Range.storageAtCap(35,20,35),20);near(Range.storageAtCap(35,40,35),40)
for _,cap in ipairs({-1,1.5,43,math.huge,0/0,'18'}) do assert(not pcall(Range.storageAtCap,35,cap,35)) end
print('PASS: default18, six-slot caps through42, migration rounding, 72-slot Guild Chest and authoritative legacy previews')

local root = assert(arg[1], 'pass the mod root with trailing slash')
local Range = dofile(root .. 'src/range.lua')
local function near(a,b) assert(math.abs(a-b)<0.00001, tostring(a)..' != '..tostring(b)) end
near(Range.radius(3500,1),3500)
near(Range.radius(3500,2),3675)
near(Range.radius(3500,8),4725)
near(Range.radius(3500,9),4900)
near(Range.radius(3500,20),6825)
near(Range.radius(3500,21),7000)
near(Range.radius(3500,35),7000)
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
assert(Runtime.apply(base)); near(base.AreaRange,4725)
assert(#registered==1 and registered[1]==eligible, 'only unassigned same-guild in-range structure qualifies')
for i=1,20 do assert(not Runtime.apply(base)); near(base.AreaRange,4725) end
base.level=9; assert(Runtime.apply(base)); near(base.AreaRange,4900)
local reloaded=dofile(root..'src/runtime.lua')(E)
assert(not reloaded.apply(base)); near(base.AreaRange,4900)
local second=newBase(2,3500,true); reloaded.apply(second); near(second.AreaRange,3675)
local client=newBase(8,3500,false)
assert(not reloaded.apply(client)); near(client.AreaRange,3500)
assert(reloaded.snapshot(client).nextPercent==nil, 'unmodded server must not advertise 140%')
client.AreaRange=4725; assert(reloaded.snapshot(client).nextPercent==nil,
    'matching current radius cannot prove remote cap or overlap rules')
local levelOne=newBase(1,3500,false)
assert(reloaded.snapshot(levelOne).nextPercent==nil, 'level-one vanilla radius cannot establish server support')
base.bTemporary=true; base.level=10
assert(not reloaded.apply(base)); near(base.AreaRange,4900)
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
print('PASS: 200% hard ceiling, capped configuration, future placement spacing, symmetric overlap protection')

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

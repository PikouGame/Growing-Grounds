local root = assert(arg[1], 'pass the mod root with trailing slash')
local Range = dofile(root .. 'src/range.lua')
local function near(a,b) assert(math.abs(a-b)<0.00001, tostring(a)..' != '..tostring(b)) end
near(Range.radius(3500,1),3500)
near(Range.radius(3500,2),3675)
near(Range.radius(3500,8),4725)
near(Range.radius(3500,9),4900)
near(Range.radius(3500,35),9450)
for _,bad in ipairs({0,-1,1.5,math.huge,0/0,'8'}) do assert(not pcall(Range.percent,bad)) end
for _,bad in ipairs({0,-1,math.huge,0/0,'3500'}) do assert(not pcall(Range.radius,bad,8)) end
local cap=Range.reward(3500,35,35)
assert(cap.atMaximum and cap.currentRadius==cap.nextRadius)

local function valid(o) return o and o:IsValid() end
local function obj(t) t.IsValid=function() return true end; return t end
local zero={A=0,B=0,C=0,D=0}
local baseId={A=1,B=0,C=0,D=0}
local groupId={A=7,B=0,C=0,D=0}
local settings=obj({BaseCampAreaRange=3500,GetFullName=function() return 'settings' end})
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
local E={range=Range,config={resetToVanilla=false},valid=valid,log=function() end,
    guard=function(_,fn) fn() end}
local function newBase(level,radius,authority)
    return obj({AreaRange=radius,level=level,authority=authority,bTemporary=false,
        IsAvailable=function() return true end,
        GetLevel=function(self) return self.level end,
        GetRange=function(self) return self.AreaRange end,
        GetId=function() return baseId end,
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
client.AreaRange=4725; assert(reloaded.snapshot(client).nextPercent==140)
local levelOne=newBase(1,3500,false)
assert(reloaded.snapshot(levelOne).nextPercent==nil, 'level-one vanilla radius cannot establish server support')
base.bTemporary=true; base.level=10
assert(not reloaded.apply(base)); near(base.AreaRange,4900)
base.bTemporary=false
E.config.resetToVanilla=true; assert(reloaded.apply(base)); near(base.AreaRange,3500)
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

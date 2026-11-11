local root=assert(arg[1])
local function obj(name,t)
    t=t or {};t.alive=true
    function t:IsValid() return self.alive end
    function t:GetFullName() return name end
    return t
end
local class=obj('Class /Script/Engine.SceneComponent')
local server,failSetup=true,false
local created,destroyed,updates,wakes=0,0,0,0
local boxes={}
local utility={IsServer=function() return server end}
StaticFindObject=function(path) return path:find('Default__PalUtility',1,true) and utility or class end
FindAllOf=function(name) assert(name=='BP_BuildObject_PalBoxV2_C');return boxes end
local id={A=12,B=34,C=56,D=78}
local base=obj('base',{GetId=function() return id end,GetRange=function() return 4900 end,GetLevel=function() return 9 end})
local concrete=obj('concrete',{BaseCampId=id})
local model=obj('model',{GetConcreteModel=function() return concrete end})
local function box(name)
    local b=obj(name,{bReplicates=true,components={},GetModel=function() return model end,IsA=function() return true end})
    function b:FlushNetDormancy() wakes=wakes+1 end
    function b:ForceNetUpdate() updates=updates+1 end
    function b:K2_GetComponentsByClass()
        local values={}
        for i,c in ipairs(self.components) do values[i]={get=function() return c end} end
        return values
    end
    function b:AddComponentByClass(c,manual,transform,defer)
        assert(c==class and manual and not defer,'never alter the native root or attach gameplay children')
        created=created+1
        local component=obj(name..'.SceneComponent'..created,{RelativeLocation=transform.Translation,
            RelativeScale3D=transform.Scale3D or {X=1,Y=1,Z=1}})
        function component:GetClass() return class end
        function component:GetOwner() return b end
        function component:SetMobility(v) assert(v==2) end
        function component:SetComponentTickEnabled(v) assert(not v) end
        function component:SetVisibility(v) assert(not v) end
        function component:SetHiddenInGame(v) assert(v) end
        function component:K2_SetRelativeLocation(v)
            self.RelativeLocation={X=v.X,Y=v.Y,Z=v.Z}
        end
        function component:SetRelativeScale3D(v) self.RelativeScale3D={X=v.X,Y=v.Y,Z=v.Z} end
        function component:SetIsReplicated(v) assert(not failSetup,'simulated native failure');self.replicates=v end
        function component:K2_DestroyComponent(owner) assert(owner==b);self.alive=false;destroyed=destroyed+1 end
        self.components[#self.components+1]=component
        return component
    end
    return b
end
local host,remote=box('serverPalbox'),box('clientPalbox')
boxes={host}
local E={range=dofile(root..'src/range.lua'),runtime={baseline=function() return 3500 end, bonuses=function() return {rangeEnabled=true,chestCap=20} end},valid=function(o) return o and o:IsValid() end,log=function() end}
E.objects={find=function(p) return StaticFindObject(p) end,all=function(n) return FindAllOf and FindAllOf(n) or {} end,first=function(n) return FindFirstOf and FindFirstOf(n) end}
local make=dofile(root..'src/preview.lua')
local publisher=make(E)
publisher.refresh();publisher.publish(host,base,145);publisher.finish()
local c=host.components[1]
assert(created==1 and c.replicates)
assert(c.RelativeLocation.X==14000 and c.RelativeLocation.Y==14500 and c.RelativeLocation.Z==441050)
assert(wakes==1 and updates==1,'new component wakes the existing Palbox channel once')
publisher.refresh();publisher.publish(host,base,145);publisher.finish()
assert(created==1 and wakes==1 and updates==1,'unchanged metadata does not create or wake anything')
server=false;boxes={remote}
local client=make(E)
client.refresh();assert(client.read(base,3500,9,4900)==nil,'no assumed network delivery')
-- Copy the wire fields to a separate simulated client component. This verifies
-- decoding/lifecycle, not the engine's delivery; live client proof is required.
local cc=remote:AddComponentByClass(class,true,{Translation={X=0,Y=0,Z=0}},false)
local function deliver() cc:K2_SetRelativeLocation(c.RelativeLocation);client.refresh() end
deliver()
assert(client.read(base,3500,9,4900)==145,'server value decoded without local policy inference')
assert(client.read(base,3500,10,5075)==nil,'out-of-order level/radius never shows stale next')
local _,policy,pending=client.read(base,3500,10,5075)
assert(pending and policy.chestCap==20 and policy.rangeEnabled,
    'split replication retains server policy and marks the rewards pending')
local revision=client.revision(base)
cc.RelativeLocation={X=14500,Y=15000,Z=400000+10+1001*41}
assert(client.revision(base)~=revision,'observe newly delivered metadata without rediscovery')
local upgraded,_,waiting=client.read(base,3500,10,5075)
assert(upgraded==150 and not waiting,'coherent preview releases the pending UI')
deliver()
assert(client.read(base,3500,9,5000)==nil,'mismatched replicated current range is rejected')
-- Between two refreshes the watcher only checks identity and decodes the value;
-- the owner and class proof belongs to refresh.
do
    local getOwner,getClass,asked=cc.GetOwner,cc.GetClass,0
    cc.GetOwner=function(...) asked=asked+1;return getOwner(...) end
    cc.GetClass=function(...) asked=asked+1;return getClass(...) end
    local before=client.revision(base)
    assert(client.read(base,3500,9,4900)==145 and before,'cheap path returns the same values')
    cc.RelativeLocation={X=14500,Y=15000,Z=400000+9+1001*41}
    assert(client.revision(base)~=before,'a changed preview still changes the revision')
    assert(asked==0,'revision and read never ask for the owner or the class between refreshes')
    client.refresh();assert(asked>0,'refresh still proves the owner and the class')
    cc.GetOwner,cc.GetClass=getOwner,getClass
    deliver()
end
client.publish(remote,base,200);assert(cc.RelativeLocation.Y==14500,'client cannot publish')
server=true;boxes={host}
publisher.refresh();publisher.publish(host,base,140);publisher.finish()
assert(wakes==2 and updates==2)
deliver();assert(client.read(base,3500,9,4900)==140,'server cap/proximity can stop next growth')
publisher.refresh();publisher.publish(host,base,nil);publisher.finish()
deliver();assert(client.read(base,3500,9,4900)==nil,'reset/unknown never invents a next value')
publisher.refresh();publisher.publish(host,base,145);publisher.finish()
local reloaded=make(E)
reloaded.refresh();reloaded.publish(host,base,145);reloaded.finish()
assert(#host.components==1,'reload adopts existing component instead of leaking a duplicate')
reloaded.refresh();reloaded.finish()
assert(destroyed==1,'base no longer published removes its preview component')
failSetup=true
assert(not pcall(reloaded.publish,host,base,145))
assert(destroyed==2,'failed setup destroys only its partial component')
failSetup=false
host.bReplicates=false
assert(not pcall(reloaded.publish,host,base,145),'refuse an owner with no existing network channel')
host.bReplicates=true
server=false;boxes={remote}
deliver()
cc.RelativeLocation.Z=231009
client.refresh();assert(client.read(base,3500,9,4900)==nil,'old standalone actor protocol is rejected')
cc.RelativeLocation.Z=232009;cc.RelativeLocation.Y=0/0
client.refresh();assert(client.read(base,3500,9,4900)==nil,'malformed network values are rejected')
deliver();remote.IsA=function() return false end
client.refresh();assert(client.read(base,3500,9,4900)==nil,'foreign owners cannot supply preview')
remote.IsA=function() return true end
cc.GetClass=function() return obj('Class /Script/Engine.StaticMeshComponent') end
client.refresh();assert(client.read(base,3500,9,4900)==nil,'native game meshes never carry mod metadata')
print('PASS: component lifecycle, separate-client decoding, stale/invalid rejection, cap, reset, reload and cleanup; native delivery requires live proof')

cc.GetClass=function() return class end
cc.RelativeLocation={X=39500,Y=40000,Z=232009}
client.refresh();assert(client.read(base,3500,9,13825)==400,'+300% bonus can be previewed as 400% total')
cc.RelativeLocation.Y=40100
client.refresh();assert(client.read(base,3500,9,13825)==nil,'oversized server preview rejected')
print('PASS: expanded preview range, +300% boundary accepted and out-of-range values rejected')

cc.RelativeLocation={X=14000,Y=14500,Z=400000+9+1001*41}
client.refresh()
local nextValue,metadata=client.read(base,3500,9,4900)
assert(nextValue==145 and metadata.rangeEnabled and metadata.chestCap==20)
for _,cap in ipairs({0,18,20,40,42}) do
    for _,enabled in ipairs({false,true}) do
        cc.RelativeLocation.Z=400000+9+1001*(cap*2+(enabled and 1 or 0))
        client.refresh()
        local _,value=client.read(base,3500,9,4900)
        assert(value and value.chestCap==cap and value.rangeEnabled==enabled)
    end
end
cc.RelativeLocation.Z=232009
client.refresh()
local _,legacy=client.read(base,3500,9,4900)
assert(legacy and legacy.chestCap==nil and legacy.rangeEnabled==nil,'never infer missing settings from an older server')
for _,invalid in ipairs({400000,400000+1001*86+9,400009.5}) do
    cc.RelativeLocation.Z=invalid;client.refresh()
    assert(client.read(base,3500,9,4900)==nil)
end
print('PASS: authoritative bonus policy, independent disabled flags, 0..42 chest cap and legacy compatibility')

-- The decoder's bounds follow Range.limits: the exact maxima round-trip, one above is refused.
local limits=E.range.limits
assert(limits.maxChestBonusSlots==42 and limits.maxRangeBonusPercent==300)
local function probe(x,y,flags)
    cc.RelativeLocation={X=x,Y=y,Z=400000+9+1001*flags}
    client.refresh()
    local _,value=client.read(base,3500,9,x/100*3500/100)
    return value
end
local top=limits.maxChestBonusSlots*2+1
local cap=probe(40000,-100,top)
assert(cap and cap.chestCap==42 and cap.rangeEnabled,'chest cap at the maximum round-trips')
assert(probe(40000,-100,top+1)==nil and probe(40000,-100,top+2)==nil,'chest cap one above the maximum is refused')
assert(probe(40000,40000,top),'+300 percent range bonus round-trips as current and next')
assert(probe(40001,-100,top),'range bonus at the upper bound is accepted')
assert(probe(40002,-100,top)==nil and probe(14000,40002,top)==nil,'range bonus one hundredth above is refused')
-- One source: a fresh Range with raised limits moves the decoder with it.
local raised=dofile(root..'src/range.lua')
raised.limits.maxChestBonusSlots=45;raised.limits.maxRangeBonusPercent=350
local E2={range=raised,runtime=E.runtime,objects=E.objects,valid=E.valid,log=E.log}
local wide=make(E2)
wide.refresh()
local function wideRead(x,y,flags)
    cc.RelativeLocation={X=x,Y=y,Z=400000+9+1001*flags}
    wide.refresh()
    local _,value=wide.read(base,3500,9,x/100*3500/100)
    return value
end
assert(wideRead(45000,-100,91),'raised chest cap and range bonus are accepted by the decoder')
assert(wideRead(45000,-100,93)==nil and wideRead(45002,-100,91)==nil,'and the raised bounds still refuse one above')
assert(probe(45000,-100,91)==nil,'the unraised decoder still refuses them')
print('PASS: preview bounds follow Range.limits at each maximum and one above')

-- Version 3 carries a separate Palbox page cap, preserving older formats.
server=false;boxes={remote};cc.GetClass=function() return class end
for pages=0,64 do
    for _,chest in ipairs({0,18,42}) do
        for _,enabled in ipairs({false,true}) do
            cc.RelativeLocation={X=14000,Y=14500,Z=1000000+9+1001*(pages*128+chest*2+(enabled and 1 or 0))}
            client.refresh()
            local _,value=client.read(base,3500,9,4900)
            assert(value and value.palboxCap==pages and value.chestCap==chest and value.rangeEnabled==enabled)
            assert(cc.RelativeLocation.Z<2^24,'wire integer must stay exact in single precision')
        end
    end
end
for _,z in ipairs({1000000,1000000+9.5,1000000+9+1001*(65*128),1000000+9+1001*86}) do
    cc.RelativeLocation.Z=z;client.refresh()
    assert(client.read(base,3500,9,4900)==nil,'invalid new payload accepted: '..z)
end
cc.RelativeLocation={X=14000,Y=14500,Z=400000+9+1001*41};client.refresh()
local _,oldPolicy=client.read(base,3500,9,4900)
assert(oldPolicy and oldPolicy.palboxCap==nil,'an older server never grants the local default Palbox bonus')
server=true;local newHost=box('newPublisher');boxes={newHost}
E.runtime.bonuses=function() return {rangeEnabled=true,chestCap=18,palboxCap=32} end
local pp=make(E);pp.refresh();pp.publish(newHost,base,145);pp.finish()
cc.RelativeLocation=newHost.components[1].RelativeLocation
server=false;boxes={remote};client.refresh()
local _,policy=client.read(base,3500,9,4900)
assert(policy and policy.palboxCap==32 and policy.chestCap==18)
print('PASS: Palbox wire cap0..64, legacy absence, malformed payload rejection and publisher/client round-trip')

-- The optional maximum uses the same invisible component, with independent
-- replication arrival and old identity-scale components handled explicitly.
server=true;boxes={newHost}
pp.refresh();pp.publish(newHost,base,145,200);pp.finish()
local maximumComponent=newHost.components[1]
local function maximumRead()
    local _,value=client.read(base,3500,9,4900)
    return value and value.maximumPercent
end
server=false;boxes={remote}
cc.RelativeLocation=maximumComponent.RelativeLocation
cc.RelativeScale3D={X=1,Y=1,Z=1};client.refresh()
assert(maximumRead()==nil,'old servers and not-yet-delivered scale never invent a maximum')
local beforeMaximum=client.revision(base)
cc:SetRelativeScale3D(maximumComponent.RelativeScale3D)
assert(maximumRead()==200 and client.revision(base)~=beforeMaximum,'late maximum wakes the UI watcher')
for _,invalid in ipairs({{X=40002,Y=14000,Z=cc.RelativeLocation.Z},
    {X=20000,Y=14500,Z=cc.RelativeLocation.Z},{X=20000,Y=14000,Z=cc.RelativeLocation.Z+1},
    {X=0/0,Y=14000,Z=cc.RelativeLocation.Z},{X=20000,Y=math.huge,Z=cc.RelativeLocation.Z}}) do
    cc.RelativeScale3D=invalid
    assert(maximumRead()==nil and client.read(base,3500,9,4900)==145,
        'malformed/stale maximum hides only the optional outer ring')
end
for _,maximum in ipairs({100,157.3,200,400}) do
    server=true;boxes={newHost}
    local beforeCount=created
    pp.refresh();pp.publish(newHost,base,145,maximum);pp.finish()
    assert(created==beforeCount,'maximum adds no replicated object')
    local beforeUpdates=updates
    pp.refresh();pp.publish(newHost,base,145,maximum);pp.finish()
    assert(updates==beforeUpdates,'unchanged maximum does not wake the Palbox')
    cc:SetRelativeScale3D(maximumComponent.RelativeScale3D)
    server=false;boxes={remote};client.refresh()
    assert(math.abs(maximumRead()-maximum)<0.00001)
end
server=true;boxes={newHost}
pp.refresh();pp.publish(newHost,base,145);pp.finish()
cc:SetRelativeScale3D(maximumComponent.RelativeScale3D)
server=false;boxes={remote};client.refresh()
assert(maximumRead()==nil,'removing the maximum clears its payload')
print('PASS: maximum preview round-trip, split replication, legacy absence, malformed values and no extra component')

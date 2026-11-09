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
        local component=obj(name..'.SceneComponent'..created,{RelativeLocation=transform.Translation})
        function component:GetClass() return class end
        function component:GetOwner() return b end
        function component:SetMobility(v) assert(v==2) end
        function component:SetComponentTickEnabled(v) assert(not v) end
        function component:SetVisibility(v) assert(not v) end
        function component:SetHiddenInGame(v) assert(v) end
        function component:K2_SetRelativeLocation(v)
            self.RelativeLocation={X=v.X,Y=v.Y,Z=v.Z}
        end
        function component:SetIsReplicated(v) assert(not failSetup,'simulated native failure');self.replicates=v end
        function component:K2_DestroyComponent(owner) assert(owner==b);self.alive=false;destroyed=destroyed+1 end
        self.components[#self.components+1]=component
        return component
    end
    return b
end
local host,remote=box('serverPalbox'),box('clientPalbox')
boxes={host}
local E={runtime={baseline=function() return 3500 end, bonuses=function() return {rangeEnabled=true,chestCap=20} end},valid=function(o) return o and o:IsValid() end,log=function() end}
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
for _,cap in ipairs({0,20,40}) do
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
for _,invalid in ipairs({400000,400000+1001*82+9,400009.5}) do
    cc.RelativeLocation.Z=invalid;client.refresh()
    assert(client.read(base,3500,9,4900)==nil)
end
print('PASS: authoritative bonus policy, independent disabled flags, 0..40 chest cap and legacy compatibility')

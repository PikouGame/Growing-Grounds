local root=assert(arg[1],'pass root with trailing slash')
local M=dofile(root..'src/motion.lua')
local W=dofile(root..'src/wave.lua')
assert(M.duration<=1.2 and W.duration==2.4,'shorter bounce, without accelerating the accepted outward wave')
local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a)..' != '..tostring(b)) end
local function observe(s,l,r,t) return M.observe(s,l,r,t,true) end
local s,action=observe(nil,8,4725,0)
assert(action=='snap' and not s.animation,'joining never animates')
s,action=observe(s,9,4725,1)
assert(action=='keep' and not s.animation,'level can arrive first')
s,action=observe(s,9,4900,6)
assert(action=='start'); near(M.sample(s,6),4725)
near(M.sample(s,6+M.duration),4900)
near(M.sample(s,6+M.duration*0.68),4910.5)
for i=0,160 do
    local r=M.sample(s,6+i/100)
    assert(r>=4725 and r<=4910.50001,'bounce must stay within growth-sized overshoot')
end
local rendered=M.sample(s,6.5)
s,action=observe(s,10,5075,6.5)
assert(action=='start'); near(M.sample(s,6.5),rendered)
s,action=observe(s,10,3500,7)
assert(action=='snap' and not s.animation and s.radius==3500,'reset snaps')
s=observe(nil,8,4725,0)
s,action=observe(s,8,4900,1)
assert(not s.animation and s.radius==4725,'radius can arrive first')
s,action=observe(s,9,4900,6)
assert(action=='start')
s,action=observe(s,9,4900,0)
assert(action=='snap' and not s.animation,'world clock reset')
s=observe(nil,8,4725,0)
s,action=observe(s,9,4900,20)
assert(action=='snap' and not s.animation,'long absence is not an upgrade event')
s=observe(nil,8,4725,0)
s=observe(s,8,4900,1)
s=observe(s,8,4900,6)
s,action=observe(s,8,4900,11)
assert(action=='snap' and s.radius==4900,'unpaired server radius eventually reconciles')
s,action=M.observe(s,9,5075,12,false)
assert(action=='snap' and not s.animation)

-- Contour geometry, sequencing, performance bounds and cache lifecycle.
local objects,queue,errors={}, {}, {}
local time,dedicated,lookups,traces,created,destroyed,sections=0,false,0,0,0,0,0
local systemChecks=0
local failMesh=false
local traceTick,terrainOffset=nil,0
local function obj(p,t)
    t=t or {};t.alive=true
    t.IsValid=function(self) return self.alive end
    t.GetFullName=function()
        if p=='/Script/Engine.Default__KismetSystemLibrary' then systemChecks=systemChecks+1 end
        return 'Mock '..p
    end
    objects[p]=t;return t
end
StaticFindObject=function(p) lookups=lookups+1;return objects[p] end
FName=function(s) return s end
ExecuteInGameThreadWithDelay=function(delay,fn) assert(delay==16);queue[#queue+1]=fn end
ExecuteWithDelay=function() error('Animation must never schedule asynchronous Lua') end
LoadAsset=function(p) obj(p) end
local function height(x,y) return 100+x*0.1+y*0.05+terrainOffset end
obj('/Script/Engine.Default__KismetSystemLibrary',{
    GetGameTimeInSeconds=function() return time end,
    LineTraceSingleForObjects=function(_,actor,start,finish,types,complex,ignore,draw,out)
        traces=traces+1
        if traceTick then traceTick() end
        assert(types[1]==0 and complex and draw==0 and ignore[1]==actor)
        out.OutHit={ImpactPoint={X=start.X,Y=start.Y,Z=height(start.X,start.Y)}}
        return true
    end,
})
obj('/Script/Pal.Default__PalUtility',{IsDedicatedServer=function() return dedicated end})
obj('/Script/ProceduralMeshComponent.ProceduralMeshComponent')
local imports=0
obj('/Script/Engine.Default__KismetRenderingLibrary',{
    ImportFileAsTexture2D=function(_,actor,path)
        assert(path==root..'assets/contour-gradient.png' or path==root..'assets/ground-wave.png')
        imports=imports+1;return obj('/Transient.Gradient'..imports)
    end,
})
local function ring(p,z)
    return obj(p,{RelativeScale3D={X=70,Y=70,Z=z},
        SetRelativeScale3D=function(self,v) self.RelativeScale3D=v end,
        K2_GetComponentLocation=function() return {X=100,Y=200,Z=300} end,
        IsVisible=function() return true end})
end
local actor,component
actor=obj('/World.Palbox',{
    AreaRange=ring('/World.Palbox.AreaRange',100),
    AreaRange1=ring('/World.Palbox.AreaRange1',100.01),
    AddComponentByClass=function()
        created=created+1
        local id=created
        component=obj('/World.Contour'..id,{
            geometry={},materials={},sectionVisible={},
            SetVisibility=function(self,v) self.visible=v end,
            SetMeshSectionVisible=function(self,layer,v) self.sectionVisible[layer]=v end,
            SetHiddenInGame=function() end,
            SetCollisionEnabled=function(_,v) assert(v==0) end,
            SetGenerateOverlapEvents=function(_,v) assert(not v) end,
            SetIsReplicated=function(_,v) assert(not v) end,
            SetCastShadow=function(_,v) assert(not v) end,
            K2_SetWorldTransform=function(self,v) self.position=v.Translation;self.scale=v.Scale3D end,
            K2_SetWorldLocation=function(self,v) self.position=v end,
            GetOwner=function() return actor end,
            K2_DestroyComponent=function(self,owner)
                assert(owner==actor);self.alive=false;destroyed=destroyed+1
            end,
            CreateMeshSection=function(self,layer,verts,indices,normals,uv,colors,tangents,collision)
                sections=sections+1
                if failMesh then error('unsupported mesh call') end
                assert(not collision and #normals==#verts and #uv==#verts)
                for _,i in ipairs(indices) do assert(i>=0 and i<#verts) end
                self.geometry[layer+1]={vertices=verts,indices=indices,uv=uv}
                self.sectionVisible[layer]=true
            end,
            CreateDynamicMaterialInstance=function(self,layer)
                local mid=obj('/World.Contour'..id..'.Material'..layer,{
                    SetTextureParameterValue=function(self,k,v) self[k]=v end,
                    SetVectorParameterValue=function(self,k,v) self[k]=v end,
                    SetScalarParameterValue=function(self,k,v) self[k]=v end,
                })
                self.materials[layer+1]=mid;return mid
            end,
        })
        return component
    end,
})
local E={root=root,config={upgradeWave=false},valid=function(o) return o and o:IsValid() end,log=function() end,
    guard=function(label,fn)
        local ok,result=pcall(fn)
        if not ok then errors[#errors+1]=label..':'..tostring(result) end
        return ok,result
    end}
E.objects={find=function(p) return StaticFindObject(p) end,all=function(n) return FindAllOf and FindAllOf(n) or {} end,first=function(n) return FindFirstOf and FindFirstOf(n) end}
local B=dofile(root..'src/boundary.lua')(E,M)
local level,radius=8,4725
local base=obj('/World.BaseModel',{GetLevel=function() return level end})
local function refresh()
    B.beginRefresh();B.update(actor,base,'base',radius);B.endRefresh()
end
local function frame(t)
    time=t;local batch=queue;queue={}
    local beforeTrace,beforeSections=traces,sections
    for _,fn in ipairs(batch) do fn() end
    assert(traces-beforeTrace<=64,'terrain work must stay bounded per update')
    assert(sections-beforeSections<=1,'mesh creation must be spread over updates')
end
local function pump(start,frames)
    for i=1,frames do frame(start+i*0.016) end
end
-- Exercise real level/radius changes, not a production replay API.
local function clear()
    B.beginRefresh();B.endRefresh()
    refresh() -- a reloaded base snaps to its authoritative radius
end
local function upgrade()
    local l,r=level,radius
    B.beginRefresh();B.endRefresh()
    level,radius=l-1,r-175;refresh()
    level,radius=l,r;refresh()
end
refresh();near(actor.AreaRange.RelativeScale3D.X,94.5)
assert(created==0 and #queue==0)
time=1;level=9;refresh();assert(#queue==0)
time=6;radius=4900;refresh()
local beforeLookup=lookups
local beforeSystemChecks=systemChecks
local savedClock=os.clock
local sampleClock=0
os.clock=function() return sampleClock end
traceTick=function() sampleClock=sampleClock+0.002 end
local beforeSlowTrace=traces
frame(6.016)
os.clock=savedClock;traceTick=nil
assert(traces-beforeSlowTrace==2,'3 ms shared deadline stops after the native call that crossed it')
assert(lookups==beforeLookup,'no repeated global lookups on animation frames')
assert(systemChecks-beforeSystemChecks<=3,'validate the native trace helper per batch, not per sample')
pump(6.016,math.floor((M.duration-0.05)/0.016)-1)
assert(created==1 and sections==2 and imports==1 and component.visible==false,table.concat(errors,';'))
assert(#errors==0,table.concat(errors,';'))
local riseStart=6+M.duration
frame(riseStart)
assert(component.visible,'contour starts only after bounce')
near(actor.AreaRange.RelativeScale3D.X,98)
near(actor.AreaRange1.RelativeScale3D.X,98.01)
near(actor.AreaRange.RelativeScale3D.Z,100)
local g=component.geometry[1]
local n=#g.vertices/2-1
assert(n==104 and #g.indices==n*6,'full circle including seam')
near(g.vertices[1].X,g.vertices[#g.vertices-1].X)
near(g.vertices[1].Z,g.vertices[#g.vertices-1].Z)
local low,high=math.huge,-math.huge
for i=1,#g.vertices,2 do
    local p=g.vertices[i]
    near(p.Z,height(p.X+100,p.Y+200)-300+12+12)
    low,high=math.min(low,p.Z),math.max(high,p.Z)
end
assert(high-low>500,'line must retain terrain relief')
local tail=component.geometry[2]
near(tail.vertices[1].Z,g.vertices[2].Z)
near(tail.vertices[2].Z,tail.vertices[1].Z-240)
near(tail.uv[1].Y,g.uv[2].Y)
assert(tail.uv[2].Y>0.99 and tail.uv[1].Y<0.07,'one continuous texture span')
for _,mid in ipairs(component.materials) do
    assert(mid.Texture01==objects['/Transient.Gradient1'])
    near(mid.DistortionScale,0);near(mid.TilingV_01,1);near(mid.ScrollingV_01,0)
    near(mid.RGBScale02,0);near(mid.AlphaScale02,0)
end
beforeLookup=lookups
local beforeRiseTraces,beforeRiseSections=traces,sections
near(component.scale.Z,1)
frame(riseStart+1)
local crest=high-12
near(component.position.Z,300+600*(1-(1-1/2.8)^3)+(1-component.scale.Z)*crest)
assert(component.scale.Z>0.35 and component.scale.Z<1,'relief straightens progressively')
assert(lookups==beforeLookup,'rising mesh and materials stay cached')
frame(riseStart+1.55)
near(component.scale.Z,0.35)
assert(component.position.Z<900+0.65*crest,'flash occurs while still rising')
assert(component.materials[1].RGBScale01>4.9,'earlier emissive flash')
assert(component.materials[2].AlphaScale01>0 and component.materials[2].RGBScale01>0,
    'soft trail remains through the flash')
frame(riseStart+2.79);assert(component.materials[1].AlphaScale01<0.01,'smooth fade before cleanup')
near(component.materials[2].AlphaScale01/component.materials[1].AlphaScale01,0.6*0.95)
assert(component.materials[2].RGBScale01>0,'trail persists until shared fade finishes')
assert(component.position.Z<900+0.65*crest,'no stationary visible hold')
assert(traces==beforeRiseTraces and sections==beforeRiseSections,
    'straightening must not add terrain scans or mesh rebuilds')
frame(riseStart+2.81);assert(destroyed==1 and #queue==0)
near(radius,4900)
upgrade();pump(time,40)
assert(created==2)
clear();frame(time+0.016)
assert(destroyed==2 and #queue==0,'base removal destroys unfinished contour')
refresh();failMesh=true;upgrade();pump(time,110)
assert(destroyed==3 and #queue==0,'native geometry failure cleaned, bounce still finishes')
near(actor.AreaRange.RelativeScale3D.X,98)
failMesh=false;dedicated=true;time=time+1;level=10;radius=5075;refresh()
assert(created==3 and #queue==0,'dedicated server never constructs effects')
near(actor.AreaRange.RelativeScale3D.X,101.5)
dedicated=false;refresh()
upgrade()
actor.GetFullName=function() return 'Mock /World.ReusedAddressOtherObject' end
frame(time+0.016);assert(#queue==0,'cached address reuse rejected')
local R=dofile(root..'src/ribbon.lua')(E,{})
-- A steep, asymmetric contour stays grounded at launch, then rises and
-- retains some relief. Use the crest, not a mean that can sink high points.
for _,heights in ipairs({{-500,-100,200,900},{-900,-600,-300,-50},{20,20,20,20}}) do
    local job={center={X=100,Y=200,Z=300},crest=math.max(table.unpack(heights))}
    local previous={table.unpack(heights)}
    for frame=0,280 do
        local elapsed=frame/100
        local pose=R.pose(job,elapsed,R.envelope(elapsed,600))
        near(pose.Scale3D.X,1);near(pose.Scale3D.Y,1)
        near(pose.Translation.X,100);near(pose.Translation.Y,200)
        for i,z in ipairs(heights) do
            local world=pose.Translation.Z+pose.Scale3D.Z*z
            if frame==0 then near(world,300+z) end
            assert(world>=300+z and world>=previous[i]-0.00001,'no point sinks or reverses its ascent')
            previous[i]=world
        end
        if elapsed>=1.4 then near(pose.Scale3D.Z,0.35) end
    end
    local first=R.pose(job,0,0)
    near(first.Scale3D.Z,1)
end
-- The configured rise height is kept within 100..2000 cm; anything else means 600.
for _,case in ipairs({{50,100},{5000,2000},{750,750},{'tall',600},{0/0,600}}) do
    E.config.upgradeEffectHeight=case[1]
    local prepared={radius=4900};R.prepare(prepared,actor)
    near(prepared.ribbon.height,case[2])
    assert(prepared.ribbon.count==104 and prepared.ribbon.nextLayer==0 and prepared.ribbon.radius==4900)
end
E.config.upgradeEffectHeight=nil
local _,quickAlpha=R.envelope(0.06,600)
near(quickAlpha,1)
local job={count=4,radius=100,points={{Z=1},{Z=2},false,{Z=4}}}
local _,indices=R.geometry(job,0)
assert(#indices==12,'missing terrain must not be bridged by a fake flat segment')
local rise,alpha,trail,light=R.envelope(R.duration,800)
near(rise,800);near(alpha,0);near(trail,0);near(light,0)
local lastDistance=math.huge
for i=1,28 do
    local a=R.envelope((i-1)*0.1,800)
    local b,visible,trail,light=R.envelope(i*0.1,800)
    assert(b-a<=lastDistance+0.00001,'rise speed must steadily decrease')
    if visible>0.00001 then assert(b>a and b<800,'still moving whenever visible') end
    if visible>0 then assert(trail>0,'no bare-line phase') end
    lastDistance=b-a
end
for _,t in ipairs({1.25,1.3,1.55,1.65,2.0,2.6}) do
    local _,head,trail=R.envelope(t,800);near(trail,head*0.6)
end
local _,headMid,_,lightMid=R.envelope(2.2,800)
near(headMid,0.5);near(lightMid,0.5)
print('PASS: terrain contour/seam, continuous gradient, early flash, shared moving fade, bounded setup, cached animation, cleanup, authority')

-- Ground wave must finish before the shorter bounce and rising contour.
clear()
actor.GetFullName=function() return 'Mock /World.Palbox' end
E.config.upgradeWave=true
local events={}
E.log=function(message)
    if message:find('Palbox wave started',1,true) then events.wave=time end
    if message:find('wave reached boundary',1,true) then events.arrived=time end
    if message:find('contour rise started',1,true) then events.rise=time end
end
errors={};level=9;radius=4900;time=time+1
B=dofile(root..'src/boundary.lua')(E,M);refresh();upgrade()
local preparedAt,firstTraceStart=time,traces
while not events.wave and time<preparedAt+15 do
    frame(time+0.016)
    near(actor.AreaRange.RelativeScale3D.X,94.5)
end
assert(events.wave and not events.arrived and not events.rise,table.concat(errors,';'))
local firstScanSamples=traces-firstTraceStart
assert(component.sectionVisible[0]==false and component.sectionVisible[1]==false and component.sectionVisible[2])
local surface=component.geometry[3]
local outermost=0
for _,p in ipairs(surface.vertices) do
    near(p.Z,height(p.X+100,p.Y+200)-300+12)
    outermost=math.max(outermost,math.sqrt(p.X*p.X+p.Y*p.Y))
end
near(outermost,4725) -- meet the old, visible circle; the bounce then expands it
local fixedTraces,fixedSections,fixedLookups=traces,sections,lookups
while not events.arrived and time<events.wave+3 do
    frame(time+0.016)
    near(actor.AreaRange.RelativeScale3D.X,94.5)
    assert(traces==fixedTraces and sections==fixedSections and lookups==fixedLookups,
        'visible wave only changes material values: no traces, mesh rebuilds or global searches')
end
assert(events.arrived and not events.rise)
near(component.materials[3].OffsetV_01,0.45)
frame(events.arrived+0.4)
assert(not component.sectionVisible[2],'ground trail fades during the bounce, before the rise')
assert(actor.AreaRange.RelativeScale3D.X>94.5)
frame(events.arrived+M.duration-0.01)
assert(not events.rise,'rise must still wait for the bounce to settle')
frame(events.arrived+M.duration+0.01)
assert(events.rise and events.rise>=events.arrived+M.duration)
assert(component.sectionVisible[0] and component.sectionVisible[1] and not component.sectionVisible[2])
near(actor.AreaRange.RelativeScale3D.X,98)
frame(events.rise+R.duration+0.01)
assert(not component.alive and #queue==0 and #errors==0,table.concat(errors,';'))

-- A repeat must sample the current surface again, even at the same
-- location and radius. Engine-object tracking remains, but terrain does not.
local repeatTraceStart=traces
terrainOffset=50
clear()
B=dofile(root..'src/boundary.lua')(E,M);refresh()
events={};local replayAt=time;upgrade()
while not events.wave and time-replayAt<15 do frame(time+0.016) end
assert(events.wave and traces-repeatTraceStart==firstScanSamples,'repeat uses a complete fresh scan')
for _,p in ipairs(component.geometry[3].vertices) do
    near(p.Z,height(p.X+100,p.Y+200)-300+12)
end
frame(events.wave+W.duration-0.01);assert(not events.arrived,'wave must not trigger the bounce early')
frame(events.wave+W.duration+0.01);assert(events.arrived)
clear();frame(time+0.016)

-- A failed wave setup releases the waiting bounce rather than leaving a small ring.
refresh()
local beforeDestroyed=destroyed
failMesh=true;upgrade();pump(time,800)
assert(#queue==0 and destroyed==beforeDestroyed+1)
near(actor.AreaRange.RelativeScale3D.X,98)
failMesh=false
upgrade();pump(time,3);clear();frame(time+0.016)
assert(#queue==0,'base removal cancels terrain preparation')
near(actor.AreaRange.RelativeScale3D.X,98)
dedicated=true;time=time+1;level=10;radius=5075
local noServerEffects=created
refresh();upgrade();assert(created==noServerEffects and #queue==0)
near(actor.AreaRange.RelativeScale3D.X,101.5)
print('PASS: Palbox wave -> bounce -> rise, terrain surface, bounded setup, no moving mesh/scans, failure and removal cleanup')

-- With the glow effects off there is no wave or contour to prepare, but the
-- boundary bounce still runs.
dedicated=false;E.config.upgradeRibbon=false;errors={};events={}
clear();time=time+1
B=dofile(root..'src/boundary.lua')(E,M);refresh()
local plainCreated,plainSections,plainTraces=created,sections,traces
local lowest,highest=math.huge,-math.huge
upgrade()
for _=1,math.floor(M.duration/0.016)+30 do
    frame(time+0.016)
    local x=actor.AreaRange.RelativeScale3D.X
    lowest,highest=math.min(lowest,x),math.max(highest,x)
end
assert(lowest<101.5-0.1 and highest>101.5+0.1,'the boundary still bounces past its new radius without the glow effects')
assert(created==plainCreated and sections==plainSections and traces==plainTraces,'no wave or contour is prepared')
assert(not events.wave and not events.rise and #queue==0 and #errors==0,table.concat(errors,';'))
near(actor.AreaRange.RelativeScale3D.X,101.5)
E.config.upgradeRibbon=nil
print('PASS: without the glow effects the bounce still runs and no wave or contour is prepared')

-- Menu readiness and elapsed idle time must no longer cause terrain work.
dedicated=false;level=9;radius=4900;time=time+1;events={};errors={}
local menuReads=0
E.objects={all=function() menuReads=menuReads+1;return {} end}
E.runtime={snapshot=function() error('presentation must not request speculative ranges') end}
local idleTraces,idleCreated=traces,created
for _=1,8 do time=time+5;refresh();frame(time+0.016) end
assert(#queue==0 and traces==idleTraces and created==idleCreated and menuReads==0,'no idle/menu preloading')
assert(not events.wave and not events.rise and E.boundaryTerrain==nil)
level=10;radius=5075;refresh()
local upgradeAt=time
while not events.wave and time-upgradeAt<15 do frame(time+0.016) end
assert(events.wave and traces>idleTraces,'a real upgrade also samples fresh terrain on demand')
near(actor.AreaRange.RelativeScale3D.X,98)
clear();frame(time+0.016)
assert(#queue==0 and #errors==0,table.concat(errors,';'))
print('PASS: fresh terrain on repeat and real upgrade, changed surfaces, no retained heights or menu/idle preloading')

-- Prepare only after a trigger, but keep every visual hidden until the native
-- Base Upgrade screen for THIS base deactivates. No viewport-root assumption.
local screenActive=true
local screen=obj('/World.BaseUpgrade',{
    IsActivated=function() return screenActive end,
    GetBaseCampModel=function() return base end,
})
E.objects={all=function(name)
    assert(name=='WBP_IngameMenu_Mission_C');menuReads=menuReads+1;return {screen}
end}
local originalVisible=actor.AreaRange.IsVisible
actor.AreaRange.IsVisible=function() return false end
refresh();events={};local beforeMenus=menuReads;upgrade();local triggeredAt=time
pump(triggeredAt,200)
assert(not events.wave and component.alive and not component.visible,'menu holds the prepared effect hidden')
assert(menuReads==beforeMenus+1,'widgets discovered once, never scanned each frame')
near(actor.AreaRange.RelativeScale3D.X,98)
local preparedTraces=traces
pump(time,10);assert(traces==preparedTraces,'ready effect does no more terrain work while the screen stays open')
screenActive=false;frame(time+0.016)
assert(events.wave==time,'closing a prepared menu starts the wave in that update, without a fixed delay')
local readsAfterClose=menuReads
frame(time+0.016);assert(menuReads==readsAfterClose,'closed screen is no longer polled')
assert(traces==preparedTraces and #errors==0,table.concat(errors,';'))
clear();frame(time+0.016)

-- Closing before setup is finished releases the UI gate but still requires
-- complete terrain/meshes. Destroyed screens also release the gate safely.
actor.AreaRange.IsVisible=originalVisible
refresh();events={};screenActive=true;upgrade();triggeredAt=time
frame(time+0.016);screenActive=false;frame(time+0.016)
assert(not events.wave,'an early close must not display incomplete terrain')
while not events.wave and time-triggeredAt<10 do frame(time+0.016) end
assert(events.wave and time-triggeredAt<1,'no one-second timer is imposed')
clear();frame(time+0.016)
refresh();events={};screenActive=true;upgrade();pump(time,200)
assert(not events.wave)
screen.alive=false;frame(time+0.016)
assert(events.wave==time,'destroying the widget cannot strand the animation')
clear();frame(time+0.016)
assert(#queue==0 and #errors==0,table.concat(errors,';'))
print('PASS: native Base Upgrade close gate, hidden preparation, immediate ready release, early close, destroyed widget and reference cleanup')

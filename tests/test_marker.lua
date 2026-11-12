local root=assert(arg[1],'pass root with trailing slash')
local Motion=dofile(root..'src/motion.lua')
local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a)..' != '..tostring(b)) end

-- A terrain-following maximum with no next-level wall.
local objects,queue,errors,logs={},{},{},{}
local time,lookups,traces,created,destroyed,sections,imports,writes=0,0,0,0,0,0,0,0
local failMesh,noGround=false,false
local function obj(p,t)
    t=t or {};t.alive=true
    t.IsValid=function(self) return self.alive end
    t.GetFullName=function() return 'Mock '..p end
    objects[p]=t;return t
end
StaticFindObject=function(p) lookups=lookups+1;return objects[p] end
FName=function(s) return s end
ExecuteInGameThreadWithDelay=function(delay,fn) assert(delay==16);queue[#queue+1]=fn end
ExecuteWithDelay=function() error('The marker must never schedule asynchronous Lua') end
LoadAsset=function(p) obj(p) end
local function height(x,y) return 100+x*0.1+y*0.05 end
obj('/Script/Engine.Default__KismetSystemLibrary',{
    GetGameTimeInSeconds=function() return time end,
    LineTraceSingleForObjects=function(_,actor,start,finish,types,complex,ignore,draw,out)
        traces=traces+1
        if noGround then return false end
        out.OutHit={ImpactPoint={X=start.X,Y=start.Y,Z=height(start.X,start.Y)}}
        return true
    end,
})
obj('/Script/Pal.Default__PalUtility',{IsDedicatedServer=function() return false end})
obj('/Script/ProceduralMeshComponent.ProceduralMeshComponent')
obj('/Script/Engine.Default__KismetRenderingLibrary',{
    ImportFileAsTexture2D=function(_,_,path)
        assert(path==root..'assets/contour-gradient.png','the marker reuses the contour gradient')
        imports=imports+1;return obj('/Transient.Gradient'..imports)
    end,
})
local function ring(p,z)
    return obj(p,{RelativeScale3D={X=70,Y=70,Z=z},
        SetRelativeScale3D=function(self,v) self.RelativeScale3D=v end,
        K2_GetComponentLocation=function() return {X=100,Y=200,Z=300} end})
end
local component
local function palbox(p)
  local actor
  actor=obj(p,{
    AreaRange=ring(p..'.AreaRange',100),
    AreaRange1=ring(p..'.AreaRange1',100.01),
    AddComponentByClass=function()
        created=created+1
        local id=created
        component=obj('/World.Marker'..id,{
            geometry={},materials={},
            SetVisibility=function(self,v) self.visible=v end,
            SetHiddenInGame=function() end,
            SetCollisionEnabled=function(_,v) assert(v==0) end,
            SetGenerateOverlapEvents=function(_,v) assert(not v) end,
            SetIsReplicated=function(_,v) assert(not v) end,
            SetCastShadow=function(_,v) assert(not v) end,
            K2_SetWorldTransform=function(self,v) self.position=v.Translation end,
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
            end,
            CreateDynamicMaterialInstance=function(self,layer)
                local mid=obj('/World.Marker'..id..'.Material'..layer,{
                    SetTextureParameterValue=function(self,k,v) self[k]=v end,
                    SetVectorParameterValue=function(self,k,v) self[k]=v end,
                    SetScalarParameterValue=function(self,k,v) writes=writes+1;self[k]=v end,
                })
                self.materials[layer+1]=mid;return mid
            end,
        })
        return component
    end,
  })
  return actor
end
local actor=palbox('/World.Palbox')
local E={root=root,config={},valid=function(o) return o and o:IsValid() end,
    log=function(message) logs[#logs+1]=message end,
    guard=function(label,fn)
        local ok,result=pcall(fn)
        if not ok then errors[#errors+1]=label..':'..tostring(result) end
        return ok,result
    end}
local menuReads=0
E.objects={find=function(p) return StaticFindObject(p) end,all=function() menuReads=menuReads+1;return {} end}
E.runtime={snapshot=function() error('the marker is told its radius; it never calculates one') end}
local B=dofile(root..'src/boundary.lua')(E,Motion)
local M=dofile(root..'src/marker.lua')(E,{},{})
assert(M.level(0)==0)
near(M.level(M.fadeIn),1);near(M.level(50),1)
near(M.level(5,M.fadeOut/2),0.5)
assert(M.level(5,M.fadeOut)==nil)

local level,radius=8,4725
local base=obj('/World.BaseModel',{GetLevel=function() return level end})
local other=obj('/World.OtherBase',{GetLevel=function() return 3 end})
local screenActive=true
local screen=obj('/World.BaseUpgrade',{IsActivated=function() return screenActive end})
local function refresh() B.beginRefresh();B.update(actor,base,'base',radius);B.endRefresh() end
local function frame(t)
    time=t;local batch=queue;queue={}
    local beforeTrace,beforeSections=traces,sections
    for _,fn in ipairs(batch) do fn() end
    assert(traces-beforeTrace<=64,'all bases share 64 terrain traces per update')
    assert(sections-beforeSections<=1,'at most one mesh section per update')
end
local function pump(frames) for _=1,frames do frame(time+0.016) end end
local function aim(maximum) B.mark(base,screen,4900,maximum) end
local function reset()
    B.beginRefresh();B.endRefresh();pump(1);refresh()
    assert(#queue==0)
end
refresh();near(actor.AreaRange.RelativeScale3D.X,94.5)
E.config.nextBoundaryMarker=true -- obsolete installed configs cannot bring back the blue wall
B.mark(base,screen,4900)
B.mark(other,screen,4900,7000)
aim(false)
assert(#queue==0 and created==0,'no maximum or another base: draw nothing, including the next blue ring')
aim(7000)
assert(#queue==1 and created==0 and traces==0,'aim only schedules')
frame(time+0.016);assert(traces==64 and created==0)
pump(9);assert(traces==640 and created==0)
frame(time+0.016);assert(traces==660 and created==0)
frame(time+0.016);assert(created==1 and sections==1 and imports==1 and not component.visible)
near(component.materials[1].AlphaScale01,0)
frame(time+0.016)
assert(component.visible and logs[1]=='maximum boundary marker shown at 7000 cm: 660/660 terrain samples')
local shownAt=time
local g=component.geometry[1]
assert(#g.vertices==660 and #g.indices==1320,'110 separate dashes, two ground quads each')
near(component.position.X,100);near(component.position.Y,200);near(component.position.Z,300)
for i,p in ipairs(g.vertices) do
    near(math.sqrt(p.X*p.X+p.Y*p.Y),7000+(i%2==1 and -20 or 20))
    near(p.Z,height(p.X+100,p.Y+200)-300+2) -- every vertex is 2 cm above its own terrain hit
    near(g.uv[i].Y,0.5/512)
end
for i=1,#g.indices,3 do
    local a,b,c=g.indices[i],g.indices[i+1],g.indices[i+2]
    assert(math.floor(a/6)==math.floor(b/6) and math.floor(a/6)==math.floor(c/6),'no triangle crosses a gap')
    local pa,pb,pc=g.vertices[a+1],g.vertices[b+1],g.vertices[c+1]
    assert((pb.X-pa.X)*(pc.Y-pa.Y)-(pb.Y-pa.Y)*(pc.X-pa.X)>0,'ground faces upwards')
end
near(component.materials[1].SoftEdge,1)
near(component.materials[1].Color01.B,1.4)
near(actor.AreaRange.RelativeScale3D.X,94.5)
frame(shownAt+M.fadeIn)
local steadyTraces,steadySections,steadyLookups,steadyReads,steadyWrites=traces,sections,lookups,menuReads,writes
for i=1,300 do
    frame(time+0.016)
    if i%60==0 then refresh();aim(7000) end
end
near(component.materials[1].AlphaScale01,0.45)
assert(traces==steadyTraces and sections==steadySections and lookups==steadyLookups and writes==steadyWrites,
    'steady maximum has no terrain, mesh, lookup or material writes')
assert(menuReads==steadyReads and created==1 and #errors==0)
screenActive=false;frame(time+0.016)
local closedAt=time
assert(component.alive and component.visible)
frame(closedAt+M.fadeOut/2);near(component.materials[1].AlphaScale01,M.alpha/2)
frame(closedAt+M.fadeOut+0.001)
assert(not component.alive and destroyed==1 and #queue==0)
print('PASS: flat sloped-ground dashes with real gaps, no next wall, bounded setup, no steady writes, fade on close')

screenActive=true;aim(7000);pump(40)
assert(created==2 and traces==steadyTraces+660 and component.visible,'reopening samples fresh terrain')
local first=component
aim(7200);assert(not first.alive)
pump(40);assert(created==3 and component.visible)
near(math.sqrt(component.geometry[1].vertices[1].X^2+component.geometry[1].vertices[1].Y^2),7180)
aim(false);pump(20);assert(not component.alive and #queue==0)
local beforeEarly=created
aim(7000);pump(1);aim(false);pump(1)
assert(created==beforeEarly and #queue==0,'cancel during sampling creates nothing')
aim(7000);pump(12);assert(not component.visible and component.alive)
screenActive=false;pump(1);assert(not component.alive and #queue==0,'close before showing creates no flash')
screenActive=true;aim(7000);pump(40)
screen.alive=false;pump(20);assert(not component.alive and #queue==0)
screen.alive=true;aim(7000);pump(40)
local fading=component
screenActive=false;pump(1);screenActive=true;aim(7000)
assert(not fading.alive,'reopen removes the fading instance')
pump(40);assert(component.visible)
radius=3500;refresh();assert(not component.alive,'a snapped radius clears the marker')
pump(1);radius=4725;reset()
aim(7000);pump(40);frame(time-30)
assert(not component.alive and #queue==0,'reset clock removes the marker')
time=time+60;reset()
aim(7000);pump(40);aim(false);aim(7000);pump(40)
assert(component.alive and component.visible,'re-aim before dismissal stays visible')
component.alive=false
local beforeLoss=created;pump(3)
assert(created==beforeLoss and #queue==0,'lost component is not rebuilt automatically')
E.config.maximumBoundaryMarker=false;aim(7000);assert(#queue==0)
E.config.maximumBoundaryMarker=nil;E.config.resetToVanilla=true;aim(7000);assert(#queue==0)
E.config.resetToVanilla=nil
aim(radius);assert(#queue==0,'already at maximum: no duplicate current boundary')
B.mark(base,screen,7000,7000);pump(40)
assert(component.visible,'maximum stays visible when next equals maximum')
reset();assert(not component.alive)
aim(7000);pump(40);actor.alive=false;pump(1)
assert(#queue==0,'removed Palbox stops updates')
actor.alive=true;reset();assert(#errors==0,table.concat(errors,';'))
print('PASS: reopening, radius changes, early close, destroyed screen/component, settings, current cap and clock reset')

local second=palbox('/World.Palbox2')
local secondBase=obj('/World.SecondBase',{GetLevel=function() return 5 end})
local secondScreen=obj('/World.BaseUpgrade2',{IsActivated=function() return true end})
B.beginRefresh();B.update(actor,base,'base',radius);B.update(second,secondBase,'second',4200);B.endRefresh()
local beforeShared,sharedCreated=traces,created
aim(7000);B.mark(secondBase,secondScreen,4375,7000)
frame(time+0.016);assert(traces-beforeShared==64)
pump(60)
assert(traces-beforeShared==1320 and created==sharedCreated+2,'two bases share the budget')
reset()
E.config.upgradeWave=false
local beforeUpgrade=created
aim(7000);pump(40);local marker=component
level=9;radius=4900;time=time+0.016;refresh()
assert(marker.alive,'upgrade fades the marker')
pump(20);assert(not marker.alive)
for _=1,12 do pump(10);aim(7000) end
assert(created==beforeUpgrade+2 and #component.geometry==2,'only celebration runs during upgrade')
reset();aim(7000);pump(40);assert(component.visible)
reset()
print('PASS: shared setup budget and preserved upgrade celebration')

local beforeFail,beforeDestroyed=created,destroyed
failMesh=true;aim(7000);pump(40)
assert(created==beforeFail+1 and destroyed==beforeDestroyed+1 and #queue==0)
assert(#errors==1 and errors[1]:find('maximum boundary marker',1,true),table.concat(errors,';'))
local afterFail=traces
aim(7000);pump(40);assert(traces==afterFail and #queue==0,'failed radius is not retried each refresh')
failMesh=false;aim(7200);pump(40);assert(component.visible)
reset();errors={};noGround=true
local beforeNoGround=created
aim(7000);pump(40)
assert(created==beforeNoGround and #queue==0 and #errors==1 and errors[1]:find('No terrain under the maximum boundary',1,true))
noGround=false
print('PASS: failed setup cleans up once; missing terrain draws nothing')

-- Geometry cannot bridge a void or a cliff, including across the strip width.
local D=dofile(root..'src/dashes.lua')
local job={radius=7000,points={}}
D.prepare(job)
for i,p in ipairs(job.samplePoints) do job.points[i]={Z=height(p.X,p.Y)+2} end
local _,good=D.geometry(job)
job.points[1]=false
local _,gap=D.geometry(job)
assert(#gap==#good-3,'only the triangle with the missing corner is omitted')
job.points[1]={Z=10000}
local _,cliff=D.geometry(job)
assert(#cliff==#gap,'a large ground discontinuity cannot turn into a wall')
local maxJob={radius=14000};D.prepare(maxJob)
assert(maxJob.count<=1152,'setup size bounded even at maximum configured range')
print('PASS: terrain holes and cliffs leave gaps; maximum geometry is bounded')

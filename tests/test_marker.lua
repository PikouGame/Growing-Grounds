local root=assert(arg[1],'pass root with trailing slash')
local Motion=dofile(root..'src/motion.lua')
local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a)..' != '..tostring(b)) end

-- Brightness: in from nothing, a slow breath, out to nothing.
local objects,queue,errors,logs={},{},{},{}
local time,lookups,traces,created,destroyed,sections,imports=0,0,0,0,0,0,0
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
                    SetScalarParameterValue=function(self,k,v) self[k]=v end,
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
assert(M.level(0)==0,'starts from nothing')
near(M.level(M.fadeIn),0.875+0.125*math.cos(2*math.pi*M.fadeIn/M.period))
near(M.level(M.period),1);near(M.level(M.period/2),0.75)
local previous=0
for i=0,math.floor(M.fadeIn*100) do
    local level=M.level(i/100)
    assert(level>=previous-0.02,'no flash on the way in');previous=level
end
for i=0,1000 do
    local level=M.level(M.fadeIn+i/100)
    assert(level>=0.75-0.00001 and level<=1.00001,'the breath stays between three quarters and full')
end
previous=M.level(5,0)
near(previous,M.level(5))
for i=1,math.floor(M.fadeOut*1000)-1 do
    local level=M.level(5+i/1000,i/1000)
    assert(level<=previous+0.001 and level>=0,'fades out without a rebound');previous=level
end
assert(previous<0.01 and M.level(5,M.fadeOut)==nil and M.level(5,M.fadeOut+1)==nil,'ends at nothing, then is gone')
assert(M.height>=100 and M.alpha>0 and M.alpha<=1 and M.light>0 and M.light<5,
    'fainter than the celebration, whose trail glows at 5')
print('PASS: marker brightness fades in, breathes between 0.75 and 1, fades out to nothing')

-- A marker at the NEXT radius, prepared in bounded batches, shown only while
-- its Base Upgrade screen is open.
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
    assert(traces-beforeTrace<=64,'terrain work must stay bounded per update')
    assert(sections-beforeSections<=1,'at most one mesh section per update')
end
local function pump(frames) for _=1,frames do frame(time+0.016) end end
local function shown() return #logs>0 and logs[#logs]:find('next boundary marker shown',1,true)~=nil end
refresh();near(actor.AreaRange.RelativeScale3D.X,94.5)
B.mark(other,screen,4900)
assert(#queue==0 and created==0,'a screen for another base marks nothing here')
B.mark(base,screen,false)
assert(#queue==0 and created==0,'nothing to announce, nothing prepared')
B.mark(base,screen,4900)
assert(#queue==1 and created==0 and traces==0,'aiming only schedules; the work is spread over updates')
frame(time+0.016);assert(traces==64 and created==0)
frame(time+0.016);assert(traces==104 and created==0,'one sample every three metres of the NEXT circle')
frame(time+0.016);assert(created==1 and sections==1 and imports==1 and not component.visible)
near(component.materials[1].AlphaScale01,0)
logs={};frame(time+0.016)
assert(component.visible and shown(),'visible once complete')
assert(logs[1]=='next boundary marker shown at 4900 cm: 104/104 terrain samples')
local shownAt=time
near(component.materials[1].AlphaScale01,0);near(component.materials[1].RGBScale01,0)
near(component.position.X,100);near(component.position.Y,200);near(component.position.Z,300)
assert(#component.geometry==1 and #component.materials==1,'one mesh section, one material')
local g=component.geometry[1]
local n=#g.vertices/2-1
assert(n==104 and #g.indices==n*6,'full circle including seam')
for i=1,#g.vertices,2 do
    local top,bottom=g.vertices[i],g.vertices[i+1]
    near(math.sqrt(bottom.X*bottom.X+bottom.Y*bottom.Y),4900)
    near(bottom.Z,height(bottom.X+100,bottom.Y+200)-300+12)
    near(top.X,bottom.X);near(top.Y,bottom.Y);near(top.Z,bottom.Z+M.height)
    assert(g.uv[i].Y>0.99 and g.uv[i+1].Y<0.01,'brightest on the ground, fading upwards')
end
near(actor.AreaRange.RelativeScale3D.X,94.5) -- the real boundary is never moved by the marker
local steadyTraces,steadySections,steadyLookups,steadyReads=traces,sections,lookups,menuReads
frame(shownAt+M.fadeIn)
near(component.materials[1].AlphaScale01,M.alpha*M.level(M.fadeIn))
near(component.materials[1].RGBScale01,M.light*M.level(M.fadeIn))
for i=1,300 do
    frame(time+0.016)
    local mid=component.materials[1]
    assert(mid.AlphaScale01>=M.alpha*0.75-0.00001 and mid.AlphaScale01<=M.alpha+0.00001)
    assert(mid.RGBScale01<=M.light+0.00001)
    if i%60==0 then refresh();B.mark(base,screen,4900) end -- the 5 s reconciliation while it is open
end
assert(traces==steadyTraces and sections==steadySections and lookups==steadyLookups and created==1,
    'a steady marker only changes two material values: no traces, meshes, searches or rebuilds')
assert(menuReads==steadyReads,'the boundary never reads menus for the marker')
assert(#errors==0,table.concat(errors,';'))
-- Closing the screen fades it out and stops every update.
screenActive=false;frame(time+0.016)
local closedAt=time
assert(component.alive and component.visible,'the close starts a fade, not a cut')
frame(closedAt+M.fadeOut/2)
assert(component.materials[1].AlphaScale01<M.alpha*0.75 and component.materials[1].AlphaScale01>0)
frame(closedAt+M.fadeOut-0.001);assert(component.alive)
frame(closedAt+M.fadeOut+0.001)
assert(destroyed==1 and not component.alive and #queue==0,'gone after the fade; nothing keeps ticking')
pump(5);assert(#queue==0 and traces==steadyTraces)
print('PASS: next-radius marker on the terrain, bounded setup, steady without work, fades with its screen')

-- The same radius reopened samples fresh terrain; another radius replaces it.
screenActive=true
B.mark(base,screen,4900);pump(4)
assert(created==2 and traces==steadyTraces+104 and component.visible,'reopening scans the current ground again')
pump(30)
local first=component
B.mark(base,screen,5075);assert(destroyed==2 and not first.alive,'a new next radius replaces the marker')
pump(4)
assert(created==3 and component.visible)
near(math.sqrt(component.geometry[1].vertices[2].X^2+component.geometry[1].vertices[2].Y^2),5075)
-- Nothing left to announce: fades out although the screen stays open.
pump(30);B.mark(base,screen,false)
frame(time+0.016);local dismissedAt=time
assert(component.alive);frame(dismissedAt+M.fadeOut+0.001)
assert(destroyed==3 and #queue==0)
-- Dismissed or closed before anything was visible: no flash at all.
B.mark(base,screen,4900);frame(time+0.016)
B.mark(base,screen,false);frame(time+0.016)
assert(created==3 and #queue==0,'dismissed during sampling: nothing was ever created')
B.mark(base,screen,4900);pump(3);assert(created==4 and not component.visible)
screenActive=false;frame(time+0.016)
assert(destroyed==4 and #queue==0,'closed before it showed: removed without appearing')
screenActive=true
-- A destroyed screen cannot strand the marker.
B.mark(base,screen,4900);pump(40);assert(component.visible)
screen.alive=false;frame(time+0.016);frame(time+M.fadeOut+0.001)
assert(destroyed==5 and #queue==0,'a destroyed widget counts as closed')
screen.alive=true
-- Reopened while fading: a fresh marker, never a half-faded one brought back.
B.mark(base,screen,4900);pump(40);local fading=component
screenActive=false;frame(time+0.016);screenActive=true
assert(fading.alive)
B.mark(base,screen,4900)
assert(not fading.alive and destroyed==6,'the fading marker is removed at once')
pump(4);assert(component~=fading and component.visible)
-- A boundary that snaps (reset, reload) drops the marker with the old state.
radius=3500;refresh()
assert(not component.alive and destroyed==7,'a snapped boundary keeps no marker')
frame(time+0.016);assert(#queue==0)
radius=4725;B.beginRefresh();B.endRefresh();refresh()
-- A world clock that restarts removes it rather than freezing it.
B.mark(base,screen,4900);pump(40);assert(component.visible)
frame(time-30)
assert(not component.alive and destroyed==8 and #queue==0,'a clock set back removes the marker')
time=time+60;B.beginRefresh();B.endRefresh();refresh()
-- Dismissed and wanted again before it faded: it must not fade away anyway.
B.mark(base,screen,4900);pump(40)
B.mark(base,screen,false);B.mark(base,screen,4900);pump(40)
assert(component.alive and component.visible,'a marker asked for again stays')
near(component.materials[1].AlphaScale01,M.alpha*M.level(36*0.016)) -- shown on the 4th of 40 updates
B.mark(base,screen,false);pump(20);assert(not component.alive and #queue==0)
-- A component destroyed under it ends the marker; it is not rebuilt each update.
B.mark(base,screen,4900);pump(40)
local beforeLoss=created
component.alive=false;pump(3)
assert(created==beforeLoss and #queue==0,'a lost component is not rebuilt on the spot')
-- Switches.
local beforeSwitches=created
E.config.nextBoundaryMarker=false;B.mark(base,screen,4900)
assert(#queue==0 and created==beforeSwitches,'nextBoundaryMarker=false prepares nothing')
E.config.nextBoundaryMarker=nil;E.config.resetToVanilla=true;B.mark(base,screen,4900)
assert(#queue==0 and created==beforeSwitches,'no marker during a reset')
E.config.resetToVanilla=nil
-- Removal of the base or of its Palbox.
B.mark(base,screen,4900);pump(40);assert(component.visible)
local beforeRemoval=destroyed
B.beginRefresh();B.endRefresh()
assert(destroyed==beforeRemoval+1,'base removal destroys its marker')
frame(time+0.016);assert(#queue==0)
refresh();B.mark(base,screen,4900);pump(40);assert(component.visible)
actor.alive=false;frame(time+0.016);assert(#queue==0,'a removed Palbox stops the updates')
component.alive=false -- a component dies with its actor
actor.alive=true;B.beginRefresh();B.endRefresh();refresh()
assert(#errors==0,table.concat(errors,';'))
-- Two bases marked together share the per-update terrain budget (checked in frame()).
local second=palbox('/World.Palbox2')
local secondBase=obj('/World.SecondBase',{GetLevel=function() return 5 end})
local secondScreen=obj('/World.BaseUpgrade2',{IsActivated=function() return screenActive end})
B.beginRefresh();B.update(actor,base,'base',radius);B.update(second,secondBase,'second',4200);B.endRefresh()
local beforeShared,sharedCreated=traces,created
B.mark(base,screen,4900);B.mark(secondBase,secondScreen,4375)
frame(time+0.016);assert(traces-beforeShared==64,'one shared budget, not one each')
pump(8)
assert(traces-beforeShared==104+96 and created==sharedCreated+2,'both markers complete over a few more updates')
B.beginRefresh();B.endRefresh();frame(time+0.016);refresh()
assert(#queue==0 and #errors==0,table.concat(errors,';'))
print('PASS: fresh scan on reopen, replaced on a new radius, dismissal, no flash when cut short, switches, removal')

-- An upgrade hands the stage to the celebration.
E.config.upgradeWave=false
local beforeUpgrade=created
B.mark(base,screen,4900);pump(40)
local marker=component
assert(marker.visible and created==beforeUpgrade+1)
level=9;radius=4900;time=time+0.016;refresh()
assert(marker.alive,'the marker fades rather than vanishing when the upgrade lands')
frame(time+0.016);local upgradedAt=time
frame(upgradedAt+M.fadeOut+0.001)
assert(not marker.alive,'the upgrade itself dismisses the marker, before the rows report anything')
for _=1,12 do pump(10);B.mark(base,screen,5075) end -- reports keep coming while the screen is open
assert(created==beforeUpgrade+2 and #component.geometry==2,
    'only the contour is prepared while the celebration is pending or playing; no second marker')
B.beginRefresh();B.endRefresh();frame(time+0.016);refresh()
assert(#queue==0 and #errors==0,table.concat(errors,';'))
-- Afterwards the marker announces the level after that.
local beforeNext=created
B.mark(base,screen,5075);pump(4)
assert(created==beforeNext+1 and component.visible)
near(math.sqrt(component.geometry[1].vertices[2].X^2+component.geometry[1].vertices[2].Y^2),5075)
B.beginRefresh();B.endRefresh();frame(time+0.016);refresh()
print('PASS: an upgrade dismisses the marker, none appears during the celebration, the next level is announced afterwards')

-- A failed setup is cleaned, reported once and not repeated for that radius.
local beforeFail,beforeDestroyed,beforeTraces=created,destroyed,traces
failMesh=true;B.mark(base,screen,5075);pump(6)
assert(created==beforeFail+1 and destroyed==beforeDestroyed+1 and #queue==0,'failed mesh: component destroyed, updates stop')
assert(#errors==1 and errors[1]:find('next boundary marker',1,true),table.concat(errors,';'))
local afterFail=traces
B.mark(base,screen,5075);pump(6)
assert(created==beforeFail+1 and traces==afterFail and #queue==0,'the same radius is not retried on every refresh')
failMesh=false;B.mark(base,screen,5250);pump(6)
assert(created==beforeFail+2 and component.visible,'another radius is tried again')
B.beginRefresh();B.endRefresh();frame(time+0.016);refresh()
errors={};noGround=true
local beforeNoGround=created
B.mark(base,screen,5250);pump(6)
assert(created==beforeNoGround and #queue==0 and #errors==1 and errors[1]:find('No terrain under the next boundary',1,true),
    'no ground under the next boundary: nothing is drawn')
noGround=false
near(actor.AreaRange.RelativeScale3D.X,98)
print('PASS: failed marker setup is cleaned, reported once, not repeated for the same radius; no ground draws nothing')

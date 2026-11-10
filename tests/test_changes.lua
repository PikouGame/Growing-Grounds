local root=assert(arg[1])
local hooks,live,scans={},{},0
FindAllOf=function(name) scans=scans+1;return live[name] or {} end
NotifyOnNewObject=function(path,fn) hooks[path]=fn end
local E={valid=function(o) return o and o.alive end,guard=function(_,fn) return pcall(fn) end}
E.objects=dofile(root..'src/objects.lua')(E)
E.objects.install()
local make=dofile(root..'src/changes.lua')
local C=make(E)
for _=1,100 do assert(not C.check()) end
assert(scans==0,'frequent observer must not seed global searches')
local function base(name,level,radius)
    return {name=name,level=level,radius=radius,alive=true,available=true,
        GetFullName=function(s) return s.name end, HasAnyFlags=function() return false end,
        IsAvailable=function(s) return s.available end,
        GetLevel=function(s) return s.level end,GetRange=function(s) return s.radius end}
end
local b=base('World.Base',9,4900)
live.PalBaseCampModel={b}
E.objects.all('PalBaseCampModel')
assert(C.check() and not C.check(),'initial base reconciles once')
for _=1,1000 do assert(not C.check()) end
assert(scans==1,'stable checks must not search all game objects')
local authority,previewCalls=false,0
E.runtime={isAuthority=function() return authority end}
E.preview={revision=function(model) previewCalls=previewCalls+1;return model.preview end}
b.preview='10:145:150:true:20'
assert(C.check() and not C.check(),'initial preview arrives independently of the base')
b.level=10
assert(C.check() and not C.check(),'detect a level before radius replication')
b.radius=5075
assert(C.check() and not C.check(),'detect delayed radius without a five-second reconciliation')
b.radius=5250
assert(C.check());b.level=11;assert(C.check(),'radius-before-level also works')
b.radius=5250.01;assert(not C.check(),'ignore insignificant float noise')
b.preview='11:150:155:true:20'
assert(C.check() and not C.check(),'late preview triggers refresh without waiting five seconds')
b.preview='11:150:155:true:0'
assert(C.check() and not C.check(),'policy-only changes refresh disabled rewards too')
b.preview=nil
assert(C.check() and not C.check(),'invalidated preview reconciles once')
local late=base('World.Late',0,0)
hooks['/Script/Pal.PalBaseCampModel'](late)
assert(not C.check(),'not-ready bases cause no refresh loop')
late.level=1;late.radius=3500
assert(C.check() and not C.check(),'late initialization is observed')
-- A server or co-op host never reads the preview: no revision call per base, and
-- level and radius changes still reconcile.
authority=true;previewCalls=0
b.preview='12:160:165:true:20'
assert(not C.check() and previewCalls==0,'an authority ignores the preview and never asks for it')
b.level=12;assert(C.check() and not C.check(),'an authority still reports a level change')
b.radius=5600;assert(C.check() and not C.check(),'an authority still reports a radius change')
assert(previewCalls==0,'no preview call on an authority')
authority=false
assert(C.check() and not C.check(),'a client reads the preview again')
assert(previewCalls>0)
late.bTemporary=true;assert(C.check() and not C.check())
late.radius=7000;assert(not C.check(),'temporary raid bases are ignored')
b.alive=false
assert(C.check() and not C.check(),'deletion reconciles once and drops references')
local nextWorld=base('OtherWorld.Base',1,3500)
hooks['/Script/Pal.PalBaseCampModel'](nextWorld)
assert(C.check(),'new world is discovered from notification')
assert(scans==1)
local menu={alive=true,active=false,CanLevelup=false,HasAnyFlags=function() return false end,
    GetFullName=function() return 'World.Menu' end,IsActivated=function(self) return self.active end}
live.WBP_IngameMenu_Mission_C={menu}
E.objects.all('WBP_IngameMenu_Mission_C')
assert(not C.check(),'a closed menu does not cause a refresh')
menu.active=true
assert(C.check() and not C.check(),'opening an existing menu refreshes once')
menu.active=false;assert(not C.check())
nextWorld.preview='2:105:110:true:20';assert(C.check())
menu.active=true
assert(C.check() and not C.check(),'reopening after closed-screen replication cannot wait for reconciliation')
menu.CanLevelup=true
assert(C.check() and not C.check(),'native readiness colors refresh without a level change')
for _=1,1000 do assert(not C.check()) end
assert(scans==2,'base/menu observers only use event-maintained sets')

-- Failed native registration keeps the slow fallback, never four scans/second.
NotifyOnNewObject=function() error('unavailable') end
local fallback=dofile(root..'src/objects.lua')(E);fallback.install()
fallback.all('PalBaseCampModel');local before=scans
local F=make({valid=E.valid,objects=fallback,guard=E.guard})
for _=1,100 do assert(not F.check()) end
assert(scans==before,'frequent fallback cannot reintroduce the freezing scans')

-- Observe directly on the game thread; one native loop cannot backlog itself.
local timer,refreshes=nil,0
LoopInGameThreadWithDelay=function(interval,fn) assert(interval==250);timer=fn end
LoopAsync=function() error('Observer must never run asynchronously') end
C.install(function() refreshes=refreshes+1 end)
nextWorld.level=2
timer();assert(refreshes==1,'native timer detects a changed base')
for _=1,20 do timer() end
assert(refreshes==1,'unchanged world triggers no full refresh')
local saved=nextWorld.GetRange
nextWorld.GetRange=function() error('destroyed during check') end
timer()
nextWorld.GetRange=saved;nextWorld.radius=3675
timer();assert(refreshes==2,'observer recovers after invalidation')
print('PASS: prompt split replication, stable no-op checks, no global scans, fallback isolation, travel/deletion and native game-thread observation')

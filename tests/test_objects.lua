local root=assert(arg[1])
local hooks,counts,live,paths={},{},{},{}
local function obj(name,flags)
    return {alive=true,name=name,IsValid=function(s) return s.alive end,
        GetFullName=function(s) return s.name end,HasAnyFlags=function() return (flags or 0)~=0 end}
end
FindAllOf=function(name) counts[name]=(counts[name] or 0)+1;return live[name] or {} end
StaticFindObject=function(path) counts[path]=(counts[path] or 0)+1;return paths[path] end
NotifyOnNewObject=function(path,fn) assert(not hooks[path],'duplicate listener');hooks[path]=fn end
local E={valid=function(o) return o and o:IsValid() end,guard=function(_,fn) return pcall(fn) end}
local make=dofile(root..'src/objects.lua')
local O=make(E)
local created=0
O.install(function() created=created+1 end);O.install()
local first=obj('World1.Base1')
live.PalBaseCampModel={first,obj('Default__PalBaseCampModel',0x10)}
assert(#O.all('PalBaseCampModel')==1,'template objects are excluded')
for _=1,100 do
    assert(O.first('PalBaseCampModel')==first)
    assert(#O.all('BP_BuildObject_PalBoxV2_C')==0)
    assert(#O.all('WBP_IngameMenu_Mission_C')==0)
end
assert(counts.PalBaseCampModel==1 and counts.BP_BuildObject_PalBoxV2_C==1
    and counts.WBP_IngameMenu_Mission_C==1,'steady refreshes never repeat global scans, even for empty menus')
local second=obj('World1.Base2')
hooks['/Script/Pal.PalBaseCampModel'](second)
hooks['/Script/Pal.PalBaseCampModel'](second)
assert(#O.all('PalBaseCampModel')==2 and created==2,'new objects appear without a rescan or duplicate entry')
first.alive=false
assert(O.first('PalBaseCampModel')==second,'destroyed objects are removed')
second.name='World1.ReusedAddress'
assert(#O.all('PalBaseCampModel')==0,'a valid wrapper with a changed name is not reused')
local third=obj('World2.Base1')
hooks['/Script/Pal.PalBaseCampModel'](third)
assert(O.first('PalBaseCampModel')==third and counts.PalBaseCampModel==1,'travel/new world repopulates through construction')
local game=obj('Persistent.GameInstance')
assert(O.first('PalGameInstance')==nil)
hooks['/Script/Pal.PalGameInstance'](game)
for _=1,100 do assert(O.first('PalGameInstance')==game) end
assert(counts.PalGameInstance==1,'late singletons do not trigger repeated FindFirstOf scans')
local utility=obj('Utility')
paths.Utility=utility
for _=1,100 do assert(O.find('Utility')==utility) end
assert(counts.Utility==1)
utility.alive=false;local replacement=obj('Utility');paths.Utility=replacement
assert(O.find('Utility')==replacement and counts.Utility==2,'invalid static wrappers are reacquired')
assert(O.find('LateClass')==nil)
paths.LateClass=obj('LateClass')
assert(O.find('LateClass')==paths.LateClass,'missing classes are not cached permanently')
O.all('PalMapObjectModel');O.all('PalMapObjectModel')
assert(counts.PalMapObjectModel==2,'untracked infrequent queries keep their original semantics')
NotifyOnNewObject=function() error('native registration unavailable') end
local fallback=make(E);fallback.install()
fallback.all('PalBaseCampModel');fallback.all('PalBaseCampModel')
assert(counts.PalBaseCampModel==3,'failed registration preserves discovery correctness')
print('PASS: no steady object scans, empty/late discovery, deletion, travel, identity reuse, static cache and registration fallback')

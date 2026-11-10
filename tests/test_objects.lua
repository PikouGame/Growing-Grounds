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
-- A set nobody reads keeps no queue: its notified objects are not held back from collection.
local chests=hooks['/Script/Pal.PalMapObjectItemChestModel']
local weak=setmetatable({},{__mode='v'})
local before=created
for i=1,1000 do local o=obj('Chest'..i);weak[i]=o;chests(o) end
collectgarbage('collect')
assert(next(weak)==nil and created==before+1000,'an unseeded set queues nothing, yet every notification calls back')
-- Its first use still finds every live object, and a seeded set then takes new ones through the queue.
local guilds,idle={},hooks['/Script/Pal.PalGroupGuild']
for i=1,1000 do guilds[i]=obj('Guild'..i);idle(guilds[i]) end
live.PalGroupGuild=guilds
assert(#O.all('PalGroupGuild')==1000,'an unseeded set finds the objects through its first scan')
local late=obj('Guild1001');idle(late)
assert(#O.all('PalGroupGuild')==1001 and counts.PalGroupGuild==1,'a seeded set takes new objects without a rescan')
print('PASS: no steady object scans, empty/late discovery, deletion, travel, identity reuse, static cache and registration fallback')

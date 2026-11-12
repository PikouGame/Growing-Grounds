-- Real settings -> range/runtime -> preview wire -> runtime -> reward painter.
-- Only native objects, network delivery and settings file I/O are simulated.
local root=assert(arg[1])
local fixture=assert(loadfile(root..'tests/test_ui.lua'))('fixture')
local E,UI,screen=fixture.env,fixture.ui,fixture.screen
local Range=dofile(root..'src/range.lua')
local settingsFactory=dofile(root..'src/settings.lua')
local runtimeFactory=dofile(root..'src/runtime.lua')
local previewFactory=dofile(root..'src/preview.lua')
local worldId=string.rep('A',32)
local files={}
local fs={}
function fs.open(path,mode)
    if mode=='r' then
        local value=files[path]
        if not value then return nil,'missing',2 end
        return {lines=function() return value:gmatch('[^\r\n]+') end,close=function() return true end}
    end
    return {write=function(_,value) files[path]=value;return true end,close=function() return true end}
end
function fs.rename(from,to) assert(files[from]);files[to],files[from]=files[from],nil;return true end
function fs.remove(path) files[path]=nil;return true end
local store=settingsFactory('',Range,{},fs)
store.save(worldId,{growthPercentPerLevel=4,maxRangeBonusPercent=100,maxChestBonusSlots=18,
    startingPalboxBoxes=1,maxPalboxBoxes=16})

local function obj(name,value)
    value=value or {}
    function value:IsValid() return true end
    function value:GetFullName() return name end
    return value
end
local id={A=1,B=2,C=3,D=4}
local function base(name,authority)
    return obj(name,{authority=authority,level=10,AreaRange=3500,
        IsAvailable=function() return true end,
        GetLevel=function(self) return self.level end,
        GetRange=function(self) return self.AreaRange end,
        GetId=function() return id end,GetGroupIdBelongTo=function() return id end,
        GetTransform=function() return {Translation={X=0,Y=0,Z=0}} end})
end
local host,remote=base('host-base',true),base('client-base',false)
local native=obj('native-settings',{BaseCampAreaRange=3500})
local utility=obj('utility',{
    IsServer=function(_,context) return context.authority end,
    GetGameSetting=function() return native end,
    GetBaseCampManager=function() return nil end})
local levelTable=obj('levels',{GetMaxLevel=function() return 35 end})
local componentClass=obj('Class /Script/Engine.SceneComponent')
local function box(name,authority)
    local concrete=obj(name..'-concrete',{BaseCampId=id})
    local model=obj(name..'-model',{GetConcreteModel=function() return concrete end})
    local actor=obj(name,{authority=authority,bReplicates=true,components={},
        GetModel=function() return model end,IsA=function() return true end,
        FlushNetDormancy=function() end,ForceNetUpdate=function() end})
    function actor:K2_GetComponentsByClass()
        local result={}
        for _,component in ipairs(self.components) do
            result[#result+1]={get=function() return component end}
        end
        return result
    end
    function actor:AddComponentByClass(_,_,transform)
        local component=obj(name..'-preview',{
            RelativeLocation=transform.Translation,RelativeScale3D=transform.Scale3D,
            GetClass=function() return componentClass end,GetOwner=function() return actor end,
            SetMobility=function() end,SetComponentTickEnabled=function() end,
            SetVisibility=function() end,SetHiddenInGame=function() end,SetIsReplicated=function() end})
        function component:K2_SetRelativeLocation(value) self.RelativeLocation=value end
        function component:SetRelativeScale3D(value) self.RelativeScale3D=value end
        self.components[#self.components+1]=component
        return component
    end
    return actor
end
local hostBox,clientBox=box('server-box',true),box('client-box',false)
local uiObjects=E.objects
local function objects(model,actor)
    return {
        find=function(path)
            if path=='/Script/Pal.Default__PalUtility' then return utility end
            if path=='/Script/Engine.SceneComponent' then return componentClass end
            return uiObjects.find(path)
        end,
        first=function(name) if name=='PalMasterDataTableAccess_BaseCampLevelData' then return levelTable end end,
        all=function(name)
            if name=='PalBaseCampModel' then return {model} end
            if name=='BP_BuildObject_PalBoxV2_C' then return {actor} end
            if name=='WBP_IngameMenu_Mission_C' then return {screen} end
            return {}
        end,
    }
end
local server={root=root,range=Range,config={},valid=E.valid,log=E.log,
    guard=function(_,fn) return pcall(fn) end,objects=objects(host,hostBox),
    policy=function() return store.get(worldId) end}
server.runtime=runtimeFactory(server)
server.preview=previewFactory(server)
E.range=Range
E.config={growthPercentPerLevel=20,maxRangeBonusPercent=300,maxChestBonusSlots=42,
    startingPalboxBoxes=96,maxPalboxBoxes=96} -- deliberately incompatible local defaults
E.objects=objects(remote,clientBox)
E.runtime=runtimeFactory(E)
E.preview=previewFactory(E)
fixture.runtime.snapshot=E.runtime.snapshot
screen.GetBaseCampModel=function() return remote end
screen.CanLevelup=true

local function publish()
    server.runtime.apply(host)
    local snapshot=server.runtime.snapshot(host)
    server.preview.refresh()
    server.preview.publish(hostBox,host,snapshot.nextPercent,snapshot.maximumPercent)
    server.preview.finish()
    local component=hostBox.components[1]
    return {level=host.level,radius=host.AreaRange,location=component.RelativeLocation,scale=component.RelativeScale3D}
end
local component=clientBox:AddComponentByClass(componentClass,true,{Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}})
local function deliver(packet,field)
    if field=='level' then remote.level=packet.level
    elseif field=='radius' then remote.AreaRange=packet.radius
    elseif field=='location' then component.RelativeLocation=packet.location
    elseif field=='scale' then component.RelativeScale3D=packet.scale end
    E.preview.refresh();UI.refresh()
end
local fields={'level','radius','location','scale'}
local function complete(packet) for _,field in ipairs(fields) do deliver(packet,field) end end
local function row(key)
    for _,value in ipairs(fixture.parent.children) do
        if value.Text_Efefct.value==E.texts()[key] then return value end
    end
    error('Missing reward '..key)
end
local function values(key,current,following)
    local reward=row(key)
    assert(reward.visibility==4 and reward.Text_Num_Pre.value==tostring(current),key..' current')
    assert(reward.Text_Num_Aft.value==tostring(following),key..' next')
end
local initial=publish();complete(initial)
values('rangeRow',36,40);values('chestRow',5,5);values('palboxRow',5,5)
host.level=11
local upgraded=publish()
local orders=0
local function permutations(prefix,remaining)
    if #remaining==0 then
        complete(initial)
        for _,field in ipairs(prefix) do
            deliver(upgraded,field)
            local displayed=row('rangeRow').Text_Num_Pre.value
            assert(displayed=='36' or displayed=='40','never paint the client growth rate')
            local palbox=row('palboxRow')
            if palbox.visibility==4 then assert(palbox.Text_Num_Pre.value=='5','never invent local Palbox totals') end
        end
        values('rangeRow',40,44);values('chestRow',5,6);values('palboxRow',5,6)
        orders=orders+1;return
    end
    for i,field in ipairs(remaining) do
        local nextPrefix,nextRemaining={table.unpack(prefix)},{}
        nextPrefix[#nextPrefix+1]=field
        for j,value in ipairs(remaining) do if i~=j then nextRemaining[#nextRemaining+1]=value end end
        permutations(nextPrefix,nextRemaining)
    end
end
permutations({},fields);assert(orders==24)

-- Persist and reload a server policy without changing the base's level.
store.save(worldId,{growthPercentPerLevel=7,maxRangeBonusPercent=140,maxChestBonusSlots=42,
    startingPalboxBoxes=8,maxPalboxBoxes=64})
store=settingsFactory('',Range,{},fs)
local changed=publish()
deliver(changed,'location') -- mismatched radius: keep the last coherent menu
screen.active=false;UI.refresh();screen.active=true
for _,key in ipairs({'rangeRow','chestRow','palboxRow'}) do fixture.reconstruct(row(key)) end
UI.refresh();values('rangeRow',40,44)
deliver(changed,'scale');deliver(changed,'radius')
values('rangeRow',70,77);values('chestRow',12,14);values('palboxRow',24,26)
fixture.setLanguage('fr');UI.refresh()
values('rangeRow',70,77);values('palboxRow',24,26)
local created,writes,prepasses=fixture.counters()
UI.refresh();UI.refresh()
local createdAfter,writesAfter,prepassesAfter=fixture.counters()
assert(created==createdAfter and writes==writesAfter and prepasses==prepassesAfter,'idle UI does no rebuilding or repainting')

server.config.resetToVanilla=true
complete(publish())
for _,key in ipairs({'rangeRow','chestRow','palboxRow'}) do assert(row(key).visibility==1,'reset hides '..key) end
assert(remote.AreaRange==3500 and server.runtime.apply(remote)==false,'client never gains authority')
print('PASS: persisted server policy through real runtime/preview/UI, 24 delivery orders, reopen, localization, idle and reset')

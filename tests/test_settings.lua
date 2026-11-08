local root=assert(arg[1],'pass mod root with trailing slash')
local Range=dofile(root..'src/range.lua')
local factory=dofile(root..'src/settings.lua')
local files, failCommit = {}, false
local fs={}
function fs.open(path,mode)
    if mode=='r' then
        if not files[path] then return nil,'missing',2 end
        local content=files[path]
        return {close=function() return true end, lines=function() return content:gmatch('[^\r\n]+') end}
    end
    return {write=function(_,data) files[path]=data; return true end,close=function() return true end}
end
function fs.rename(a,b)
    if failCommit and a:match('%.tmp$') then return nil,'disk unavailable' end
    assert(files[a], 'source must exist')
    files[b], files[a] = files[a], nil
    return true
end
function fs.remove(path) files[path]=nil;return true end
local a,b=string.rep('A',32),string.rep('B',32)
local defaults={growthPercentPerLevel=5,maxRangePercent=200}
local store=factory('',Range,defaults,fs)
assert(store.get(a).maxRangePercent==200)
assert(not pcall(store.save,'../../config.lua',defaults))
store.save(a,{growthPercentPerLevel=8,maxRangePercent=175})
store.save(b,{growthPercentPerLevel=2,maxRangePercent=125})
store=factory('',Range,defaults,fs)
assert(store.get(a).growthPercentPerLevel==8 and store.get(a).maxRangePercent==175)
assert(store.get(b).growthPercentPerLevel==2 and store.get(b).maxRangePercent==125)
assert(store.get(nil).growthPercentPerLevel==5,'server defaults stay independent')
failCommit=true
assert(not pcall(store.save,a,{growthPercentPerLevel=20,maxRangePercent=200}))
assert(store.get(a).growthPercentPerLevel==8,'failed save never commits cache')
assert(factory('',Range,defaults,fs).get(a).growthPercentPerLevel==8,'failed rename restores disk')
failCommit=false
files['world-settings.ini.bak'],files['world-settings.ini']=files['world-settings.ini'],nil
assert(factory('',Range,defaults,fs).get(a).growthPercentPerLevel==8,'interrupted Windows rename recovers backup')
files['world-settings.ini']='['..a..']\ngrowthPercentPerLevel=20\nmaxRangePercent=500\nos.execute("bad")\n'
store=factory('',Range,defaults,fs)
assert(store.get(a).maxRangePercent==200,'sidecar cannot bypass hard cap')
print('PASS: per-world isolation, data-only parsing, traversal rejection, cap, persistence and failed-write recovery')

local objects,hookCallbacks={},{}
local nextRow=0
local function obj(name,data)
    data=data or {};objects[name]=data;data.alive=true
    data.IsValid=function(self) return self.alive end
    data.GetFullName=function() return name end
    return data
end
StaticFindObject=function(path) return objects[path] end
FText=function(v) return v end
RegisterHook=function(path,fn) hookCallbacks[path]=fn end
local panel=obj('panel',{children={}})
function panel:GetChildrenCount() return #self.children end
function panel:GetChildAt(i) return self.children[i+1] end
function panel:AddChild(row) self.children[#self.children+1]=row;return {SetPadding=function() end} end
local rowPath='/Game/Pal/Blueprint/UI/UserInterface/Title/WBP_Title_WorldSettings_ListContent.WBP_Title_WorldSettings_ListContent_C'
obj(rowPath)
obj('/Script/UMG.Default__WidgetBlueprintLibrary',{
    Create=function()
        nextRow=nextRow+1
        return obj('row'..nextRow,{Text_OptionTitle={SetText=function(self,v) self.text=v end},
            SetToolTipText=function() end,SetupIntValue=function(self,v,min,max) self.value=v end})
    end,
})
local menu=obj('menu',{ScrollBox_DifficultySetting=panel,
    WorldSettings_BaseCampWorkerNum=obj('nativeRow',{OptionType=1}),GetOwningPlayer=function() end})
local outer=obj('outer',{WBP_Title_WorldSettings=menu})
local current=a
local E={range=Range,settings=store,worldId=function() return current end,
    valid=function(o) return o and o:IsValid() end,log=function() end,guard=function(_,fn) return fn() end}
local W=dofile(root..'src/world_settings.lua')(E)
W.setup(menu,a,false);assert(#panel.children==2)
W.change(panel.children[1],7)
assert(menu.IsEditedSettingFlag and menu.IsEditedInCustomSetting)
assert(store.get(a).growthPercentPerLevel==20,'drag is draft only')
W.saved(outer,false);assert(store.get(a).growthPercentPerLevel==20,'native save failure must not commit')
W.setup(menu,a,false);assert(#panel.children==2 and panel.children[1].value==20,'cancel/reopen discards draft without duplicates')
W.change(panel.children[1],7);W.change(panel.children[2],165)
W.saved(outer,true)
assert(store.get(a).growthPercentPerLevel==7 and store.get(a).maxRangePercent==165)
W.setup(menu,b,false)
W.change(panel.children[1],3);W.saved(outer,true)
assert(store.get(a).growthPercentPerLevel==7 and store.get(b).growthPercentPerLevel==3)
W.setup(menu,'',true);W.change(panel.children[1],9)
W.newGame(outer);W.refresh()
assert(store.get(a).growthPercentPerLevel==7,'new world must not overwrite selected old world')
current=string.rep('C',32);W.refresh()
assert(store.get(current).growthPercentPerLevel==9 and not W.pendingNew)
print('PASS: native menu draft/confirm/failure/cancel, no duplicate rows, correct world and new-world identity')

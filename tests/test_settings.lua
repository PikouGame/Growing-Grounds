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
local defaults={growthPercentPerLevel=5,maxRangeBonusPercent=100,maxChestBonusSlots=20}
local store=factory('',Range,defaults,fs)
assert(store.get(a).maxRangeBonusPercent==100)
assert(not pcall(store.save,'../../config.lua',defaults))
store.save(a,{growthPercentPerLevel=8,maxRangePercent=175})
store.save(b,{growthPercentPerLevel=2,maxRangePercent=125})
store=factory('',Range,defaults,fs)
assert(store.get(a).growthPercentPerLevel==8 and store.get(a).maxRangeBonusPercent==75)
assert(store.get(b).growthPercentPerLevel==2 and store.get(b).maxRangeBonusPercent==25)
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
assert(store.get(a).maxRangeBonusPercent==100,'legacy oversize sidecar retains the former hard cap')
print('PASS: per-world isolation, data-only parsing, traversal rejection, cap, persistence and failed-write recovery')

local objects,hookCallbacks={},{}
local nextRow=0
local function obj(name,data)
    data=data or {};objects[name]=data;data.alive=true
    data.IsValid=function(self) return self.alive end
    data.GetFullName=function() return name end
    return data
end
-- Native transient widget full names cannot be resolved like asset paths.
StaticFindObject=function(path) return path:sub(1,1)=='/' and objects[path] or nil end
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
            SetToolTipText=function() end,
            WBP_OptionSettings_ListContentSlider=obj("slider"..nextRow,{BP_PalTextBlock_Value={SetText=function(self,v) self.text=v end}}),
            SetupIntValue=function(self,v,min,max) self.value=v; self.min=min; self.max=max end})
    end,
})
local menu=obj('menu',{ScrollBox_DifficultySetting=panel,
    WorldSettings_BaseCampWorkerNum=obj('nativeRow',{OptionType=1}),GetOwningPlayer=function() end})
local outer=obj('outer',{WBP_Title_WorldSettings=menu})
local current=a
local E={range=Range,settings=store,worldId=function() return current end,
    valid=function(o) return o and o:IsValid() end,log=function() end,guard=function(_,fn) return fn() end}
local W=dofile(root..'src/world_settings.lua')(E)
W.setup(menu,a,false);assert(#panel.children==3)
W.change(panel.children[1],7)
W.change(panel.children[3],40)
assert(store.get(a).maxChestBonusSlots==20,'chest slider changes only its draft')
assert(menu.IsEditedSettingFlag and menu.IsEditedInCustomSetting)
assert(store.get(a).growthPercentPerLevel==20,'drag is draft only')
W.saved(outer,false);assert(store.get(a).growthPercentPerLevel==20,'native save failure must not commit')
W.setup(menu,a,false);assert(#panel.children==3 and panel.children[1].value==20,'cancel/reopen discards draft without duplicates')
assert(panel.children[3].value==20,'cancel discards chest draft')
assert(panel.children[2].min==0 and panel.children[2].max==300)
assert(panel.children[2].WBP_OptionSettings_ListContentSlider.BP_PalTextBlock_Value.text=='+100%')
W.change(panel.children[1],7);W.change(panel.children[2],65);W.change(panel.children[3],40)
W.saved(outer,true)
assert(store.get(a).growthPercentPerLevel==7 and store.get(a).maxRangeBonusPercent==65)
assert(store.get(a).maxChestBonusSlots==40)
assert(panel.children[2].WBP_OptionSettings_ListContentSlider.BP_PalTextBlock_Value.text=='+65%')
W.setup(menu,b,false)
W.change(panel.children[1],3);W.saved(outer,true)
assert(store.get(a).growthPercentPerLevel==7 and store.get(b).growthPercentPerLevel==3)
W.setup(menu,'',true);W.change(panel.children[1],9)
W.change(panel.children[2],999);W.change(panel.children[3],999)
W.newGame(outer);W.refresh()
assert(store.get(a).growthPercentPerLevel==7,'new world must not overwrite selected old world')
current=string.rep('C',32);W.refresh()
assert(store.get(current).growthPercentPerLevel==9 and not W.pendingNew)
assert(store.get(current).maxRangeBonusPercent==300 and store.get(current).maxChestBonusSlots==40)
print('PASS: native menu draft/confirm/failure/cancel, no duplicate rows, correct world and new-world identity')

-- Old totals migrate once; a different world's save must not change their meaning.
files['world-settings.ini']='['..a..']\ngrowthPercentPerLevel=5\nmaxRangePercent=175\n'
local custom=factory('',Range,{maxRangeBonusPercent=300,maxChestBonusSlots=30},fs)
assert(custom.get(a).maxRangeBonusPercent==75 and custom.get(a).maxChestBonusSlots==30)
custom.save(b,{maxRangeBonusPercent=300,maxChestBonusSlots=40})
assert(not files['world-settings.ini']:find('maxRangePercent='),'write only canonical bonus settings')
custom=factory('',Range,{maxRangeBonusPercent=300,maxChestBonusSlots=30},fs)
assert(custom.get(a).maxRangeBonusPercent==75 and custom.get(a).maxChestBonusSlots==30)
assert(custom.get(b).maxRangeBonusPercent==300 and custom.get(b).maxChestBonusSlots==40)
files['world-settings.ini']='['..a..']\nmaxRangePercent=200\nmaxRangeBonusPercent=150\nmaxChestBonusSlots=-2\n'
custom=factory('',Range,defaults,fs)
assert(custom.get(a).maxRangeBonusPercent==150 and custom.get(a).maxChestBonusSlots==0)
print('PASS: legacy total migration, default inheritance, canonical precedence, +50..+300 display, chest cap0..40')

-- The 4% default only reaches a world that never saved its own growth value.
local saved=files['world-settings.ini']
local shipped=dofile(root..'config.lua')
assert(shipped.growthPercentPerLevel==4)
files['world-settings.ini']='['..a..']\ngrowthPercentPerLevel=5\nmaxRangeBonusPercent=100\nmaxChestBonusSlots=20\n'
local updated=factory('',Range,shipped,fs)
assert(updated.get(a).growthPercentPerLevel==5,'saved World Settings keep their growth after the update')
assert(updated.get(b).growthPercentPerLevel==4,'a world without saved settings follows the shipped config')
assert(updated.get(nil).growthPercentPerLevel==4,'a server reading the shipped config.lua gets the new default')
-- Saving another world writes every section in full; it must not move world A.
updated.save(b,{maxChestBonusSlots=30})
assert(files['world-settings.ini']:find('growthPercentPerLevel=5',1,true),'world A is rewritten with its own 5%')
updated=factory('',Range,shipped,fs)
assert(updated.get(a).growthPercentPerLevel==5 and updated.get(b).growthPercentPerLevel==4)
local kept=factory('',Range,{growthPercentPerLevel=5,maxRangeBonusPercent=100,maxChestBonusSlots=20},fs)
assert(kept.get(nil).growthPercentPerLevel==5,'a preserved config.lua keeps its explicit 5%')
assert(factory('',Range,{maxRangeBonusPercent=100},fs).get(nil).growthPercentPerLevel==4,
    'a config.lua without the key falls back to 4%')
files['world-settings.ini']=saved
print('PASS: 4% default reaches only unsaved worlds; saved World Settings and a kept config.lua retain 5%')

W.setup(menu,a,false)
W.change(panel.children[2],0);W.change(panel.children[3],0)
for _,i in ipairs({2,3}) do
    assert(panel.children[i].WBP_OptionSettings_ListContentSlider.BP_PalTextBlock_Value.text=='Off')
end
W.saved(outer,true);W.setup(menu,a,false)
assert(store.get(a).maxRangeBonusPercent==0 and store.get(a).maxChestBonusSlots==0)
assert(panel.children[2].value==0 and panel.children[3].value==0,'disabled caps persist on reopen')
print('PASS: both caps explicitly display Off at zero and persist independently')

local slider=panel.children[2].WBP_OptionSettings_ListContentSlider
slider.BP_PalTextBlock_Value:SetText('0')
W.sliderUpdated(slider)
assert(slider.BP_PalTextBlock_Value.text=='Off','native numeric rewrite must not erase Off')
W.change(panel.children[2],65);slider.BP_PalTextBlock_Value:SetText('65');W.sliderUpdated(slider)
assert(slider.BP_PalTextBlock_Value.text=='+65%','native numeric rewrite must not erase the range bonus notation')
W.sliderUpdated(obj('unowned slider'))
menu.alive=false;W.refresh();slider.BP_PalTextBlock_Value:SetText('native');W.sliderUpdated(slider)
assert(slider.BP_PalTextBlock_Value.text=='native','cleanup releases slider ownership')
print('PASS: native post-notification rewrites, keyboard/mouse repaint, unowned slider isolation and cleanup')

-- The slider maxima are the shared limits, not copies of them.
-- The cleanup test above closed the menu; reopen it, which builds a fresh row group.
menu.alive=true;W.setup(menu,a,false)
local rows={panel.children[#panel.children-2],panel.children[#panel.children-1],panel.children[#panel.children]}
assert(rows[1].max==Range.limits.growthPercentPerLevel and rows[2].max==Range.limits.maxRangeBonusPercent
    and rows[3].max==Range.limits.maxChestBonusSlots,'slider maxima equal Range.limits')
-- One source: with the chest limit raised in a fresh copy of the modules, settings and slider follow.
local raised=dofile(root..'src/range.lua')
raised.limits.maxChestBonusSlots=45
assert(raised.settings({maxChestBonusSlots=45}).maxChestBonusSlots==45 and raised.settings({maxChestBonusSlots=46}).maxChestBonusSlots==45)
assert(Range.settings({maxChestBonusSlots=45}).maxChestBonusSlots==40,'the unraised copy keeps its own limit')
local store2=factory('',raised,defaults,fs)
local panel2=obj('panel2',{children={}})
panel2.GetChildrenCount,panel2.GetChildAt,panel2.AddChild=panel.GetChildrenCount,panel.GetChildAt,panel.AddChild
local menu2=obj('menu2',{ScrollBox_DifficultySetting=panel2,
    WorldSettings_BaseCampWorkerNum=obj('nativeRow2',{OptionType=1}),GetOwningPlayer=function() end})
local outer2=obj('outer2',{WBP_Title_WorldSettings=menu2})
local W2=dofile(root..'src/world_settings.lua')({range=raised,settings=store2,worldId=function() return a end,
    valid=E.valid,log=E.log,guard=E.guard})
W2.setup(menu2,a,false)
assert(panel2.children[3].max==45,'slider maximum follows the raised limit')
W2.change(panel2.children[3],45);W2.saved(outer2,true)
assert(store2.get(a).maxChestBonusSlots==45,'a value up to the raised limit is saved')
assert(factory('',raised,defaults,fs).get(a).maxChestBonusSlots==45,'and read back')
print('PASS: slider maxima equal Range.limits and follow it from one source')

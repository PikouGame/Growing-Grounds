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
local defaults={maxRangeBonusPercent=100,maxChestBonusSlots=18}
local store=factory('',Range,defaults,fs)
assert(store.get(a).maxRangeBonusPercent==100)
assert(not pcall(store.save,'../../config.lua',defaults))
store.save(a,{maxRangeBonusPercent=80,maxRangePercent=175})
store.save(b,{maxRangeBonusPercent=30,maxRangePercent=125})
store=factory('',Range,defaults,fs)
assert(store.get(a).maxRangeBonusPercent==80 and store.get(b).maxRangeBonusPercent==30)
assert(store.get(nil).maxRangeBonusPercent==100,'server defaults stay independent')
failCommit=true
assert(not pcall(store.save,a,{maxRangeBonusPercent=200}))
assert(store.get(a).maxRangeBonusPercent==80,'failed save never commits cache')
assert(factory('',Range,defaults,fs).get(a).maxRangeBonusPercent==80,'failed rename restores disk')
failCommit=false
files['world-settings.ini.bak'],files['world-settings.ini']=files['world-settings.ini'],nil
assert(factory('',Range,defaults,fs).get(a).maxRangeBonusPercent==80,'interrupted Windows rename recovers backup')
files['world-settings.ini']='['..a..']\ngrowthPercentPerLevel=20\nmaxRangePercent=500\nos.execute("bad")\n'
store=factory('',Range,defaults,fs)
assert(store.get(a).maxRangeBonusPercent==100,'legacy oversize sidecar retains the former hard cap')
assert(store.get(a).growthPercentPerLevel==nil,'the removed growth setting is not a setting')
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
            SetToolTipText=function(self,v) self.tip=v end,
            WBP_OptionSettings_ListContentSlider=obj("slider"..nextRow,{BP_PalTextBlock_Value={SetText=function(self,v) self.text=v end}}),
            SetupIntValue=function(self,v,min,max) self.value=v; self.min=min; self.max=max end})
    end,
})
local menu=obj('menu',{ScrollBox_DifficultySetting=panel,
    WorldSettings_BaseCampWorkerNum=obj('nativeRow',{OptionType=1}),GetOwningPlayer=function() end})
local outer=obj('outer',{WBP_Title_WorldSettings=menu})
local current=a
local logs={}
local E={range=Range,settings=store,worldId=function() return current end,
    valid=function(o) return o and o:IsValid() end,log=function(m) logs[#logs+1]=m end,guard=function(_,fn) return fn() end}
E.objects={find=function(p) return StaticFindObject(p) end,all=function(n) return FindAllOf and FindAllOf(n) or {} end,first=function(n) return FindFirstOf and FindFirstOf(n) end}
local Texts=dofile(root..'src/texts.lua')
local language='en'
E.texts=function() return Texts.get(language) end
local W=dofile(root..'src/world_settings.lua')(E)
W.setup(menu,a,false);assert(#panel.children==2,'World Settings shows two rows')
assert(logs[#logs]=='World Settings: range bonus cap and chest bonus cap rows ready',tostring(logs[#logs]))
assert(panel.children[1].Text_OptionTitle.text=='Growing Grounds: Maximum range bonus')
assert(panel.children[1].tip=='The range bonus arrives steadily over all base levels; the last level gives it all. 0 disables it. +100% doubles the original radius; +300% makes it four times larger. Default: +100%. Nearby bases can limit growth.')
assert(panel.children[2].Text_OptionTitle.text=='Growing Grounds: Maximum bonus chest slots')
assert(panel.children[2].tip=='These slots arrive steadily over all base levels; the last level gives them all. 0 disables them. Default: 18. Guild Chests share one bonus. Occupied extra slots remain until emptied.')
W.change(panel.children[1],70)
W.change(panel.children[2],40)
assert(store.get(a).maxChestBonusSlots==18,'chest slider changes only its draft')
assert(menu.IsEditedSettingFlag and menu.IsEditedInCustomSetting)
assert(store.get(a).maxRangeBonusPercent==100,'drag is draft only')
W.saved(outer,false);assert(store.get(a).maxRangeBonusPercent==100,'native save failure must not commit')
W.setup(menu,a,false);assert(#panel.children==2 and panel.children[1].value==100,'cancel/reopen discards draft without duplicates')
assert(panel.children[2].value==18,'cancel discards chest draft')
assert(panel.children[1].min==0 and panel.children[1].max==300)
assert(panel.children[1].OverrideSliderStepValue==1 and panel.children[2].OverrideSliderStepValue==6)
assert(panel.children[2].min==0 and panel.children[2].max==42)
assert(panel.children[1].WBP_OptionSettings_ListContentSlider.BP_PalTextBlock_Value.text=='+100%')
W.change(panel.children[1],65);W.change(panel.children[2],40)
W.saved(outer,true)
assert(store.get(a).maxRangeBonusPercent==65)
assert(store.get(a).maxChestBonusSlots==42)
assert(panel.children[1].WBP_OptionSettings_ListContentSlider.BP_PalTextBlock_Value.text=='+65%')
W.setup(menu,b,false)
W.change(panel.children[1],30);W.saved(outer,true)
assert(store.get(a).maxRangeBonusPercent==65 and store.get(b).maxRangeBonusPercent==30)
W.setup(menu,'',true)
W.change(panel.children[1],999);W.change(panel.children[2],999)
W.newGame(outer);W.refresh()
assert(store.get(a).maxRangeBonusPercent==65,'new world must not overwrite selected old world')
current=string.rep('C',32);W.refresh()
assert(store.get(current).maxRangeBonusPercent==300 and not W.pendingNew)
assert(store.get(current).maxRangeBonusPercent==300 and store.get(current).maxChestBonusSlots==42)
print('PASS: native menu draft/confirm/failure/cancel, no duplicate rows, correct world and new-world identity')

-- Old totals migrate once; a different world's save must not change their meaning.
files['world-settings.ini']='['..a..']\ngrowthPercentPerLevel=5\nmaxRangePercent=175\n'
local custom=factory('',Range,{maxRangeBonusPercent=300,maxChestBonusSlots=30},fs)
assert(custom.get(a).maxRangeBonusPercent==75 and custom.get(a).maxChestBonusSlots==30)
custom.save(b,{maxRangeBonusPercent=300,maxChestBonusSlots=40})
assert(not files['world-settings.ini']:find('maxRangePercent='),'write only canonical bonus settings')
custom=factory('',Range,{maxRangeBonusPercent=300,maxChestBonusSlots=30},fs)
assert(custom.get(a).maxRangeBonusPercent==75 and custom.get(a).maxChestBonusSlots==30)
assert(custom.get(b).maxRangeBonusPercent==300 and custom.get(b).maxChestBonusSlots==42)
files['world-settings.ini']='['..a..']\nmaxRangePercent=200\nmaxRangeBonusPercent=150\nmaxChestBonusSlots=-2\n'
custom=factory('',Range,defaults,fs)
assert(custom.get(a).maxRangeBonusPercent==150 and custom.get(a).maxChestBonusSlots==0)
print('PASS: legacy total migration, default inheritance, canonical precedence, +50..+300 display, chest cap0..42 in steps of six')

-- A world file written by an older version has three keys per section. It is read as the
-- two settings, and written back with two. Only a growth of 0 (range off) still means something.
local function lines(text) local n=0 for _ in text:gmatch('[^\n]+') do n=n+1 end return n end
local saved=files['world-settings.ini']
files['world-settings.ini']='['..a..']\ngrowthPercentPerLevel=5\nmaxRangeBonusPercent=80\nmaxChestBonusSlots=12\n'
    ..'['..b..']\ngrowthPercentPerLevel=0\nmaxRangeBonusPercent=100\nmaxChestBonusSlots=25\n'
local old=factory('',Range,defaults,fs)
local read=old.get(a)
assert(read.maxRangeBonusPercent==80 and read.maxChestBonusSlots==12 and read.growthPercentPerLevel==nil,'old section: growth ignored')
assert(old.get(b).maxRangeBonusPercent==0 and old.get(b).maxChestBonusSlots==24,'old section with growth 0: range stays off, chests stay')
assert(old.get(nil).maxRangeBonusPercent==100,'worlds without a section follow the defaults')
local third=string.rep('C',32)
old.save(third,{maxRangeBonusPercent=40,maxChestBonusSlots=5})
local text=files['world-settings.ini']
assert(not text:find('growthPercentPerLevel',1,true),'the file is rewritten with two keys per section')
assert(text:find('['..b..']\nmaxRangeBonusPercent=0\nmaxChestBonusSlots=24\n',1,true),'the world that was off is written off')
assert(text:find('['..a..']\nmaxRangeBonusPercent=80\nmaxChestBonusSlots=12\n',1,true))
assert(lines(text)==1+3*3,'one comment line and three lines per section, got '..lines(text))
old=factory('',Range,{maxRangeBonusPercent=250,maxChestBonusSlots=20},fs)
assert(old.get(b).maxRangeBonusPercent==0,'a world that was off stays off after the rewrite, whatever the default')
assert(old.get(a).maxRangeBonusPercent==80 and old.get(third).maxRangeBonusPercent==40)
-- Growth 0 switches off the legacy total as well, and a saved-again world stays off.
files['world-settings.ini']='['..a..']\ngrowthPercentPerLevel=0\nmaxRangePercent=175\n'
old=factory('',Range,defaults,fs)
assert(old.get(a).maxRangeBonusPercent==0 and old.get(a).maxChestBonusSlots==18)
old.save(a,old.get(a))
assert(files['world-settings.ini']:find('maxRangeBonusPercent=0\n',1,true) and not files['world-settings.ini']:find('growth',1,true))
assert(factory('',Range,defaults,fs).get(a).maxRangeBonusPercent==0,'saving an off world again keeps it off')
-- A growth that is not 0 never matters, nor does a config.lua that still has the key.
files['world-settings.ini']='['..a..']\ngrowthPercentPerLevel=20\nmaxRangeBonusPercent=100\nmaxChestBonusSlots=20\n'
assert(factory('',Range,defaults,fs).get(a).maxRangeBonusPercent==100)
local shipped=dofile(root..'config.lua')
assert(shipped.growthPercentPerLevel==nil and shipped.maxRangeBonusPercent==100 and shipped.maxChestBonusSlots==18)
for growth,expected in pairs({[4]=100,[5]=100,[0]=0}) do
    local config=load('return {growthPercentPerLevel='..growth..',maxRangeBonusPercent=100,maxChestBonusSlots=20,resetToVanilla=false}')()
    local fromOld=factory('',Range,config,fs)
    files['world-settings.ini'],files['world-settings.ini.bak']=nil,nil
    assert(fromOld.get(nil).maxRangeBonusPercent==expected,'old config.lua growth '..growth)
    assert(fromOld.get(a).maxRangeBonusPercent==expected and fromOld.get(a).maxChestBonusSlots==18)
    files['world-settings.ini']='['..a..']\nmaxRangeBonusPercent=70\nmaxChestBonusSlots=20\n'
    assert(factory('',Range,config,fs).get(a).maxRangeBonusPercent==70,'a world that saved its own cap keeps it')
    assert(factory('',Range,config,fs).get(b).maxRangeBonusPercent==expected)
end
files['world-settings.ini']=saved
print('PASS: old three-key world files and old config.lua growth keys are read, growth 0 stays off, files are rewritten with two keys')

W.setup(menu,a,false)
W.change(panel.children[1],0);W.change(panel.children[2],0)
for _,i in ipairs({1,2}) do
    assert(panel.children[i].WBP_OptionSettings_ListContentSlider.BP_PalTextBlock_Value.text=='Off')
end
W.saved(outer,true);W.setup(menu,a,false)
assert(store.get(a).maxRangeBonusPercent==0 and store.get(a).maxChestBonusSlots==0)
assert(panel.children[1].value==0 and panel.children[2].value==0,'disabled caps persist on reopen')
print('PASS: both caps explicitly display Off at zero and persist independently')

local slider=panel.children[1].WBP_OptionSettings_ListContentSlider
slider.BP_PalTextBlock_Value:SetText('0')
W.sliderUpdated(slider)
assert(slider.BP_PalTextBlock_Value.text=='Off','native numeric rewrite must not erase Off')
W.change(panel.children[1],65);slider.BP_PalTextBlock_Value:SetText('65');W.sliderUpdated(slider)
assert(slider.BP_PalTextBlock_Value.text=='+65%','native numeric rewrite must not erase the range bonus notation')
W.sliderUpdated(obj('unowned slider'))
menu.alive=false;W.refresh();slider.BP_PalTextBlock_Value:SetText('native');W.sliderUpdated(slider)
assert(slider.BP_PalTextBlock_Value.text=='native','cleanup releases slider ownership')
print('PASS: native post-notification rewrites, keyboard/mouse repaint, unowned slider isolation and cleanup')

-- The slider maxima are the shared limits, not copies of them.
-- The cleanup test above closed the menu; reopen it, which builds a fresh row group.
menu.alive=true;W.setup(menu,a,false)
local rows={panel.children[#panel.children-1],panel.children[#panel.children]}
assert(rows[1].max==Range.limits.maxRangeBonusPercent and rows[2].max==Range.limits.maxChestBonusSlots,'slider maxima equal Range.limits')
-- One source: with the chest limit raised in a fresh copy of the modules, settings and slider follow.
local raised=dofile(root..'src/range.lua')
raised.limits.maxChestBonusSlots=48
assert(raised.settings({maxChestBonusSlots=48}).maxChestBonusSlots==48 and raised.settings({maxChestBonusSlots=49}).maxChestBonusSlots==48)
assert(Range.settings({maxChestBonusSlots=45}).maxChestBonusSlots==42,'the unraised copy keeps its own limit')
local store2=factory('',raised,defaults,fs)
local panel2=obj('panel2',{children={}})
panel2.GetChildrenCount,panel2.GetChildAt,panel2.AddChild=panel.GetChildrenCount,panel.GetChildAt,panel.AddChild
local menu2=obj('menu2',{ScrollBox_DifficultySetting=panel2,
    WorldSettings_BaseCampWorkerNum=obj('nativeRow2',{OptionType=1}),GetOwningPlayer=function() end})
local outer2=obj('outer2',{WBP_Title_WorldSettings=menu2})
local W2=dofile(root..'src/world_settings.lua')({range=raised,settings=store2,worldId=function() return a end,
    objects=E.objects,valid=E.valid,log=E.log,guard=E.guard,texts=E.texts})
W2.setup(menu2,a,false)
assert(panel2.children[2].max==48,'slider maximum follows the raised limit')
W2.change(panel2.children[2],48);W2.saved(outer2,true)
assert(store2.get(a).maxChestBonusSlots==48,'a value up to the raised limit is saved')
assert(factory('',raised,defaults,fs).get(a).maxChestBonusSlots==48,'and read back')
print('PASS: slider maxima equal Range.limits and follow it from one source')

-- Mouse floats snap directly to the six-slot grid, without intermediate integer rounding.
W.setup(menu,a,false)
local function drag(index,value)
    W.change(rows[index],value);W.saved(outer,true)
    return store.get(a)
end
assert(drag(2,18.9999).maxChestBonusSlots==18,'18.9999 stays at 18')
assert(drag(2,18.4).maxChestBonusSlots==18,'18.4 saves as 18')
assert(drag(2,18.5).maxChestBonusSlots==18 and drag(2,40.4).maxChestBonusSlots==42 and drag(2,-0.4).maxChestBonusSlots==0)
assert(drag(2,20.9999).maxChestBonusSlots==18 and drag(2,21).maxChestBonusSlots==24,'midpoint snaps up at 21, not 20.5')
assert(drag(2,2.9999).maxChestBonusSlots==0 and drag(2,3).maxChestBonusSlots==6,'off-to-six midpoint')
assert(drag(1,64.6).maxRangeBonusPercent==65 and drag(1,64.4).maxRangeBonusPercent==64)
assert(drag(1,999).maxRangeBonusPercent==300 and drag(2,999).maxChestBonusSlots==42,'maxima still clamp')
do
-- An unreadable file: defaults, one log line, a retry only after five seconds, saved values return.
files['world-settings.ini']='['..a..']\nmaxRangeBonusPercent=9\n'
local unreadable,now,logged,opens=true,100,{},0
local readFs={rename=fs.rename,remove=fs.remove}
function readFs.open(path,mode)
    if mode=='r' and path=='world-settings.ini' then
        opens=opens+1
        if unreadable then return nil,'permission denied',13 end
    end
    return fs.open(path,mode)
end
store=factory('',Range,defaults,readFs,function(m)logged[#logged+1]=m end,function()return now end)
for _=1,5 do assert(store.get(a).maxRangeBonusPercent==100,'unreadable file gives config values') end
local staleDraft=store.get(a) -- what a World Settings menu opened now would hold
assert(#logged==1 and logged[1]:find('permission denied',1,true) and opens==1,'logged once, not retried at once')
assert(not pcall(store.save,a,defaults),'save refuses while the file cannot be read')
now=104;store.get(a);assert(opens==1 and #logged==1,'no retry before five seconds')
now=105;store.get(a);assert(opens==2 and #logged==1,'retried after the interval, not logged again')
unreadable=false;now=110
assert(store.get(a).maxRangeBonusPercent==9 and opens==3,'saved values return once readable')
for _=1,3 do store.get(a) end
assert(opens==3 and #logged==1,'a loaded file is not read again')
-- A draft taken while the file was unreadable holds config values. Saving it
-- after the recovery would replace this world's saved 9 by the default.
staleDraft.maxChestBonusSlots=30
local onDisk=files['world-settings.ini']
assert(not pcall(store.save,a,staleDraft),'saving stays refused for the session after a read failure')
assert(files['world-settings.ini']==onDisk and store.get(a).maxRangeBonusPercent==9,'the saved values are untouched')
-- A clock set back does not postpone the next attempt.
unreadable=true;now=1000;opens=0
store=factory('',Range,defaults,readFs,function()end,function()return now end)
store.get(a);assert(opens==1)
now=400;store.get(a);assert(opens==2,'a clock set back retries at once')
now=402;store.get(a);assert(opens==2,'then the five-second interval applies again')
now=405;store.get(a);assert(opens==3)
unreadable=false
-- A missing file stays silent and is not retried.
files['world-settings.ini'],files['world-settings.ini.bak']=nil,nil
opens,logged=0,{}
store=factory('',Range,defaults,readFs,function(m)logged[#logged+1]=m end,function()return now end)
for _=1,3 do now=now+60;assert(store.get(a).maxRangeBonusPercent==100) end
assert(#logged==0 and opens==1,'missing file: silent and read once')
end
print('PASS: range slider rounds to whole percents, chest slider snaps directly to six-slot caps')

-- The two rows, their tooltips and Off are shown in the game's language.
do
    local french=Texts.get('fr')
    language='fr'
    W.setup(menu,a,false)
    -- Earlier blocks rebuilt the rows; the live pair is the last one in this mock's panel.
    local range,chest=panel.children[#panel.children-1],panel.children[#panel.children]
    local function shown(row) return row.WBP_OptionSettings_ListContentSlider.BP_PalTextBlock_Value.text end
    assert(range.Text_OptionTitle.text==french.rangeCapTitle and range.tip==french.rangeCapTip)
    assert(chest.Text_OptionTitle.text==french.chestCapTitle and chest.tip==french.chestCapTip)
    assert(french.rangeCapTitle=='Growing Grounds : bonus de rayon maximal' and french.off=='Désactivé')
    W.change(range,0);W.change(chest,0)
    assert(shown(range)=='Désactivé' and shown(chest)=='Désactivé')
    W.change(range,65);W.change(chest,7)
    assert(shown(range)=='+65%' and shown(chest)=='6')
    -- A language changed while the menu is open is followed at the next paint.
    language='ko'
    W.change(range,0)
    assert(range.Text_OptionTitle.text==Texts.get('ko').rangeCapTitle and shown(range)==Texts.get('ko').off)
    language='en'
    W.setup(menu,a,false)
    assert(range.Text_OptionTitle.text=='Growing Grounds: Maximum range bonus' and chest.tip==Texts.get('en').chestCapTip)
    assert(logs[#logs]=='World Settings: range bonus cap and chest bonus cap rows ready','the log stays in English')
end
print('PASS: World Settings rows, tooltips and Off follow the game language')

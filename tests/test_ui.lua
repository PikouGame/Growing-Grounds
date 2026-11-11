local root = assert(arg[1])
local function obj(t) t.IsValid=function() return true end; return t end
local widgetId=0
local function widget(t)
    t=t or {}
    widgetId=widgetId+1
    local id=widgetId
    t.GetFullName=t.GetFullName or function() return 'widget-'..id end
    t.GetParent=function(self) return self.parent end
    t.IsA=function(self,path) return self.class==path end
    t.SetVisibility=function(self,v) self.visibility=v end
    t.RemoveFromParent=function(self)
        if self.parent then
            for i,child in ipairs(self.parent.children) do
                if child==self then table.remove(self.parent.children,i);break end
            end
            self.parent=nil
        end
    end
    return obj(t)
end
local function label()
    return widget({value='',Font={Size=20,FontObject='native-font',TypefaceFontName='native-face'},
        ColorAndOpacity={SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0},RenderOpacity=1,
        ShadowColorAndOpacity={R=0,G=0,B=0,A=1},ShadowOffset={X=1,Y=1},
        SetText=function(self,v) self.value=v end,
        GetText=function(self) return {ToString=function() return self.value end} end,
        SetFont=function(self,v) local f={};for k,x in pairs(v) do f[k]=x end;self.Font=f end,
        SetColorAndOpacity=function(self,v) self.color=v;self.ColorAndOpacity=v end,
        SetRenderOpacity=function(self,v) self.RenderOpacity=v end,
        SetShadowColorAndOpacity=function(self,v) self.ShadowColorAndOpacity=v end,
        SetShadowOffset=function(self,v) self.ShadowOffset=v end,
        GetDesiredSize=function(self)
            if self.unmeasurable then return {X=0,Y=0} end
            -- The percent glyph need not have the same width as a digit.
            return {X=self.value=='%' and self.Font.Size*0.75 or utf8.len(self.value)*self.Font.Size*0.5,Y=self.Font.Size}
        end})
end
local function panel(width,class)
    local p=widget({children={},WidthOverride=width,class=class or '/Script/UMG.HorizontalBox'})
    p.GetChildrenCount=function(self) return #self.children end
    p.GetChildAt=function(self,i)
        local child=self.children[i+1]
        -- UE4SS can return a fresh Lua handle for the same UObject.
        if child and child.freshHandle then return setmetatable({},{__index=child,__newindex=child}) end
        return child
    end
    p.AddChild=function(self,child)
        child:RemoveFromParent();child.parent=self;self.children[#self.children+1]=child
        child.Slot={Padding={Left=0,Right=0,Top=0,Bottom=0},Size={Value=1,SizeRule=0},
            HorizontalAlignment=0,VerticalAlignment=0,
            SetPadding=function(slot,v) slot.padding=v;slot.Padding=v end,
            SetSize=function(slot,v) slot.Size=v end,
            SetVerticalAlignment=function(slot,v) slot.vertical=v;slot.VerticalAlignment=v end,
            SetHorizontalAlignment=function(slot,v) slot.horizontal=v;slot.HorizontalAlignment=v end}
        return child.Slot
    end
    p.AddChildToHorizontalBox=p.AddChild
    p.SetWidthOverride=function(self,v) self.WidthOverride=v end
    p.GetDesiredSize=function(self)
        if self.WidthOverride then return {X=self.WidthOverride,Y=20} end
        local x=0
        for _,child in ipairs(self.children) do
            x=x+child:GetDesiredSize().X+(child.Slot.padding and child.Slot.padding.Left or 0)
        end
        return {X=x,Y=20}
    end
    return p
end
local hook,created,writes,prepasses=nil,0,0,0
local parent=panel()
local rewardSection=widget({Slot=obj({position={X=0,Y=148},size={X=656,Y=152},
    GetSize=function(self) return self.size end, SetSize=function(self,s) self.size=s end,
    IsA=function(_,p) return p=='/Script/UMG.CanvasPanelSlot' end,
    GetPosition=function(self) return self.position end,
    SetPosition=function(self,p) self.position=p end})})
local rowStack=widget({parent=rewardSection})
parent.parent=rowStack
local texture=obj({})
local function row(name)
    local pre,aft=label(),label()
    local preBox,aftBox=panel(72,'/Script/UMG.SizeBox'),panel(72,'/Script/UMG.SizeBox')
    preBox:AddChild(pre);aftBox:AddChild(aft)
    -- Native reward hierarchy from WBP_IngameMenu_MissionLevelEffect:
    -- icon (24 + 12 padding), auto title, fill spacer, values (72), arrow (24).
    local content=panel()
    local icon=panel(24,'/Script/UMG.SizeBox')
    content:AddChild(icon):SetPadding({Left=0,Right=12,Top=0,Bottom=0})
    local title=label();title.freshHandle=true;content:AddChild(title):SetVerticalAlignment(2)
    local spacer=widget({class='/Script/UMG.Spacer',GetDesiredSize=function() return {X=0,Y=0} end})
    content:AddChild(spacer):SetSize({Value=1,SizeRule=1})
    content:AddChild(preBox):SetPadding({Left=0,Right=0,Top=1,Bottom=0})
    local arrow=widget({GetDesiredSize=function() return {X=24,Y=32} end})
    content:AddChild(arrow):SetVerticalAlignment(2)
    content:AddChild(aftBox):SetPadding({Left=0,Right=0,Top=1,Bottom=0})
    return widget({GetFullName=function() return name end,WidgetTree=obj({}),
        Text_Efefct=title,Text_Num_Pre=pre,Text_Num_Aft=aft,content=content,
        Image_Icon=widget({SetBrushFromTexture=function(self,v) self.texture=v end}),
        Image_Arrow=arrow,SizeBox_Aft=aftBox,
        GetDesiredSize=function() return {X=588,Y=32} end,
        ForceLayoutPrepass=function() prepasses=prepasses+1 end,
        SetEffectInfo=function(self,_,_,_,canLevelup)
            writes=writes+1
            self.Text_Num_Aft:SetColorAndOpacity({SpecifiedColor={R=0.2,G=0.8,B=1,A=1},ColorUseRule=0})
            self.Text_Num_Aft.RenderOpacity=canLevelup and 1 or 0.5
        end})
end
local function reconstruct(w)
    w.Text_Efefct:SetText('None')
    w.Image_Icon:SetBrushFromTexture(w.Texture)
    hook({get=function() return w end})
end
parent.AddChildToVerticalBox=function(self,w)
    assert(w.Texture==texture, 'texture must exist before first Construct')
    local slot=self:AddChild(w);reconstruct(w);return slot
end
local nativePal,nativeBase=row('vanilla-pal'),row('vanilla-base')
parent:AddChild(nativePal);parent:AddChild(nativeBase)
local model=obj({IsAvailable=function() return true end})
local screen=obj({CanLevelup=false,active=true,IsActivated=function(self) return self.active end,
    ForceLayoutPrepass=function() end,GetFullName=function() return 'screen' end,
    GetBaseCampModel=function() return model end,GetOwningPlayer=function() return obj({}) end,
    WBP_IngameMenu_MissionLevelEffect=nativePal,WBP_IngameMenu_MissionLevelEffect_1=nativeBase})
local library={Create=function() created=created+1;return row('row'..created) end}
StaticFindObject=function(path)
    if path:find('WidgetBlueprintLibrary',1,true) then return library end
    if path:find('KismetRenderingLibrary',1,true) then return {ImportFileAsTexture2D=function() return texture end} end
    return obj({path=path})
end
local constructed,titleBoxes=0,0
StaticConstructObject=function(class,outer,name)
    assert(outer:IsValid())
    if class.path=='/Script/UMG.ScaleBox' then
        assert(name=='GG_TitleFit')
        titleBoxes=titleBoxes+1
        local box=panel(nil,class.path)
        box.SetStretch=function(self,v) self.stretch=v end
        box.SetStretchDirection=function(self,v) self.direction=v end
        return box
    end
    assert(name:match('GG_Text_Num_'))
    constructed=constructed+1
    if class.path=='/Script/UMG.HorizontalBox' then return panel() end
    if class.path=='/Script/UMG.Spacer' then
        return widget({size={X=0,Y=0},SetSize=function(self,v) self.size=v end,
            GetDesiredSize=function(self) return self.size end})
    end
    assert(class.path=='/Script/UMG.TextBlock');return label()
end
RegisterHook=function(_,fn) assert(not hook,'duplicate Construct hook');hook=fn end
FText=function(v) return v end
FName=function(v) return v end
FindAllOf=function() return {screen} end
local snapshot={currentPercent=145,nextPercent=150,radius=5075,baseline=3500,atMaximum=false}
local E={root=root,log=function() end,guard=function(_,fn) fn() end,valid=function(o) return o and o:IsValid() end}
E.objects={find=function(p) return StaticFindObject(p) end,all=function(n) return FindAllOf and FindAllOf(n) or {} end,first=function(n) return FindFirstOf and FindFirstOf(n) end}
local Runtime={snapshot=function() return snapshot end}
local Texts=dofile(root..'src/texts.lua')
local language='en'
E.texts=function() return Texts.get(language) end
local UI=dofile(root..'src/ui.lua')(E,Runtime)
local function current() return parent.children[3] end
local function unit(w,field) return w[field]:GetParent():GetChildAt(2) end
local function note(w,field) return w[field]:GetParent():GetChildAt(3) end
local function assertTextAlignment(w)
    for _,field in ipairs({'Text_Num_Pre','Text_Num_Aft'}) do
        local main,n=w[field],note(w,field)
        assert(n.Slot.vertical==2 and n.Slot.padding.Left==3,
            'metres use the same vertical centre as the number, with a three-unit gap after percent')
        assert(n.Slot.padding.Top==0 and n.Slot.padding.Bottom==0,'plain vertical centring without optical offsets')
        for _,rowHeight in ipairs({20,36,60}) do
            local h,nh=main:GetDesiredSize().Y,n:GetDesiredSize().Y
            local mainCentre=(rowHeight-h)/2+h/2
            local noteCentre=(rowHeight-nh-n.Slot.padding.Top)/2+n.Slot.padding.Top+nh/2
            assert(math.abs(noteCentre-mainCentre)<0.00001,
                'metres share the numeric text centre independently of reward-row height')
            assert(n.Slot.padding.Top+nh<=h,'annotation must not enlarge the text group height')
        end
    end
end
local function assertCentred(w)
    for _,field in ipairs({'Text_Num_Pre','Text_Num_Aft'}) do
        local main=w[field]
        local group=main:GetParent()
        local width=group:GetParent().WidthOverride
        local groupLeft=(width-group:GetDesiredSize().X)/2
        local textCentre=groupLeft+group:GetChildAt(0):GetDesiredSize().X+main:GetDesiredSize().X/2
        assert(math.abs(textCentre-width/2)<0.001, 'only the digits must align with native value centres')
        if main.value~='' then
            local combinedCentre=textCentre+unit(w,field):GetDesiredSize().X/2
            assert(combinedCentre>width/2, 'the percent glyph must extend right of the centred number')
            local endOfNote=textCentre+main:GetDesiredSize().X/2+unit(w,field):GetDesiredSize().X
                +note(w,field):GetDesiredSize().X+3
            assert(width-endOfNote>=4,'reserve clearance before the chevrons without moving the centred digits')
        end
    end
end
UI.refresh()
assert(created==1 and #parent.children==3 and constructed==8, 'exactly one row and two balanced number/unit/metre groups')
local w=current()
assert(w.Text_Efefct.value=='Base Range Bonus' and w.Image_Icon.texture==texture)
assert(w.Text_Num_Pre.value=='45' and w.Text_Num_Aft.value=='50')
assert(note(w,'Text_Num_Pre').value=='50.8m' and note(w,'Text_Num_Aft').value=='52.5m')
for _,field in ipairs({'Text_Num_Pre','Text_Num_Aft'}) do
    local n=note(w,field)
    local u=unit(w,field)
    assert(u.value=='%' and u.Font.Size==13 and w[field].Font.Size==20,
        'percent suffix uses two-thirds size without changing the native number font')
    assert(u.Font.FontObject=='native-font' and u.Font.TypefaceFontName=='native-face')
    assert(u.color==w[field].ColorAndOpacity and u.RenderOpacity==w[field].RenderOpacity,
        'percent suffix follows native current/preview color and opacity')
    assert(not u.Slot.padding, 'no added gap between digits and percent')
    assert(n.Font.Size==9 and w[field].Font.Size==20, 'annotation is 45% without changing the main font')
    assert(n.Font.FontObject=='native-font' and n.Font.TypefaceFontName=='native-face')
    assert(n.color.SpecifiedColor.R==0.27 and n.color.SpecifiedColor.G==0.78 and n.color.SpecifiedColor.B==0.60)
    local width=w[field]:GetParent():GetParent().WidthOverride
    assert(width>=w[field]:GetParent():GetDesiredSize().X, 'annotation must fit measured text width')
    assert(nativePal[field]:GetParent().WidthOverride==width and nativeBase[field]:GetParent().WidthOverride==width,
        'all native reward arrows and value columns must share the same widths')
end
assertCentred(w)
assertTextAlignment(w)
-- A long title must not steal width from the numeric columns. Model the
-- native horizontal box allocation: Auto children keep desired width, Fill
-- children share the remaining space, clamped at zero. Physical DPI scale
-- does not change that allocation; changing available logical width does.
local function arrange(row,width,dpi)
    local fixed,fill=0,0
    for _,child in ipairs(row.content.children) do
        local slot=child.Slot
        fixed=fixed+slot.Padding.Left+slot.Padding.Right
        if slot.Size.SizeRule==1 then fill=fill+slot.Size.Value
        else fixed=fixed+child:GetDesiredSize().X end
    end
    local remaining=math.max(0,width-fixed)
    local x,positions=0,{}
    for _,child in ipairs(row.content.children) do
        local slot=child.Slot
        x=x+slot.Padding.Left
        local space=slot.Size.SizeRule==1 and remaining*slot.Size.Value/fill or child:GetDesiredSize().X
        positions[child]={left=x*dpi,width=space*dpi,centre=(x+space/2)*dpi}
        x=x+space+slot.Padding.Right
    end
    return positions,x*dpi
end
local function assertRewardLayout(rows,width,dpi)
    local expected
    for _,reward in ipairs(rows) do
        local placed,right=arrange(reward,width,dpi)
        local arrow=placed[reward.Image_Arrow].centre
        if expected then assert(math.abs(arrow-expected)<0.001,'a long title must not shift its arrow right') end
        expected=expected or arrow
        assert(right<=width*dpi+0.001,'all rewards stay within the row width')
        local title=reward.Text_Efefct
        local box=title:GetParent()
        local area=placed[title] or placed[box]
        local natural=title:GetDesiredSize().X*dpi
        local factor=1
        if box.class=='/Script/UMG.ScaleBox' then
            assert(box.stretch==2 and box.direction==1,'titles fit proportionally, shrinking only')
            assert(title.Slot.horizontal==1 and title.Slot.vertical==2,'titles stay left aligned and vertically centred')
            factor=math.min(1,area.width/natural)
        end
        assert(area.left+natural*factor<=placed[reward.content.children[#reward.content.children-2]].left+0.001,
            'the complete title fits before the value columns')
        assert(title.Font.Size==20,'fitting leaves the native font unchanged')
        assert(reward.content.children[#reward.content.children-2].Slot.Padding.Top==1,
            'fitting preserves native numeric slot padding')
    end
end
nativePal.Text_Efefct:SetText('Nombre max de Pals actifs à la base')
nativeBase.Text_Efefct:SetText('Nombre de bases pouvant être construites')
for _,width in ipairs({520,588,632}) do
    for _,dpi in ipairs({2/3,1,4/3}) do assertRewardLayout({nativePal,nativeBase},width,dpi) end
end
local titleCount=titleBoxes
for i=1,25 do UI.refresh() end
assert(titleBoxes==titleCount,'idle refresh must not wrap titles again')
print('PASS: long titles fit without shifting native arrows; allocation at three widths and DPI scales, no idle wrapping')
local initialWidth=nativeBase.SizeBox_Aft.WidthOverride
local steady,layouts=writes,prepasses
for i=1,25 do UI.refresh() end
assert(created==1 and constructed==8 and writes==steady and prepasses==layouts, 'steady UI must not rebuild, repaint or measure')
for i=1,10 do
    reconstruct(w)
    assert(w.Text_Efefct.value=='Base Range Bonus' and w.Image_Icon.texture==texture)
    assert(w.Text_Num_Pre.value=='45' and unit(w,'Text_Num_Pre').value=='%')
    assert(note(w,'Text_Num_Pre').value=='50.8m' and note(w,'Text_Num_Pre').Font.Size==9)
    assertTextAlignment(w)
end
reconstruct(nativePal)
assert(nativePal.Text_Efefct.value=='None' and nativePal.Text_Num_Pre.Font.Size==20,
    'do not replace native content, fonts or Construct behavior')
UI.refresh()
steady,layouts=writes,prepasses
-- Closing/reconstructing Slate must not consume zero measurements.
local beforeClosedWidth=nativeBase.SizeBox_Aft.WidthOverride
local beforeClosedBalance=w.Text_Num_Pre:GetParent():GetChildAt(0).size.X
screen.active=false
for _,field in ipairs({'Text_Num_Pre','Text_Num_Aft'}) do
    w[field].unmeasurable=true;unit(w,field).unmeasurable=true;note(w,field).unmeasurable=true
end
UI.refresh()
assert(writes==steady and prepasses==layouts,'closed-screen refresh does no layout work')
assert(nativeBase.SizeBox_Aft.WidthOverride==beforeClosedWidth)
assert(w.Text_Num_Pre:GetParent():GetChildAt(0).size.X==beforeClosedBalance)
-- The opening frame can also be unmeasurable. Keep all previous sizes until
-- BOTH current/next measurements are ready, then retry without a value change.
screen.active=true;reconstruct(w);UI.refresh()
assert(nativeBase.SizeBox_Aft.WidthOverride==beforeClosedWidth)
for _,field in ipairs({'Text_Num_Pre','Text_Num_Aft'}) do
    w[field].unmeasurable=false;unit(w,field).unmeasurable=false;note(w,field).unmeasurable=false
end
note(w,'Text_Num_Aft').unmeasurable=true
-- Retry pending layout with a wider first value and an unmeasurable second.
local getSize=unit(w,'Text_Num_Pre').GetDesiredSize
unit(w,'Text_Num_Pre').GetDesiredSize=function() return {X=70,Y=13} end
UI.refresh()
assert(w.Text_Num_Pre:GetParent():GetChildAt(0).size.X==beforeClosedBalance,
    'partial measurements must not change the first spacer before the second value is ready')
unit(w,'Text_Num_Pre').GetDesiredSize=getSize
note(w,'Text_Num_Aft').unmeasurable=false
UI.refresh()
assert(nativeBase.SizeBox_Aft.WidthOverride==beforeClosedWidth and current()==w and created==1)
assertCentred(w)
steady,layouts=writes,prepasses;UI.refresh()
assert(writes==steady and prepasses==layouts,'successful deferred measurement returns to idle')
snapshot.radius=5080;snapshot.currentPercent=5080/3500*100;snapshot.nextPercent=146.25
UI.refresh()
assert(w.Text_Num_Pre.value=='45' and note(w,'Text_Num_Pre').value=='50.8m', 'metres use actual radius, not rounded percentages')
assert(note(w,'Text_Num_Aft').value=='51.2m')
snapshot.baseline=4000;snapshot.radius=5800;snapshot.currentPercent=145;snapshot.nextPercent=150
UI.refresh()
assert(note(w,'Text_Num_Pre').value=='58m' and note(w,'Text_Num_Aft').value=='60m', 'respect nonstandard native baseline')
assert(nativeBase.SizeBox_Aft.WidthOverride<initialWidth, 'shorter metres must let arrows move back right, not keep the previous widest grid')
assertCentred(w)
-- When the full annotation fits, preserve the original native columns exactly.
snapshot.baseline=100;snapshot.radius=100;snapshot.currentPercent=100;snapshot.nextPercent=100
UI.refresh()
assert(note(w,'Text_Num_Pre').value=='1m' and nativeBase.SizeBox_Aft.WidthOverride==72,
    'restore native arrow position whenever the measured text fits')
assertCentred(w)
snapshot.baseline=3500;snapshot.radius=3500;snapshot.currentPercent=100;snapshot.nextPercent=105
UI.refresh()
assert(w.Text_Num_Pre.value=='0' and w.Text_Num_Aft.value=='5')
assert(note(w,'Text_Num_Pre').value=='35m' and note(w,'Text_Num_Aft').value=='36.8m')
assertCentred(w)
snapshot.radius=3675;snapshot.currentPercent=105;snapshot.nextPercent=110
UI.refresh()
assert(w.Text_Num_Pre.value=='5' and w.Text_Num_Aft.value=='10')
assert(note(w,'Text_Num_Pre').value=='36.8m' and note(w,'Text_Num_Aft').value=='38.5m')
assertCentred(w)
snapshot.radius=7000;snapshot.currentPercent=200;snapshot.nextPercent=200
UI.refresh()
assert(w.Text_Num_Pre.value=='100' and note(w,'Text_Num_Pre').value=='70m')
assertCentred(w)
snapshot.radius=13825;snapshot.currentPercent=395;snapshot.nextPercent=400
UI.refresh()
assert(w.Text_Num_Pre.value=='295' and w.Text_Num_Aft.value=='300')
assert(note(w,'Text_Num_Pre').value=='138.3m' and note(w,'Text_Num_Aft').value=='140m')
assertCentred(w)
snapshot.nextPercent=nil
UI.refresh()
assert(w.Text_Num_Aft.value=='' and unit(w,'Text_Num_Aft').value=='' and note(w,'Text_Num_Aft').value=='')
assert(w.Image_Arrow.visibility==2 and w.SizeBox_Aft.visibility==2, 'missing preview hides both next values without collapsing the grid')
snapshot.nextPercent=145;screen.CanLevelup=true
UI.refresh();assert(w.Image_Arrow.visibility==4 and w.SizeBox_Aft.visibility==4)
assert(unit(w,'Text_Num_Aft').value=='%' and unit(w,'Text_Num_Aft').RenderOpacity==1)
assert(note(w,'Text_Num_Aft').color==w.Text_Num_Aft.ColorAndOpacity,
    'ready next metres inherit native upgrade turquoise')
assert(note(w,'Text_Num_Pre').color.SpecifiedColor.R==0.27,'current metres stay mint')
screen.CanLevelup=false;UI.refresh()
assert(note(w,'Text_Num_Aft').color.SpecifiedColor.R==0.27,'next metres return to mint when not ready')
snapshot.atMaximum=true
UI.refresh();assert(w.SizeBox_Aft.visibility==2)
w:RemoveFromParent()
UI.refresh()
assert(created==2 and #parent.children==3 and current().Text_Efefct.value=='Base Range Bonus', 'rebuild only a missing mod row')
snapshot.atMaximum=false;snapshot.chestCurrent=9;snapshot.chestNext=10
UI.refresh()
local chest=parent.children[4]
assert(created==3 and constructed==16 and chest.Text_Efefct.value=='Bonus Chest Slots')
assert(chest.Text_Num_Pre.value=='9' and chest.Text_Num_Aft.value=='10')
assert(rewardSection.Slot.position.Y+rewardSection.Slot.size.Y==300,'bottom separator stays fixed')
assert(rewardSection.Slot.position.Y==112,'fourth row shifts the complete title/reward group by one native row')
assert(chest.Image_Icon.texture==texture and chest.SizeBox_Aft.WidthOverride==nativeBase.SizeBox_Aft.WidthOverride)
for _,width in ipairs({520,588,632}) do
    for _,dpi in ipairs({2/3,1,4/3}) do
        assertRewardLayout({nativePal,nativeBase,current(),chest},width,dpi)
    end
end
-- Reproduce upgrade -> close -> reopen before the preview packet. Keep both
-- complete rewards, then replace them together when metadata catches up.
local retained=current()
local beforeUpgradeY=rewardSection.Slot.position.Y
local pendingSnapshot={}
for k,v in pairs(snapshot) do pendingSnapshot[k]=v end
snapshot=pendingSnapshot -- Runtime.snapshot returns a new value, not a mutable singleton.
snapshot.previewPending=true;snapshot.nextPercent=nil;snapshot.chestCurrent=nil;snapshot.chestNext=nil
UI.refresh();screen.active=false;UI.refresh();screen.active=true
reconstruct(retained);reconstruct(chest);UI.refresh()
assert(chest.visibility==4 and chest.Text_Num_Pre.value=='9' and chest.Text_Num_Aft.value=='10',
    'a missing preview must not collapse or blank the chest reward on reopening')
assert(retained.SizeBox_Aft.visibility==4 and rewardSection.Slot.position.Y==beforeUpgradeY,
    'pending replication preserves the last complete range and section layout')
snapshot.previewPending=false;snapshot.currentPercent=150;snapshot.nextPercent=155;snapshot.radius=5250
snapshot.chestCurrent=10;snapshot.chestNext=11
UI.refresh()
assert(current()==retained and chest==parent.children[4] and created==3,'upgrade reuses existing reward widgets')
assert(retained.Text_Num_Pre.value=='50' and retained.Text_Num_Aft.value=='55')
assert(chest.Text_Num_Pre.value=='10' and chest.Text_Num_Aft.value=='11','both new rewards appear together')
-- Slots are spread over the levels, so an upgrade can keep the same number.
-- Show both values and the arrow, as the game does for an unchanged reward.
snapshot.chestCurrent=1;snapshot.chestNext=1;UI.refresh()
assert(chest.Text_Num_Pre.value=='1' and chest.Text_Num_Aft.value=='1')
assert(chest.Image_Arrow.visibility==4 and chest.SizeBox_Aft.visibility==4,'an unchanged next value stays visible')
snapshot.chestNext=2;UI.refresh()
assert(chest.Text_Num_Pre.value=='1' and chest.Text_Num_Aft.value=='2','the following level shows its new slot')
snapshot.chestCurrent=0;snapshot.chestNext=0;UI.refresh()
assert(chest.visibility==4 and chest.Text_Num_Pre.value=='0' and chest.Text_Num_Aft.value=='0',
    'a small cap that starts later keeps its row')
snapshot.chestCurrent=20;snapshot.chestNext=20;UI.refresh()
assert(chest.Text_Num_Pre.value=='20' and chest.Text_Num_Aft.value=='20','cap stops slot growth')
snapshot.atMaximum=true;UI.refresh();assert(chest.SizeBox_Aft.visibility==2)
snapshot.rangeEnabled=false;snapshot.chestCurrent=nil;snapshot.chestNext=nil
UI.refresh()
assert(current().visibility==1 and chest.visibility==1,'disabled bonuses collapse their reward rows')
assert(rewardSection.Slot.position.Y==148,'disabled bonuses restore the original section position')
assert(nativeBase.SizeBox_Aft.WidthOverride==72,'disabled annotations restore native columns')
reconstruct(chest)
snapshot.rangeEnabled=true;snapshot.chestCurrent=9;snapshot.chestNext=10;snapshot.atMaximum=false
UI.refresh()
assert(current().visibility==4 and chest.visibility==4 and created==3,'reenable without duplicating widgets')
reconstruct(chest);assert(chest.Text_Efefct.value=='Bonus Chest Slots' and chest.Text_Num_Aft.value=='10')
FindAllOf=function() return {} end
UI.refresh();reconstruct(current())
assert(current().Text_Efefct.value=='None', 'release ownership after the screen disappears')
print('PASS: centred digits with percent suffix, native unit styling, gain-only values, parenthesis-free metres, smaller mint notes, native/minimum-fit arrow positions, font isolation, shared columns, reconstruction, stable refresh, max/missing preview, tree cleanup')

-- The ground marker is told the same next radius the range row prints, from
-- the same values, or false when the screen has no larger radius to announce.
local marks={}
FindAllOf=function() return {screen} end
E.boundary={mark=function(base,target,radius) marks[#marks+1]={base=base,screen=target,radius=radius} end}
local function marked(values)
    local fresh={}
    for k,v in pairs(snapshot) do fresh[k]=v end
    for k,v in pairs(values) do if v=='none' then fresh[k]=nil else fresh[k]=v end end
    snapshot=fresh
    local before=#marks
    UI.refresh()
    assert(#marks<=before+1,'one report per open screen and refresh')
    return marks[#marks],#marks-before
end
local last,count=marked({baseline=3500,radius=4725,currentPercent=135,nextPercent=140,atMaximum=false,
    rangeEnabled=true,previewPending=false})
assert(count==1 and last.base==model and last.screen==screen and last.radius==4900,
    'the marker gets baseline x next percent, for this screen and its base')
last=marked({rangeEnabled='none'})
assert(last.radius==4900,'a server that sent no switch still announces its next radius')
last=marked({nextPercent=135.02})
assert(last.radius==false,'a next radius within a centimetre of the current one is not a larger boundary')
last=marked({nextPercent=135})
assert(last.radius==false,'neighbours can leave nothing to gain')
last=marked({nextPercent='none'})
assert(last.radius==false,'no next value, no marker')
last=marked({nextPercent=140,atMaximum=true})
assert(last.radius==false,'nothing after the last level')
last=marked({atMaximum=false,rangeEnabled=false})
assert(last.radius==false,'range bonus off, no marker')
last,count=marked({rangeEnabled=true,previewPending=true})
assert(count==0,'values still arriving leave the marker as it is')
last,count=marked({previewPending=false})
assert(count==1 and last.radius==4900)
screen.active=false
last,count=marked({})
assert(count==0,'a closed screen reports nothing; the marker notices the close itself')
screen.active=true
E.boundary={}
UI.refresh()
E.boundary=nil
UI.refresh()
print('PASS: the reward rows report the next radius to the ground marker, false when there is none, nothing while values arrive')

-- Row titles follow the game's language, also when it changes while the screen
-- is open; the log keeps its English names.
local function rowTitled(title)
    -- The newest match: rows of a screen that went away stay in this mock's list.
    for i=#parent.children,1,-1 do
        if parent.children[i].Text_Efefct.value==title then return parent.children[i] end
    end
end
local logged={}
E.log=function(message) logged[#logged+1]=message end
local rangeRow,chestRow=rowTitled('Base Range Bonus'),rowTitled('Bonus Chest Slots')
assert(rangeRow and chestRow and rangeRow~=chestRow)
language='fr';UI.refresh()
assert(rangeRow.Text_Efefct.value=='Bonus de rayon de la base' and chestRow.Text_Efefct.value=='Emplacements de coffre bonus',
    'a language changed in the options repaints both titles')
local quiet,measured=writes,prepasses
UI.refresh();UI.refresh()
assert(writes==quiet and prepasses==measured,'a translated title is not repainted on every refresh')
reconstruct(rangeRow);reconstruct(chestRow)
assert(rangeRow.Text_Efefct.value=='Bonus de rayon de la base' and chestRow.Text_Efefct.value=='Emplacements de coffre bonus',
    'a rebuilt row keeps the current language')
language='ja';UI.refresh()
assert(rangeRow.Text_Efefct.value==Texts.get('ja').rangeRow and chestRow.Text_Efefct.value==Texts.get('ja').chestRow)
assertRewardLayout({nativePal,nativeBase,rangeRow,chestRow},588,2/3)
language='en';UI.refresh()
assert(rangeRow.Text_Efefct.value=='Base Range Bonus' and chestRow.Text_Efefct.value=='Bonus Chest Slots')
FindAllOf=function() return {} end
UI.refresh()
FindAllOf=function() return {screen} end
language='de';UI.refresh()
local born,bornChest=rowTitled(Texts.get('de').rangeRow),rowTitled(Texts.get('de').chestRow)
assert(born and bornChest and born~=rangeRow and bornChest~=chestRow,'new rows are born in the current language')
local english=0
for _,message in ipairs(logged) do
    if message=='Base Range Bonus row added' or message=='Bonus Chest Slots row added' then english=english+1 end
    assert(not message:find('Lagerradius',1,true),'log lines stay in English')
end
assert(english==2,'the log names the two rows in English whatever the language')
print('PASS: reward row titles follow the game language at once, stay steady, survive a rebuild; the log stays English')

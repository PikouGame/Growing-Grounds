local root = assert(arg[1])
local function obj(t) t.IsValid=function() return true end; return t end
local function widget(t)
    t=t or {}
    t.GetParent=function(self) return self.parent end
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
            return {X=self.value=='%' and self.Font.Size*0.75 or #self.value*self.Font.Size*0.5,Y=self.Font.Size}
        end})
end
local function panel(width)
    local p=widget({children={},WidthOverride=width})
    p.GetChildrenCount=function(self) return #self.children end
    p.GetChildAt=function(self,i) return self.children[i+1] end
    p.AddChild=function(self,child)
        child:RemoveFromParent();child.parent=self;self.children[#self.children+1]=child
        child.Slot={Padding={Left=0,Right=0,Top=0,Bottom=0},SetPadding=function(slot,v) slot.padding=v;slot.Padding=v end,
            SetVerticalAlignment=function(slot,v) slot.vertical=v end,
            SetHorizontalAlignment=function(slot,v) slot.horizontal=v end}
        return child.Slot
    end
    p.AddChildToHorizontalBox=p.AddChild
    p.SetWidthOverride=function(self,v) self.WidthOverride=v end
    p.GetDesiredSize=function(self)
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
    local preBox,aftBox=panel(72),panel(72)
    preBox:AddChild(pre);aftBox:AddChild(aft)
    return widget({GetFullName=function() return name end,WidgetTree=obj({}),
        Text_Efefct=label(),Text_Num_Pre=pre,Text_Num_Aft=aft,
        Image_Icon=widget({SetBrushFromTexture=function(self,v) self.texture=v end}),
        Image_Arrow=widget(),SizeBox_Aft=aftBox,
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
local constructed=0
StaticConstructObject=function(class,outer,name)
    assert(outer:IsValid() and name:match('GG_Text_Num_'))
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

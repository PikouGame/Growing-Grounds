local root = assert(arg[1])
local function obj(t) t.IsValid=function() return true end; return t end
local function label()
    return {value='',SetText=function(self,v) self.value=v end,
        GetText=function(self) return {ToString=function() return self.value end} end}
end
local function visibility() return {SetVisibility=function(self,v) self.visibility=v end} end
local hook,created,writes= nil,0,0
local children={}
local texture=obj({})
local function row(name)
    return obj({GetFullName=function() return name end,Text_Efefct=label(),Text_Num_Pre=label(),Text_Num_Aft=label(),
        Image_Icon={SetBrushFromTexture=function(self,v) self.texture=v end},
        Image_Arrow=visibility(),SizeBox_Aft=visibility(),
        SetEffectInfo=function() writes=writes+1 end})
end
local function reconstruct(widget)
    -- Reproduce the observed game lifecycle: native Construct overwrites
    -- presentation using the backing Texture and empty localization handle.
    widget.Text_Efefct:SetText('None')
    widget.Image_Icon:SetBrushFromTexture(widget.Texture)
    hook({get=function() return widget end})
end
local parent=obj({GetChildrenCount=function() return #children end,
    GetChildAt=function(_,i) return children[i+1] end,
    AddChildToVerticalBox=function(_,widget)
        assert(widget.Texture==texture, 'texture must exist before first Construct')
        children[#children+1]=widget
        reconstruct(widget)
        return {SetPadding=function() end}
    end})
local model=obj({IsAvailable=function() return true end})
local screen=obj({CanLevelup=false,GetFullName=function() return 'screen' end,
    GetBaseCampModel=function() return model end,GetOwningPlayer=function() return obj({}) end,
    WBP_IngameMenu_MissionLevelEffect_1=obj({GetParent=function() return parent end})})
local class=obj({})
local library={Create=function() created=created+1; return row('row'..created) end}
StaticFindObject=function(path)
    if path:find('WidgetBlueprintLibrary',1,true) then return library end
    if path:find('KismetRenderingLibrary',1,true) then return {ImportFileAsTexture2D=function() return texture end} end
    return class
end
RegisterHook=function(_,fn) assert(not hook, 'duplicate Construct hook'); hook=fn end
FText=function(v) return v end
FindAllOf=function() return {screen} end
local snapshot={currentPercent=135,nextPercent=140,atMaximum=false}
local E={root=root,log=function() end,guard=function(_,fn) fn() end,valid=function(o) return o and o:IsValid() end}
local UI=dofile(root..'src/ui.lua')(E,{snapshot=function() return snapshot end})
UI.refresh()
assert(created==1 and children[1].Text_Efefct.value=='Base Range')
assert(children[1].Image_Icon.texture==texture)
assert(children[1].Text_Num_Pre.value=='135%' and children[1].Text_Num_Aft.value=='140%')
local steady=writes
for i=1,25 do UI.refresh() end
assert(created==1 and writes==steady, 'unchanged UI must not rebuild or rewrite')
for i=1,10 do
    reconstruct(children[1])
    assert(children[1].Text_Efefct.value=='Base Range' and children[1].Image_Icon.texture==texture)
end
local vanilla=row('vanilla')
reconstruct(vanilla)
assert(vanilla.Text_Efefct.value=='None', 'must not modify native reward rows')
snapshot.currentPercent=140; snapshot.nextPercent=145
UI.refresh(); assert(children[1].Text_Num_Pre.value=='140%' and children[1].Text_Num_Aft.value=='145%')
snapshot.nextPercent=nil
UI.refresh()
assert(children[1].Text_Num_Aft.value=='' and children[1].Image_Arrow.visibility==2
    and children[1].SizeBox_Aft.visibility==2,'unavailable preview preserves both native column widths without a placeholder')
snapshot.nextPercent=145
UI.refresh()
assert(children[1].Image_Arrow.visibility==4 and children[1].SizeBox_Aft.visibility==4)
snapshot.atMaximum=true
UI.refresh(); assert(children[1].SizeBox_Aft.visibility==2)
children={} -- Same screen name with a newly rebuilt widget tree.
UI.refresh(); assert(created==2 and #children==1 and children[1].Text_Efefct.value=='Base Range')
print('PASS: initial/deferred reconstruction, icon retention, stable refresh, isolated native rows, level/max updates, rebuilt tree')

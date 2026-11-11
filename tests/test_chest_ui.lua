local root=assert(arg[1])
local make=dofile(root..'src/chest_ui.lua')
local created,writes,logs,errors=0,0,{},{}
local failAttach=false
local function copy(v)
    if type(v)~='table' then return v end
    local result={};for k,x in pairs(v) do result[k]=copy(x) end;return result
end
local function slot(parent,child)
    local s={parent=parent,child=child,Padding={Left=0,Top=0,Right=0,Bottom=0},HorizontalAlignment=0,VerticalAlignment=0}
    for _,name in ipairs({'Padding','HorizontalAlignment','VerticalAlignment','Size'}) do
        s['Set'..name]=function(self,value) self[name]=copy(value) end
    end
    return s
end
local function widget(name,class)
    local w={name=name,class=class,alive=true,children={},visibility=4}
    function w:IsValid() return self.alive end
    function w:GetFullName() return self.name end
    function w:IsA(c) return self.class==c end
    function w:GetParent() return self.parent end
    function w:RemoveFromParent()
        if self.parent then
            for i,c in ipairs(self.parent.children) do if c==self then table.remove(self.parent.children,i);break end end
        end
        self.parent=nil
    end
    function w:AddChild(child)
        if failAttach and self.class=='/Script/UMG.VerticalBox' and child.isGrid then error('simulated attach failure') end
        child:RemoveFromParent();child.parent=self;self.children[#self.children+1]=child
        child.Slot=slot(self,child);return child.Slot
    end
    w.AddChildToOverlay=w.AddChild;w.AddChildToVerticalBox=w.AddChild
    function w:SetFont(font) self.Font=copy(font) end
    function w:SetText(value) self.text=value;writes=writes+1 end
    function w:SetVisibility(value) self.visibility=value end
    for _,field in ipairs({'Stretch','StretchDirection','ColorAndOpacity','ShadowColorAndOpacity','ShadowOffset'}) do
        w['Set'..field]=function(self,value) self[field]=copy(value) end
    end
    return w
end
FName=function(v) return v end;FText=function(v) return v end
StaticConstructObject=function(class,_,name) created=created+1;return widget('Created'..created..'.'..name,class) end
local function container(number,total)
    local c=widget('Container'..number,'container');c.total=total
    function c:Num() return self.total end
    function c:GetId() return {ID={A=number,B=0,C=0,D=0}} end
    return c
end
local function chest(name,native,total)
    local screen=widget(name,'screen');screen.active=true
    function screen:IsActivated() return self.active end
    local view=widget(name..'.View','view');screen.WBP_IngameMenu_Chest=view
    view.WidgetTree={};view.TargetContainer=container(1,total);view['Display Slot Num Default']=native
    screen.TargetContainerId=view.TargetContainer:GetId()
    local overlay=widget(name..'.Overlay','/Script/UMG.Overlay')
    local grid=widget(name..'.Grid','grid');grid.isGrid=true
    overlay:AddChild(grid):SetPadding({Left=0,Top=-5,Right=0,Bottom=-20})
    view.WBP_PalItemScrollList=grid
    view.Text_TargetContainerName=widget(name..'.Title','text')
    view.Text_TargetContainerName.Font={Size=20,TypefaceFontName='Regular'}
    view.Text_TargetContainerName.ShadowOffset={X=1,Y=1}
    view.Text_TargetContainerName.ShadowColorAndOpacity={R=0,G=0,B=0,A=1}
    return screen,view,overlay,grid
end
local screens,tracked,scans={},nil,0
local culture='en'
local texts=dofile(root..'src/texts.lua')
local E={valid=function(o) return o and o:IsValid() end,texts=function() return texts.get(culture) end,
    log=function(s) logs[#logs+1]=s end,guard=function(_,fn) local ok,err=pcall(fn);if not ok then errors[#errors+1]=err end;return ok end,
    objects={find=function(s) return s end,all=function(name) assert(name=='WBP_ItemChest_C');scans=scans+1;return screens end,
        tracked=function(name) assert(name=='WBP_ItemChest_C');return tracked end}}
local C=make(E)
C.check();assert(scans==0,'frequent observer cannot start discovery')
local screen,view,overlay,grid=chest('Chest',24,34)
screens={screen};C.refresh();tracked=screens
assert(#errors==0,table.concat(errors,';'))
assert(created==3 and grid:GetParent().class=='/Script/UMG.VerticalBox')
local stack=grid:GetParent();local fit=stack.children[1];local label=fit.children[1]
assert(label.text=='24 + 10 slots' and label.Font.Size==15 and view.Text_TargetContainerName.Font.Size==20)
assert(stack.Slot.Padding.Top==-5 and stack.Slot.Padding.Bottom==-20 and grid.Slot.Size.SizeRule==1,
    'native overlay bounds preserved; grid fills remaining height')
for _=1,100 do C.check() end
assert(created==3 and writes==1 and scans==1,'stable open chest never repaints, rebuilds or globally scans')
view.TargetContainer.total=39;C.check()
assert(label.text=='24 + 15 slots','retained overflow uses actual slots, not a policy estimate')
culture='fr';C.check();assert(label.text=='24 + 15 emplacements')
screen.active=false;C.check();assert(fit.visibility==1)
screen.active=true;C.check();assert(fit.visibility==4 and created==3,'reopen reuses widgets')
-- New target with a still-old container must not show stale counts.
screen.TargetContainerId={ID={A=2,B=0,C=0,D=0}};C.check();assert(fit.visibility==1)
view.TargetContainer=container(2,64);view['Display Slot Num Default']=54;C.check()
assert(label.text=='54 + 10 emplacements' and fit.visibility==4,'Guild Chest uses its native size once')
for _,value in ipairs({0,-1,1.5,math.huge,'54'}) do
    view['Display Slot Num Default']=value;C.check();assert(fit.visibility==1)
end
view['Display Slot Num Default']=54;view.TargetContainer.total=54;C.check();assert(fit.visibility==1,'no extra slots hides the annotation')
view.TargetContainer.total=53;C.check();assert(fit.visibility==1,'incoherent shrink is not a negative bonus')
view.TargetContainer.total=64;C.check()
local beforeDestroyed=writes
screen.alive=false;C.check();assert(fit.visibility==1 and writes==beforeDestroyed,'destroyed screen is forgotten')
local failed,fview,fparent,fgrid=chest('Failed',10,20)
screens={failed};failAttach=true;C.refresh()
assert(#errors==1 and fgrid:GetParent()==fparent and fgrid.Slot.Padding.Top==-5,
    'attachment failure restores the original grid and slot')
failAttach=false;C.refresh();assert(fgrid:GetParent().class=='/Script/UMG.VerticalBox','later attempt can recover')
assert(view.TargetContainer.total==64,'presentation never changes capacity')
print('PASS: native/extra counts, Guild Chest, late replication, overflow, reusable fitted layout, no idle writes/scans, cleanup and rollback')

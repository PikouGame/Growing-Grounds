-- Capacity of the open chest, from its native UI/container data. Presentation
-- only: no inventory writes, policy guesses or new replication requests.
return function(E)
    local C,attached,capacities={},{},{}
    local function integer(n) return type(n)=='number' and n>0 and n<math.huge and n%1==0 end
    local function same(a,b) return E.valid(a) and E.valid(b) and a:GetFullName()==b:GetFullName() end
    local function hide(record)
        if record and not record.hidden and E.valid(record.fit) then
            record.fit:SetVisibility(1);record.hidden=true
        end
        if record then record.written=nil end
    end
    local function id(value)
        local g=value.ID
        return table.concat({g.A,g.B,g.C,g.D},':')
    end
    local function nativeCapacity(screen,container)
        local key=screen:GetFullName()
        local cached=capacities[key]
        if cached and same(cached.container,container) then return cached.native end
        local native
        if container.bIsGuildChestContainer then
            local settings=E.objects.find('/Script/Pal.Default__PalUtility'):GetGameSetting(screen)
            if E.valid(settings) then native=settings.GuildChestSlotNum end
        else
            -- The UI's Display Slot Num Default can be -1 (use actual size).
            -- Read the same native actor parameter used by server storage.
            local param=screen:GetParam()
            if not E.valid(param) then return end
            local model=param.MapObjectConcreteModel
            if not E.valid(model) then return end
            local actor=model:GetActor()
            local class=E.objects.find('/Script/Pal.PalMapObjectItemChestParameterComponent')
            if not E.valid(actor) or not E.valid(class) then return end
            for _,entry in ipairs(actor:K2_GetComponentsByClass(class)) do
                local component=entry:get()
                if E.valid(component) and integer(component.SlotNum) then native=component.SlotNum;break end
            end
        end
        if not integer(native) then return end
        capacities[key]={container=container,native=native}
        return native
    end
    function C.values(screen)
        local view=screen.WBP_IngameMenu_Chest
        if not E.valid(view) then return end
        local container=view.TargetContainer
        if not E.valid(container) then return end
        -- During a switch, the previous container may still be on the widget.
        if id(container:GetId())~=id(screen.TargetContainerId) then return end
        local native=nativeCapacity(screen,container)
        if not native then return end
        local total=container:Num()
        if not integer(total) or total<=native then return end
        return native,total-native,view
    end
    local function attach(view)
        local grid,title=view.WBP_PalItemScrollList,view.Text_TargetContainerName
        assert(E.valid(grid) and E.valid(title),'Chest grid/title unavailable')
        local parent=grid:GetParent()
        assert(E.valid(parent) and parent:IsA('/Script/UMG.Overlay'),'Unexpected chest grid parent')
        local old=grid.Slot
        local p=old.Padding
        local padding={Left=p.Left,Top=p.Top,Right=p.Right,Bottom=p.Bottom}
        local horizontal,vertical=old.HorizontalAlignment,old.VerticalAlignment
        local function make(class,name)
            local widget=StaticConstructObject(E.objects.find('/Script/UMG.'..class),view.WidgetTree,FName(name))
            assert(E.valid(widget),'Cannot create chest capacity '..class)
            return widget
        end
        local stack=make('VerticalBox','GG_ChestCapacityStack')
        local fit=make('ScaleBox','GG_ChestCapacityFit')
        local label=make('TextBlock','GG_ChestCapacity')
        label:SetFont(title.Font)
        label.Font.Size=math.max(1,math.floor(title.Font.Size*0.75+0.5))
        label:SetFont(label.Font)
        label:SetColorAndOpacity({SpecifiedColor={R=0.27,G=0.78,B=0.60,A=1},ColorUseRule=0})
        label:SetShadowColorAndOpacity(title.ShadowColorAndOpacity)
        label:SetShadowOffset(title.ShadowOffset)
        label:SetVisibility(4)
        fit:SetStretch(2);fit:SetStretchDirection(1) -- fit down only
        fit:SetVisibility(4);stack:SetVisibility(4)
        fit:AddChild(label):SetHorizontalAlignment(1)
        local heading=stack:AddChildToVerticalBox(fit)
        heading:SetSize({Value=1,SizeRule=0}) -- Auto
        heading:SetPadding({Left=8,Top=4,Right=8,Bottom=4})
        -- Preserve the native overlay slot; the scroll area takes the remaining
        -- height, so the footer, scrollbar and controller targets stay native.
        grid:RemoveFromParent()
        local ok,err=pcall(function()
            local slot=stack:AddChildToVerticalBox(grid)
            slot:SetSize({Value=1,SizeRule=1}) -- Fill
            slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
            local outer=parent:AddChildToOverlay(stack)
            outer:SetPadding(padding);outer:SetHorizontalAlignment(horizontal);outer:SetVerticalAlignment(vertical)
        end)
        if not ok then
            grid:RemoveFromParent();stack:RemoveFromParent()
            local restore=parent:AddChildToOverlay(grid)
            restore:SetPadding(padding);restore:SetHorizontalAlignment(horizontal);restore:SetVerticalAlignment(vertical)
            error(err)
        end
        return {view=view,grid=grid,stack=stack,label=label,fit=fit}
    end
    local function update(screen)
        local key=screen:GetFullName()
        local record=attached[key]
        if not screen:IsActivated() then hide(record);return end
        local native,bonus,view=C.values(screen)
        if not native then hide(record);return end
        if record and (not same(record.view,view) or not E.valid(record.stack) or not E.valid(record.grid)
                or not same(record.grid:GetParent(),record.stack)) then
            hide(record);attached[key]=nil;record=nil
        end
        if not record then record=attach(view);attached[key]=record end
        local value=string.format(E.texts().chestCapacity,native,bonus)
        if record.written~=value then
            record.label:SetText(FText(value))
            record.label:SetVisibility(4);record.fit:SetVisibility(4)
            record.written=value;record.hidden=false
            E.log(string.format('chest capacity label: %d + %d slots',native,bonus))
        end
    end
    local function visit(screens)
        local live={}
        for _,screen in ipairs(screens or {}) do
            if E.valid(screen) then
                local key=screen:GetFullName();live[key]=true
                if not E.guard('chest capacity label',function() update(screen) end) then hide(attached[key]) end
            end
        end
        for key,record in pairs(attached) do
            if not live[key] then hide(record);attached[key]=nil end
        end
        for key in pairs(capacities) do if not live[key] then capacities[key]=nil end end
    end
    function C.refresh() visit(E.objects.all('WBP_ItemChest_C')) end
    function C.check()
        local screens=E.objects.tracked('WBP_ItemChest_C')
        if screens then visit(screens) end -- no global scan on the frequent observer
    end
    return C
end

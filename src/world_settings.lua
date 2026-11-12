-- Native rows in World Settings. Drafts live only in this menu; saving follows
-- the game's successful-save event, never a slider movement or closing/cancel.
return function(E)
    local W = {}
    local menuPath = '/Game/Pal/Blueprint/UI/UserInterface/Title/WBP_Title_WorldSettings.WBP_Title_WorldSettings_C'
    local rowPath = '/Game/Pal/Blueprint/UI/UserInterface/Title/WBP_Title_WorldSettings_ListContent.WBP_Title_WorldSettings_ListContent_C'
    local outerPath = '/Game/Pal/Blueprint/UI/Title/WBP_WorldSetting.WBP_WorldSetting_C'
    local screens, owned, sliders, hooks = {}, {}, {}, {}
    local fields = {
        -- title and tip are keys of the texts, read in the game's language at each paint.
        {key='growthPercentPerLevel', title='rangeGrowthTitle', tip='rangeGrowthTip', min=0, max=E.range.limits.growthPercentPerLevel, step=1},
        {key='maxRangeBonusPercent', title='rangeCapTitle', tip='rangeCapTip', min=0, max=E.range.limits.maxRangeBonusPercent, step=1},
        {key='maxChestBonusSlots', title='chestCapTitle', tip='chestCapTip', min=0, max=E.range.limits.maxChestBonusSlots, step=E.range.chestSlotStep},
        {key='startingPalboxBoxes', title='palboxStartTitle', tip='palboxStartTip', min=1, max=E.range.limits.maxPalboxBoxes, step=1},
        {key='maxPalboxBoxes', title='palboxCapTitle', tip='palboxCapTip', min=1, max=E.range.limits.maxPalboxBoxes, step=1},
    }
    local function object(path) return E.objects.find(path) end
    local function stringValue(value)
        return type(value)=='string' and value or value:ToString()
    end
    local function paint(row, spec, value)
        local texts=E.texts()
        row.Text_OptionTitle:SetText(FText(texts[spec.title]))
        row:SetToolTipText(FText(texts[spec.tip]))
        if value~=nil then
            local display=value==0 and texts.off or ((spec.key=='maxRangeBonusPercent' or spec.key=='growthPercentPerLevel') and string.format('+%g%%',value) or tostring(value))
            row.WBP_OptionSettings_ListContentSlider.BP_PalTextBlock_Value:SetText(FText(display))
        end
    end
    local function findChild(panel, path)
        if not path then return end
        for i=0,panel:GetChildrenCount()-1 do
            local child = panel:GetChildAt(i)
            if E.valid(child) and child:GetFullName()==path then return child end
        end
    end
    local function forgetRow(path)
        local entry=path and owned[path]
        if not entry then return end
        sliders[entry.slider]=nil
        owned[path]=nil
    end
    local function positionGroup(menu,state,panel)
        if state.positioned then return end
        local anchor=E.valid(menu.WorldSettings_MaxBuildingLimitNum) and menu.WorldSettings_MaxBuildingLimitNum
            or menu.WorldSettings_BaseCampWorkerNum
        local anchorName=anchor:GetFullName()
        local own,group,tail={},{},{}
        for _,spec in ipairs(fields) do
            local name=state.rows[spec.key]
            own[name]=true;group[#group+1]=assert(findChild(panel,name),'Missing mod setting row')
        end
        local anchorIndex
        for i=0,panel:GetChildrenCount()-1 do
            if panel:GetChildAt(i):GetFullName()==anchorName then anchorIndex=i;break end
        end
        if not anchorIndex then return end
        -- Keep the game's caution text attached to its own setting.
        while anchorIndex+1<panel:GetChildrenCount() and
                panel:GetChildAt(anchorIndex+1):GetFullName():find('Overlay_Caution_',1,true) do
            anchorIndex=anchorIndex+1
        end
        local already=true
        for i,row in ipairs(group) do
            local child=panel:GetChildAt(anchorIndex+i)
            if not E.valid(child) or child:GetFullName()~=row:GetFullName() then already=false;break end
        end
        if already then state.positioned=true;return end
        for i=anchorIndex+1,panel:GetChildrenCount()-1 do
            local child=panel:GetChildAt(i)
            if not own[child:GetFullName()] then
                local slot=child.Slot;local pad=slot.Padding
                tail[#tail+1]={child=child,padding={Left=pad.Left,Top=pad.Top,Right=pad.Right,Bottom=pad.Bottom},
                    horizontal=slot.HorizontalAlignment,vertical=slot.VerticalAlignment}
            end
        end
        for _,row in ipairs(group) do row:RemoveFromParent() end
        for _,entry in ipairs(tail) do entry.child:RemoveFromParent() end
        for _,row in ipairs(group) do panel:AddChild(row):SetPadding({Left=8,Top=4,Right=5,Bottom=0}) end
        for _,entry in ipairs(tail) do
            local slot=panel:AddChild(entry.child)
            slot:SetPadding(entry.padding);slot:SetHorizontalAlignment(entry.horizontal);slot:SetVerticalAlignment(entry.vertical)
        end
        state.positioned=true
    end
    local markTexture
    local function mark(row)
        local renderer=object('/Script/Engine.Default__KismetRenderingLibrary')
        if not E.valid(renderer) then return end
        if not E.valid(markTexture) then
            markTexture=renderer:ImportFileAsTexture2D(row,E.root..'assets/gg-mark.png')
            assert(E.valid(markTexture),'Cannot load Growing Grounds settings mark')
        end
        local title=row.Text_OptionTitle
        local column=title:GetParent()
        local canvas=column:GetParent()
        assert(E.valid(canvas) and canvas:IsA('/Script/UMG.CanvasPanel'),'Unexpected settings title layout')
        local size=title.Font.Size
        assert(type(size)=='number' and size>0,'Settings title font size unavailable')
        local image=StaticConstructObject(object('/Script/UMG.Image'),row.WidgetTree,FName('GG_SettingsMark'))
        assert(E.valid(image),'Cannot create settings mark')
        image:SetBrushFromTexture(markTexture,false)
        image:SetVisibility(4) -- SelfHitTestInvisible: preserve native mouse/keyboard input.
        local position=column.Slot:GetPosition()
        local slot=canvas:AddChildToCanvas(image)
        slot:SetAnchors({Minimum={X=0,Y=0.5},Maximum={X=0,Y=0.5}})
        slot:SetAlignment({X=0,Y=0.5})
        slot:SetPosition({X=position.X,Y=0})
        slot:SetSize({X=size,Y=size})
        column.Slot:SetPosition({X=position.X+size*1.3,Y=position.Y})
    end
    function W.attach(menu, state)
        -- Keep the draft pending even when native assets are not ready yet.
        -- W.refresh retries it after each ordinary reconciliation.
        state.initializing = true
        local panel, example = menu.ScrollBox_DifficultySetting, menu.WorldSettings_BaseCampWorkerNum
        if not E.valid(panel) or not E.valid(example) then return end
        local class = object(rowPath)
        if not E.valid(class) then return end
        for _, spec in ipairs(fields) do
            local row = findChild(panel, state.rows[spec.key])
            if not E.valid(row) then
                state.positioned = false
                forgetRow(state.rows[spec.key])
                row = object('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(menu,class,menu:GetOwningPlayer())
                assert(E.valid(row), 'Cannot create World Settings row')
                E.guard('World Settings mark',function() mark(row) end)
                row.OptionType = example.OptionType
                row.IsOverrideSliderStep, row.OverrideSliderStepValue = true, spec.step
                local path = row:GetFullName()
                state.rows[spec.key] = path
                local slider=row.WBP_OptionSettings_ListContentSlider:GetFullName()
                owned[path] = {screen=menu:GetFullName(), row=row, spec=spec, slider=slider}
                sliders[slider]=path
                -- Append one compact mod group in the custom settings list.
                -- Avoid reconstructing/reordering native rows with pending edits.
                local slot = panel:AddChild(row)
                slot:SetPadding({Left=8,Top=4,Right=5,Bottom=0})
            end
            row:SetupIntValue(state.draft[spec.key],spec.min,spec.max)
            paint(row,spec,state.draft[spec.key])
        end
        positionGroup(menu,state,panel)
        state.initializing = false
    end
    function W.setup(menu, world, isNew)
        local name = menu:GetFullName()
        local old = screens[name]
        local id = E.settings.key(world)
        if not id and not isNew then
            screens[name] = nil
            error('Cannot identify selected world; no Growing Grounds settings will be saved')
        end
        local state = {menu=menu,world=id,isNew=isNew,draft=E.settings.get(id),rows=old and old.rows or {},
            previousWorld=E.worldId(),dirty=false}
        screens[name] = state
        W.attach(menu,state)
        E.log(state.initializing and 'World Settings: waiting for native widgets'
            or 'World Settings: range growth/cap, chest and Palbox start/total rows ready')
    end
    function W.change(row, value)
        local entry = owned[row:GetFullName()]
        if not entry then return end
        local state = screens[entry.screen]
        if not state or state.initializing then return end
        -- Snap the native float directly to this setting's step. Rounding to
        -- an integer first would move the six-slot midpoint (20.6 -> 24).
        if type(value)=='number' and value==value and math.abs(value)<math.huge then
            local step=entry.spec.step
            value=math.floor(value/step+0.5)*step
        end
        local candidate={}
        for k,v in pairs(state.draft) do candidate[k]=v end
        candidate[entry.spec.key]=value
        -- Moving the start above the end raises the end; lowering the end
        -- lowers the start. Keep both visible sliders consistent with the draft.
        if entry.spec.key=='startingPalboxBoxes' and type(value)=='number' and value==value then
            candidate.maxPalboxBoxes=math.max(state.draft.maxPalboxBoxes,value)
        end
        local normalized = E.range.settings(candidate)[entry.spec.key]
        normalized = math.max(entry.spec.min,math.min(entry.spec.max,math.floor(normalized+0.5)))
        if state.draft[entry.spec.key]==normalized then
            paint(row,entry.spec,normalized)
            return
        end
        state.draft[entry.spec.key] = normalized
        state.dirty = true
        local menu = state.menu
        assert(E.valid(menu) and menu:GetFullName()==entry.screen, 'Settings menu closed')
        menu.IsEditedSettingFlag = true
        menu.IsEditedInCustomSetting = true
        state.draft=E.range.settings(candidate)
        W.attach(menu,state)
    end
    function W.sliderUpdated(slider)
        local path=sliders[slider:GetFullName()]
        local entry=path and owned[path]
        local state=entry and screens[entry.screen]
        local row=entry and entry.row
        if state and not state.initializing and E.valid(row) and row:GetFullName()==path then
            paint(row,entry.spec,state.draft[entry.spec.key])
        end
    end
    function W.saved(outer, success)
        if not success then return end
        local menu = outer.WBP_Title_WorldSettings
        if not E.valid(menu) then return end
        local state = screens[menu:GetFullName()]
        if state and state.world and state.dirty then
            E.settings.save(state.world,state.draft)
            state.dirty = false
            E.log('World Settings saved for selected world')
        end
    end
    function W.newGame(outer)
        local menu = outer.WBP_Title_WorldSettings
        if not E.valid(menu) then return end
        local state = screens[menu:GetFullName()]
        if state and state.isNew then
            -- Retain values until the game has assigned the NEW world's GUID.
            W.pendingNew = {draft=E.range.settings(state.draft), previous=state.previousWorld}
        end
    end
    local function hook(path, callback)
        if hooks[path] or not E.valid(object(path)) then return end
        RegisterHook(path,callback)
        hooks[path] = true
    end
    function W.installHooks()
        hook(menuPath..':Setup',function(context,_,isNew,_,directory)
            E.guard('world settings setup',function()
                W.setup(context:get(),stringValue(directory:get()),isNew:get())
            end)
        end)
        hook(rowPath..':BndEvt__WBP_Title_WorldSettings_ListContent_WBP_OptionSettings_ListContentSlider_K2Node_ComponentBoundEvent_8_OnValueChanged__DelegateSignature',
            function(context,value)
                E.guard('world setting change',function() W.change(context:get(),value:get()) end)
            end)
        hook(rowPath..':Construct',function(context)
            local row = context:get()
            if not E.valid(row) then return end
            local entry = owned[row:GetFullName()]
            if entry then E.guard('world setting label',function()
                local state=screens[entry.screen]
                if state then paint(row,entry.spec,state.draft[entry.spec.key]) end
            end) end
        end)
        -- The native slider rewrites its number AFTER notifying the parent row.
        -- Restore our suffix/Off label once that mouse or keyboard update ends.
        local sliderPath='/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_OptionSettings_ListContentSlider.WBP_OptionSettings_ListContentSlider_C:'
        for _,event in ipairs({'AddConstantValue','AddPercent',
            'BndEvt__WBP_OptionSettings_ListContentSlider_Slider_K2Node_ComponentBoundEvent_0_OnFloatValueChangedEvent__DelegateSignature'}) do
            hook(sliderPath..event,function(context)
                E.guard('world setting display',function() W.sliderUpdated(context:get()) end)
            end)
        end
        hook(outerPath..':OnCompletedSaveSetting',function(context,success)
            E.guard('world settings save',function() W.saved(context:get(),success:get()) end)
        end)
        hook(outerPath..':StartNewGame',function(context)
            E.guard('new world settings',function() W.newGame(context:get()) end)
        end)
    end
    function W.refresh()
        W.installHooks()
        if W.pendingNew then
            local id = E.worldId()
            if id and id ~= W.pendingNew.previous then
                E.settings.save(id,W.pendingNew.draft)
                W.pendingNew = nil
                E.log('Growing Grounds settings saved for new world')
            end
        end
        for name,state in pairs(screens) do
            local menu = state.menu
            if not E.valid(menu) or menu:GetFullName()~=name then
                for _,path in pairs(state.rows) do
                    forgetRow(path)
                end
                screens[name]=nil
            elseif state.initializing then
                -- An asset can be unavailable on the first construction frame.
                W.attach(menu,state)
            end
        end
    end
    return W
end

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
        {key='maxRangeBonusPercent', title='rangeCapTitle', tip='rangeCapTip', min=0, max=E.range.limits.maxRangeBonusPercent},
        {key='maxChestBonusSlots', title='chestCapTitle', tip='chestCapTip', min=0, max=E.range.limits.maxChestBonusSlots},
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
            local display=value==0 and texts.off or (spec.key=='maxRangeBonusPercent' and string.format('+%g%%',value) or tostring(value))
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
    function W.attach(menu, state)
        local panel, example = menu.ScrollBox_DifficultySetting, menu.WorldSettings_BaseCampWorkerNum
        if not E.valid(panel) or not E.valid(example) then return end
        local class = object(rowPath)
        if not E.valid(class) then return end
        state.initializing = true
        for _, spec in ipairs(fields) do
            local row = findChild(panel, state.rows[spec.key])
            if not E.valid(row) then
                row = object('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(menu,class,menu:GetOwningPlayer())
                assert(E.valid(row), 'Cannot create World Settings row')
                row.OptionType = example.OptionType
                row.IsOverrideSliderStep, row.OverrideSliderStepValue = true, 1
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
        E.log('World Settings: range bonus cap and chest bonus cap rows ready')
    end
    function W.change(row, value)
        local entry = owned[row:GetFullName()]
        if not entry then return end
        local state = screens[entry.screen]
        if not state or state.initializing then return end
        -- Round the native float first: Range.settings floors the chest cap.
        if type(value)=='number' and value==value and math.abs(value)<math.huge then value=math.floor(value+0.5) end
        local normalized = E.range.settings({[entry.spec.key]=value})[entry.spec.key]
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
        paint(row,entry.spec,normalized)
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
                    local entry=owned[path]
                    if entry then sliders[entry.slider]=nil end
                    owned[path]=nil
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

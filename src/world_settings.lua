-- Native rows in World Settings. Drafts live only in this menu; saving follows
-- the game's successful-save event, never a slider movement or closing/cancel.
return function(E)
    local W = {}
    local menuPath = '/Game/Pal/Blueprint/UI/UserInterface/Title/WBP_Title_WorldSettings.WBP_Title_WorldSettings_C'
    local rowPath = '/Game/Pal/Blueprint/UI/UserInterface/Title/WBP_Title_WorldSettings_ListContent.WBP_Title_WorldSettings_ListContent_C'
    local outerPath = '/Game/Pal/Blueprint/UI/Title/WBP_WorldSetting.WBP_WorldSetting_C'
    local screens, owned, hooks = {}, {}, {}
    local fields = {
        {key='growthPercentPerLevel', title='Growing Grounds: Range growth per level (%)', min=0, max=20,
            tip='Adds a percentage of the original radius each level after level 1. Default: 5%.'},
        {key='maxRangePercent', title='Growing Grounds: Maximum base radius (%)', min=100, max=200,
            tip='200% doubles the original radius: 35 m becomes 70 m. Nearby bases can limit growth.'},
    }
    local function object(path)
        if E.objects then return E.objects.find(path) end
        return StaticFindObject(path)
    end
    local function stringValue(value)
        return type(value)=='string' and value or value:ToString()
    end
    local function paint(row, spec)
        row.Text_OptionTitle:SetText(FText(spec.title))
        row:SetToolTipText(FText(spec.tip))
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
                owned[path] = {screen=menu:GetFullName(), spec=spec}
                -- Append one compact mod group in the custom settings list.
                -- Avoid reconstructing/reordering native rows with pending edits.
                local slot = panel:AddChild(row)
                slot:SetPadding({Left=8,Top=4,Right=5,Bottom=0})
            end
            row:SetupIntValue(state.draft[spec.key],spec.min,spec.max)
            paint(row,spec)
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
        local state = {world=id,isNew=isNew,draft=E.settings.get(id),rows=old and old.rows or {},
            previousWorld=E.worldId(),dirty=false}
        screens[name] = state
        W.attach(menu,state)
        E.log('World Settings: growth and radius cap rows ready')
    end
    function W.change(row, value)
        local entry = owned[row:GetFullName()]
        if not entry then return end
        local state = screens[entry.screen]
        if not state or state.initializing then return end
        local normalized = E.range.settings({[entry.spec.key]=value})[entry.spec.key]
        normalized = math.floor(normalized+0.5)
        if state.draft[entry.spec.key]==normalized then return end
        state.draft[entry.spec.key] = normalized
        state.dirty = true
        local menu = object(entry.screen)
        assert(E.valid(menu), 'Settings menu closed')
        menu.IsEditedSettingFlag = true
        menu.IsEditedInCustomSetting = true
        paint(row,entry.spec)
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
            if entry then E.guard('world setting label',function() paint(row,entry.spec) end) end
        end)
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
            local menu = object(name)
            if not E.valid(menu) then
                for _,path in pairs(state.rows) do owned[path]=nil end
                screens[name]=nil
            elseif state.initializing then
                -- An asset can be unavailable on the first construction frame.
                W.attach(menu,state)
            end
        end
    end
    return W
end

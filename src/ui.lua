return function(E, Runtime)
    local UI = {}
    local rowPath = '/Game/Pal/Blueprint/UI/UserInterface/IngameMenu/Task/WBP_IngameMenu_MissionLevelEffect.WBP_IngameMenu_MissionLevelEffect_C'
    local attached, owned, lastWritten = {}, {}, {}
    local constructHookInstalled = false
    local function object(path)
        if E.objects then return E.objects.find(path) end
        return StaticFindObject(path)
    end
    local function text(value) return FText(value) end
    local function percent(value) return string.format('%.0f%%', value) end
    local function paint(row, state)
        local before = math.floor(state.currentPercent + 0.5)
        row:SetEffectInfo(before, state.nextPercent or before, state.atMaximum, state.canLevelup)
        row.Image_Icon:SetBrushFromTexture(row.Texture, false)
        row.Text_Efefct:SetText(text('Base Range'))
        row.Text_Num_Pre:SetText(text(percent(state.currentPercent)))
        local showNext=not state.atMaximum and state.nextPercent~=nil
        row.Text_Num_Aft:SetText(text(state.nextPercent and percent(state.nextPercent) or ''))
        -- Hidden preserves the game's two value columns while replication catches up.
        row.Image_Arrow:SetVisibility(showNext and 4 or 2)
        row.SizeBox_Aft:SetVisibility(showNext and 4 or 2)
    end
    local function installConstructHook()
        if constructHookInstalled then return end
        -- Blueprint Construct runs again when Slate rebuilds the row. Its
        -- defaults are InfoMsgId=None and Texture=null. Repair only our rows
        -- in a post-hook, after the game's own initialization has completed.
        RegisterHook(rowPath .. ':Construct', function(context)
            E.guard('reward reconstruction', function()
                local row = context:get()
                if not E.valid(row) then return end
                local state = owned[row:GetFullName()]
                if state then paint(row, state) end
            end)
        end)
        constructHookInstalled = true
    end
    function UI.update(screen)
        if not E.valid(screen) then return end
        local model = screen:GetBaseCampModel()
        if not E.valid(model) or not model:IsAvailable() then return end
        local example = screen.WBP_IngameMenu_MissionLevelEffect_1
        if not E.valid(example) then return end
        local parent = example:GetParent()
        if not E.valid(parent) then return end
        local key = screen:GetFullName()
        local state = Runtime.snapshot(model)
        state.canLevelup = screen.CanLevelup
        local row
        -- Resolve through the live widget tree instead of holding raw UObject
        -- references across GC, close/reopen or travel.
        if attached[key] then
            for index = 0, parent:GetChildrenCount() - 1 do
                local child = parent:GetChildAt(index)
                if child:GetFullName() == attached[key] then row = child; break end
            end
        end
        if not E.valid(row) then
            local oldName = attached[key]
            if oldName then owned[oldName], lastWritten[oldName] = nil, nil end
            local class = object(rowPath)
            if not E.valid(class) then return end
            installConstructHook()
            local library = object('/Script/UMG.Default__WidgetBlueprintLibrary')
            row = library:Create(screen, class, screen:GetOwningPlayer())
            assert(E.valid(row), 'Reward widget creation failed')
            local rendering = object('/Script/Engine.Default__KismetRenderingLibrary')
            local texture = rendering:ImportFileAsTexture2D(screen, E.root .. 'assets/base-range.png')
            assert(E.valid(texture), 'Cannot load four-arrow icon')
            -- Set the Blueprint's backing property before attaching: its
            -- Construct event copies Texture into Image_Icon. The reflected
            -- reference also retains the runtime texture across collection.
            row.Texture = texture
            attached[key] = row:GetFullName()
            owned[row:GetFullName()] = state
            local slot = parent:AddChildToVerticalBox(row)
            slot:SetPadding({Left=0, Top=4, Right=0, Bottom=0})
            E.log('native Base Range reward row added')
        end
        local name = row:GetFullName()
        owned[name] = state
        local signature = table.concat({state.currentPercent, tostring(state.nextPercent),
            tostring(state.atMaximum), tostring(state.canLevelup)}, ':')
        if lastWritten[name] ~= signature or row.Text_Efefct:GetText():ToString() ~= 'Base Range' then
            paint(row, state)
            lastWritten[name] = signature
        end
    end
    function UI.refresh()
        local live = {}
        local screens=E.objects and E.objects.all('WBP_IngameMenu_Mission_C') or FindAllOf('WBP_IngameMenu_Mission_C') or {}
        for _, screen in ipairs(screens) do
            if E.valid(screen) then
                live[screen:GetFullName()] = true
                E.guard('reward row', function() UI.update(screen) end)
            end
        end
        for key, name in pairs(attached) do
            if not live[key] then
                owned[name], lastWritten[name], attached[key] = nil, nil, nil
            end
        end
    end
    return UI
end

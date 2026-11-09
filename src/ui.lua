return function(E, Runtime)
    local UI = {}
    local rowPath = '/Game/Pal/Blueprint/UI/UserInterface/IngameMenu/Task/WBP_IngameMenu_MissionLevelEffect.WBP_IngameMenu_MissionLevelEffect_C'
    local attached, owned, columns, lastWritten = {}, {}, {}, {}
    local constructHookInstalled = false
    local function object(path)
        if E.objects then return E.objects.find(path) end
        return StaticFindObject(path)
    end
    local function text(value) return FText(value) end
    local label = 'Base Range Bonus'
    local function gain(value) return string.format('%.0f', value - 100) end
    local mint = {SpecifiedColor={R=0.27,G=0.78,B=0.60,A=1},ColorUseRule=0}
    local metreGap = 3
    local metreScale = 0.45
    local valueGutter = 4 -- clearance between the annotation and native chevrons
    local function metres(cm)
        -- Round a positive radius to the nearest tenth, then omit a trailing .0.
        local value = string.format('%.1f', math.floor(cm / 10 + 0.5) / 10):gsub('%.0$', '')
        return value .. 'm'
    end
    local function wrapValue(row, field)
        local main = row[field]
        local box = main:GetParent()
        local group = StaticConstructObject(object('/Script/UMG.HorizontalBox'), row.WidgetTree, FName('GG_' .. field .. '_Group'))
        local balance = StaticConstructObject(object('/Script/UMG.Spacer'), row.WidgetTree, FName('GG_' .. field .. '_Balance'))
        local unit = StaticConstructObject(object('/Script/UMG.TextBlock'), row.WidgetTree, FName('GG_' .. field .. '_Percent'))
        local note = StaticConstructObject(object('/Script/UMG.TextBlock'), row.WidgetTree, FName('GG_' .. field .. '_Metres'))
        assert(E.valid(group) and E.valid(balance) and E.valid(unit) and E.valid(note), 'Cannot create inline range labels')
        balance:SetSize({X=0,Y=0})
        main:RemoveFromParent()
        group:AddChildToHorizontalBox(balance)
        group:AddChildToHorizontalBox(main):SetVerticalAlignment(2)
        group:AddChildToHorizontalBox(unit):SetVerticalAlignment(2)
        local slot = group:AddChildToHorizontalBox(note)
        slot:SetVerticalAlignment(2)
        slot:SetPadding({Left=metreGap,Top=0,Right=0,Bottom=0})
        local outerSlot = box:AddChild(group)
        outerSlot:SetHorizontalAlignment(2)
        outerSlot:SetVerticalAlignment(2)
        unit:SetVisibility(4)
        note:SetVisibility(4)
    end
    local function paintSuffix(main, index, scale, value, color)
        -- Copy the native face, weight and shadow; change only size and tint.
        local suffix = main:GetParent():GetChildAt(index)
        suffix:SetFont(main.Font)
        suffix.Font.Size = math.max(1, math.floor(main.Font.Size * scale + 0.5))
        suffix:SetFont(suffix.Font)
        suffix:SetShadowColorAndOpacity(main.ShadowColorAndOpacity)
        suffix:SetShadowOffset(main.ShadowOffset)
        suffix:SetColorAndOpacity(color or main.ColorAndOpacity)
        if not color then suffix:SetRenderOpacity(main.RenderOpacity) end
        suffix:SetText(text(value))
    end
    local function fitColumns(screen, row, state)
        -- Balance BOTH suffixes with equal empty space on the left. Only the
        -- digits sit on the native value centre; '%' and metres extend right.
        -- Only changed presentation triggers measurement, never an idle tick.
        local example = screen.WBP_IngameMenu_MissionLevelEffect_1
        local grid = columns[screen:GetFullName()]
        -- Always start from the original native width, not our last enlarged
        -- width. Shorter annotations can then move the arrows back right.
        local width = grid.minimum
        local measured = {}
        for _, field in ipairs({'Text_Num_Pre','Text_Num_Aft'}) do
            if field=='Text_Num_Pre' or (not state.atMaximum and state.nextPercent~=nil) then
                local main = row[field]
                local group = main:GetParent()
                local number, percent, metres = main:GetDesiredSize(),
                    group:GetChildAt(2):GetDesiredSize(), group:GetChildAt(3):GetDesiredSize()
                for _, size in ipairs({number, percent, metres}) do
                    -- A closed/unconstructed Slate tree can report zero even
                    -- for nonempty text. Never commit those sizes or spacers.
                    if not (size.X>0 and size.X<math.huge and size.Y>0 and size.Y<math.huge) then
                        return false
                    end
                end
                local side = percent.X + metres.X + metreGap
                measured[#measured+1] = {group=group,side=side}
                width = math.max(width, number.X + 2 * side + 2 * valueGutter)
            end
        end
        -- Commit only after every displayed value is measurable. A bad next
        -- value must not alter the current value's already balanced spacer.
        for _, value in ipairs(measured) do value.group:GetChildAt(0):SetSize({X=value.side,Y=0}) end
        width = math.ceil(width)
        for _, reward in ipairs({screen.WBP_IngameMenu_MissionLevelEffect, example, row}) do
            if E.valid(reward) then
                for _, field in ipairs({'Text_Num_Pre','Text_Num_Aft'}) do
                    local box = reward[field]:GetParent()
                    if reward == row then box = box:GetParent() end
                    if box.WidthOverride ~= width then box:SetWidthOverride(width) end
                end
            end
        end
        return true
    end
    local function paint(row, state)
        local before = math.floor(state.currentPercent + 0.5)
        row:SetEffectInfo(before, state.nextPercent or before, state.atMaximum, state.canLevelup)
        row.Image_Icon:SetBrushFromTexture(row.Texture, false)
        row.Text_Efefct:SetText(text(label))
        row.Text_Num_Pre:SetText(text(gain(state.currentPercent)))
        local showNext=not state.atMaximum and state.nextPercent~=nil
        row.Text_Num_Aft:SetText(text(state.nextPercent and gain(state.nextPercent) or ''))
        paintSuffix(row.Text_Num_Pre, 2, 2/3, '%')
        paintSuffix(row.Text_Num_Aft, 2, 2/3, state.nextPercent and '%' or '')
        paintSuffix(row.Text_Num_Pre, 3, metreScale, metres(state.radius), mint)
        paintSuffix(row.Text_Num_Aft, 3, metreScale, state.nextPercent and metres(state.baseline * state.nextPercent / 100) or '', mint)
        -- Hidden preserves the game's two value columns while replication catches up.
        row.Image_Arrow:SetVisibility(showNext and 4 or 2)
        row.SizeBox_Aft:SetVisibility(showNext and 4 or 2)
        row:ForceLayoutPrepass()
        -- Construct can rebuild Slate outside UI.update. Its post-hook uses
        -- this same current painter; the next visible update must remeasure.
        lastWritten[row:GetFullName()] = nil
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
        if not screen:IsActivated() then return end
        local model = screen:GetBaseCampModel()
        if not E.valid(model) or not model:IsAvailable() then return end
        local example = screen.WBP_IngameMenu_MissionLevelEffect_1
        if not E.valid(example) then return end
        local parent = example:GetParent()
        if not E.valid(parent) then return end
        local key = screen:GetFullName()
        if not columns[key] then
            columns[key] = {minimum=math.max(example.Text_Num_Pre:GetParent().WidthOverride,
                example.Text_Num_Aft:GetParent().WidthOverride)}
        end
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
            wrapValue(row, 'Text_Num_Pre')
            wrapValue(row, 'Text_Num_Aft')
            attached[key] = row:GetFullName()
            owned[row:GetFullName()] = state
            local slot = parent:AddChildToVerticalBox(row)
            slot:SetPadding({Left=0, Top=4, Right=0, Bottom=0})
            E.log('Base Range Bonus row added')
        end
        local name = row:GetFullName()
        owned[name] = state
        local signature = table.concat({state.currentPercent, tostring(state.nextPercent), state.radius, state.baseline,
            tostring(state.atMaximum), tostring(state.canLevelup)}, ':')
        if lastWritten[name] ~= signature or row.Text_Efefct:GetText():ToString() ~= label then
            paint(row, state)
            if fitColumns(screen, row, state) then lastWritten[name] = signature end
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
        for key in pairs(columns) do
            if not live[key] then
                local name = attached[key]
                if name then owned[name], lastWritten[name] = nil, nil end
                attached[key], columns[key] = nil, nil
            end
        end
    end
    return UI
end

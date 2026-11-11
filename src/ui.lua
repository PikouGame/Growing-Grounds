return function(E, Runtime)
    local UI = {}
    local rowPath = '/Game/Pal/Blueprint/UI/UserInterface/IngameMenu/Task/WBP_IngameMenu_MissionLevelEffect.WBP_IngameMenu_MissionLevelEffect_C'
    local attached, owned, columns, lastWritten = {}, {}, {}, {}
    local constructHookInstalled = false
    -- Engine enum values: ESlateVisibility and EVerticalAlignment/EHorizontalAlignment.
    local SelfHitTestInvisible, Hidden, Collapsed, Center = 4, 2, 1, 2
    local function object(path) return E.objects.find(path) end
    local function text(value) return FText(value) end
    -- label names the row in the log; text is its title's key in the game's language.
    local specs = {
        {key='range', label='Base Range Bonus', text='rangeRow', icon='base-range.png'},
        {key='chest', label='Bonus Chest Slots', text='chestRow', icon='chest-bonus.png'},
        {key='palbox', label='Bonus Palbox Pages', text='palboxRow', icon='palbox-bonus.png'},
    }
    local function gain(value) return string.format('%.0f', value - 100) end
    local mint = {SpecifiedColor={R=0.27,G=0.78,B=0.60,A=1},ColorUseRule=0}
    local metreGap = 3
    local metreScale = 0.45
    local valueGutter = 4 -- clearance between the annotation and native chevrons
    local function fitTitle(row)
        local title = row.Text_Efefct
        local titleName = title:GetFullName()
        local parent = title:GetParent()
        if parent:IsA('/Script/UMG.ScaleBox') then return end
        -- The native row is icon, Auto title, Fill spacer, current, arrow,
        -- next. Once the spacer reaches zero, an Auto title pushes the values
        -- outside the row. Give its space to a shrink-only title instead.
        local tail, found = {}, false
        for index=0,parent:GetChildrenCount()-1 do
            local child=parent:GetChildAt(index)
            -- Repeated UObject lookups can produce different Lua handles.
            if child:GetFullName()==titleName then found=true end
            if found then
                local slot=child.Slot
                local p,s=slot.Padding,slot.Size
                tail[#tail+1]={child=child,padding={Left=p.Left,Top=p.Top,Right=p.Right,Bottom=p.Bottom},
                    size={Value=s.Value,SizeRule=s.SizeRule},horizontal=slot.HorizontalAlignment,
                    vertical=slot.VerticalAlignment}
            end
        end
        assert(found,'Reward title is missing from its row')
        local box=StaticConstructObject(object('/Script/UMG.ScaleBox'),row.WidgetTree,FName('GG_TitleFit'))
        assert(E.valid(box),'Cannot create fitted reward title')
        box:SetStretch(2) -- EStretch::ScaleToFit, preserving the aspect ratio.
        box:SetStretchDirection(1) -- EStretchDirection::DownOnly.
        title:RemoveFromParent()
        local titleSlot=box:AddChild(title)
        titleSlot:SetHorizontalAlignment(1) -- HAlign_Left
        titleSlot:SetVerticalAlignment(Center)
        -- Reappend the tail in its original order using runtime panel APIs.
        -- Keep the native number widgets, padding and visibility intact.
        for index,entry in ipairs(tail) do
            local child=index==1 and box or entry.child
            if index>1 then child:RemoveFromParent() end
            local slot=parent:AddChildToHorizontalBox(child)
            if index==1 then
                entry.size={Value=1,SizeRule=1} -- Fill the remaining width.
                entry.horizontal=0 -- HAlign_Fill
                entry.padding.Right=entry.padding.Right+valueGutter
            elseif child:IsA('/Script/UMG.Spacer') and entry.size.SizeRule==1 then
                entry.size={Value=1,SizeRule=0} -- The title now owns the flexible space.
            end
            slot:SetPadding(entry.padding)
            slot:SetSize(entry.size)
            slot:SetHorizontalAlignment(entry.horizontal)
            slot:SetVerticalAlignment(entry.vertical)
        end
    end
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
        group:AddChildToHorizontalBox(main):SetVerticalAlignment(Center)
        group:AddChildToHorizontalBox(unit):SetVerticalAlignment(Center)
        local slot = group:AddChildToHorizontalBox(note)
        slot:SetVerticalAlignment(Center)
        slot:SetPadding({Left=metreGap,Top=0,Right=0,Bottom=0})
        local outerSlot = box:AddChild(group)
        outerSlot:SetHorizontalAlignment(Center)
        outerSlot:SetVerticalAlignment(Center)
        unit:SetVisibility(SelfHitTestInvisible)
        note:SetVisibility(SelfHitTestInvisible)
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
    local function fitColumns(screen, row, state, rows)
        -- Balance BOTH suffixes with equal empty space on the left. Only the
        -- digits sit on the native value centre; '%' and metres extend right.
        -- Only changed presentation triggers measurement, never an idle tick.
        local example = screen.WBP_IngameMenu_MissionLevelEffect_1
        local grid = columns[screen:GetFullName()]
        -- Always start from the original native width, not our last enlarged
        -- width. Shorter annotations can then move the arrows back right.
        local width = grid.minimum
        local measured = {}
        for _, field in ipairs(row and {'Text_Num_Pre','Text_Num_Aft'} or {}) do
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
        local rewards={screen.WBP_IngameMenu_MissionLevelEffect, example}
        for _,spec in ipairs(specs) do if E.valid(rows[spec.key]) then rewards[#rewards+1]=rows[spec.key] end end
        for _, reward in ipairs(rewards) do
            if E.valid(reward) then
                fitTitle(reward)
                for _, field in ipairs({'Text_Num_Pre','Text_Num_Aft'}) do
                    local box = reward[field]:GetParent()
                    if reward == rows.range then box = box:GetParent() end
                    if box.WidthOverride ~= width then box:SetWidthOverride(width) end
                end
            end
        end
        return true
    end
    local function fitHeight(parent, grid, rows)
        local stack=parent:GetParent()
        if not E.valid(stack) then return end
        stack=stack:GetParent()
        if not E.valid(stack) or not E.valid(stack.Slot) or not stack.Slot:IsA('/Script/UMG.CanvasPanelSlot') then return end
        if not grid.position then
            local p=stack.Slot:GetPosition()
            grid.position={X=p.X,Y=p.Y}
            local size=stack.Slot:GetSize()
            grid.size={X=size.X,Y=size.Y}
        end
        -- Keep the established three-row spacing. Each additional reward grows
        -- upward by its native height, leaving the button/separator untouched.
        local extra,count=0,0
        for _,spec in ipairs(specs) do
            if grid.visible[spec.key] then
                count=count+1
                if count>1 then
                    local row=rows[spec.key]
                    local padding=row.Slot.Padding
                    extra=extra+row:GetDesiredSize().Y+padding.Top+padding.Bottom
                end
            end
        end
        local y=grid.position.Y-extra
        if stack.Slot:GetPosition().Y~=y then stack.Slot:SetPosition({X=grid.position.X,Y=y}) end
        -- Bottom-anchored separator stays put as the section expands upward.
        if stack.Slot:GetSize().Y~=grid.size.Y+extra then stack.Slot:SetSize({X=grid.size.X,Y=grid.size.Y+extra}) end
    end
    -- Where the boundary will be after the next upgrade, or false when this
    -- screen has no larger radius to announce.
    local function nextRadius(state)
        if state.rangeEnabled==false or state.atMaximum or not state.nextPercent then return false end
        local radius=state.baseline*state.nextPercent/100
        return radius>state.radius+1 and radius
    end
    local function paintRange(row, state, title)
        local before = math.floor(state.currentPercent + 0.5)
        row:SetEffectInfo(before, state.nextPercent or before, state.atMaximum, state.canLevelup)
        row.Image_Icon:SetBrushFromTexture(row.Texture, false)
        row.Text_Efefct:SetText(text(title))
        row.Text_Num_Pre:SetText(text(gain(state.currentPercent)))
        local showNext=not state.atMaximum and state.nextPercent~=nil
        row.Text_Num_Aft:SetText(text(state.nextPercent and gain(state.nextPercent) or ''))
        paintSuffix(row.Text_Num_Pre, 2, 2/3, '%')
        paintSuffix(row.Text_Num_Aft, 2, 2/3, state.nextPercent and '%' or '')
        paintSuffix(row.Text_Num_Pre, 3, metreScale, metres(state.radius), mint)
        paintSuffix(row.Text_Num_Aft, 3, metreScale, state.nextPercent and metres(state.baseline * state.nextPercent / 100) or '',
            state.canLevelup and row.Text_Num_Aft.ColorAndOpacity or mint)
        -- Hidden preserves the game's two value columns while replication catches up.
        row.Image_Arrow:SetVisibility(showNext and SelfHitTestInvisible or Hidden)
        row.SizeBox_Aft:SetVisibility(showNext and SelfHitTestInvisible or Hidden)
        row:ForceLayoutPrepass()
        -- Construct can rebuild Slate outside UI.update. Its post-hook uses
        -- this same current painter; the next visible update must remeasure.
        lastWritten[row:GetFullName()] = nil
    end
    local function paint(row, entry)
        local state=entry.state
        if entry.kind=='range' then paintRange(row,state,entry.title);return end
        local current,nextValue=state[entry.kind..'Current'],state[entry.kind..'Next']
        row:SetEffectInfo(current,nextValue or current,state.atMaximum,state.canLevelup)
        row.Image_Icon:SetBrushFromTexture(row.Texture,false)
        row.Text_Efefct:SetText(text(entry.title))
        row.Text_Num_Pre:SetText(text(tostring(current)))
        row.Text_Num_Aft:SetText(text(nextValue and tostring(nextValue) or ''))
        local showNext=not state.atMaximum and nextValue~=nil
        row.Image_Arrow:SetVisibility(showNext and SelfHitTestInvisible or Hidden)
        row.SizeBox_Aft:SetVisibility(showNext and SelfHitTestInvisible or Hidden)
        lastWritten[row:GetFullName()]=nil
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
                if state and (state.kind=='range' or state.state[state.kind..'Current']~=nil) then paint(row, state) end
            end)
        end)
        constructHookInstalled = true
    end
    function UI.update(screen)
        if not E.valid(screen) or not screen:IsActivated() then return end
        local model=screen:GetBaseCampModel()
        if not E.valid(model) or not model:IsAvailable() then return end
        local example=screen.WBP_IngameMenu_MissionLevelEffect_1
        if not E.valid(example) then return end
        local parent=example:GetParent()
        if not E.valid(parent) then return end
        local state=Runtime.snapshot(model)
        -- Preserve the last coherent rewards while the server's three fields
        -- arrive separately. A missing packet is not a disabled chest bonus.
        if state.previewPending then return end
        -- The ground shows the same next radius as the row, from the same values.
        if E.boundary and E.boundary.mark then
            E.guard('next boundary marker',function() E.boundary.mark(model,screen,nextRadius(state)) end)
        end
        local key=screen:GetFullName()
        if not columns[key] then
            columns[key]={minimum=math.max(example.Text_Num_Pre:GetParent().WidthOverride,
                example.Text_Num_Aft:GetParent().WidthOverride),visible={}}
            attached[key]={}
        end
        local grid=columns[key]
        local texts=E.texts()
        state.canLevelup=screen.CanLevelup
        local rows,signatures={},{}
        local needsLayout=false
        local enabled={range=state.rangeEnabled~=false,chest=state.chestCurrent~=nil,palbox=state.palboxCurrent~=nil}
        for _,spec in ipairs(specs) do
            local row
            for index=0,parent:GetChildrenCount()-1 do
                local child=parent:GetChildAt(index)
                if child:GetFullName()==attached[key][spec.key] then row=child;break end
            end
            if enabled[spec.key] and not E.valid(row) then
                local old=attached[key][spec.key]
                if old then owned[old],lastWritten[old]=nil,nil end
                local class=object(rowPath)
                if not E.valid(class) then return end
                installConstructHook()
                row=object('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(screen,class,screen:GetOwningPlayer())
                assert(E.valid(row),'Reward widget creation failed')
                local texture=object('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(screen,E.root..'assets/'..spec.icon)
                assert(E.valid(texture),'Cannot load reward icon: '..spec.icon)
                row.Texture=texture
                if spec.key=='range' then
                    wrapValue(row,'Text_Num_Pre');wrapValue(row,'Text_Num_Aft')
                end
                attached[key][spec.key]=row:GetFullName()
                owned[row:GetFullName()]={kind=spec.key,state=state,title=texts[spec.text]}
                parent:AddChildToVerticalBox(row):SetPadding({Left=0,Top=4,Right=0,Bottom=0})
                needsLayout=true
                E.log(spec.label..' row added')
            end
            if E.valid(row) then
                rows[spec.key]=row
                local name=row:GetFullName()
                owned[name]={kind=spec.key,state=state,title=texts[spec.text]}
                if grid.visible[spec.key]~=enabled[spec.key] then
                    row:SetVisibility(enabled[spec.key] and SelfHitTestInvisible or Collapsed)
                    grid.visible[spec.key]=enabled[spec.key]
                    lastWritten[name]=nil
                    needsLayout=true
                end
                if enabled[spec.key] then
                    local signature=spec.key=='range'
                        and table.concat({state.currentPercent,tostring(state.nextPercent),state.radius,state.baseline,
                            tostring(state.atMaximum),tostring(state.canLevelup)},':')
                        or table.concat({state[spec.key..'Current'],tostring(state[spec.key..'Next']),tostring(state.atMaximum),tostring(state.canLevelup)},':')
                    signatures[name]=signature
                    if lastWritten[name]~=signature or row.Text_Efefct:GetText():ToString()~=texts[spec.text] then
                        paint(row,owned[name]);needsLayout=true
                    end
                end
            end
        end
        if needsLayout then
            screen:ForceLayoutPrepass()
            fitHeight(parent,grid,rows)
        end
        if needsLayout and fitColumns(screen,enabled.range and rows.range or nil,state,rows) then
            for name,signature in pairs(signatures) do lastWritten[name]=signature end
        end
    end
    function UI.refresh()
        local live = {}
        local screens=E.objects.all('WBP_IngameMenu_Mission_C')
        for _, screen in ipairs(screens) do
            if E.valid(screen) then
                live[screen:GetFullName()] = true
                E.guard('reward row', function() UI.update(screen) end)
            end
        end
        for key in pairs(columns) do
            if not live[key] then
                for _,name in pairs(attached[key] or {}) do owned[name],lastWritten[name]=nil,nil end
                attached[key], columns[key] = nil, nil
            end
        end
    end
    return UI
end

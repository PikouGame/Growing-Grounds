-- Native level hooks can miss internal calls, and radius has no OnRep callback.
-- Observe only the small event-maintained base set; never search the world here.
return function(E)
    local C,previous,visible={},{},{}
    local function positive(n) return type(n)=='number' and n==n and n>0 and n<math.huge end
    function C.check()
        local models=E.objects.tracked('PalBaseCampModel')
        if not models then return false end
        local current,changed={},false
        -- The server and a co-op host build their values directly and never read
        -- the preview, so only a client watches its revision. Decide once per tick.
        local watchPreview
        for _,model in ipairs(models) do
            if E.valid(model) and model:IsAvailable() and not model.bTemporary then
                local name=model:GetFullName()
                local level,radius=model:GetLevel(),model:GetRange()
                if positive(level) and level%1==0 and positive(radius) then
                    if watchPreview==nil then watchPreview=E.preview~=nil and not E.runtime.isAuthority(model) end
                    local preview=watchPreview and E.preview.revision(model) or nil
                    current[name]={level=level,radius=radius,preview=preview}
                    local old=previous[name]
                    if not old or old.level~=level or math.abs(old.radius-radius)>0.1 or old.preview~=preview then changed=true end
                end
            end
        end
        for name in pairs(previous) do if not current[name] then changed=true end end
        previous=current
        -- A cached menu can reopen after replication completed while it was
        -- closed. Observe activation/readiness without repainting an idle menu.
        local screens={}
        for _,screen in ipairs(E.objects.tracked('WBP_IngameMenu_Mission_C') or {}) do
            if E.valid(screen) and screen:IsActivated() then
                local name=screen:GetFullName()
                screens[name]=screen.CanLevelup
                if visible[name]~=screens[name] then changed=true end
            end
        end
        visible=screens
        return changed
    end
    function C.install(refresh)
        LoopInGameThreadWithDelay(250,function()
            local ok,changed=E.guard('base change observer',C.check)
            if ok and changed then refresh() end
        end)
    end
    return C
end

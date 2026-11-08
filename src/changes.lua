-- Native level hooks can miss internal calls, and radius has no OnRep callback.
-- Observe only the small event-maintained base set; never search the world here.
return function(E)
    local C,previous={},{}
    local function finite(n) return type(n)=='number' and n==n and n>0 and n<math.huge end
    function C.check()
        local models=E.objects.tracked('PalBaseCampModel')
        if not models then return false end
        local current,changed={},false
        for _,model in ipairs(models) do
            if E.valid(model) and model:IsAvailable() and not model.bTemporary then
                local name=model:GetFullName()
                local level,radius=model:GetLevel(),model:GetRange()
                if finite(level) and level%1==0 and finite(radius) then
                    current[name]={level=level,radius=radius}
                    local old=previous[name]
                    if not old or old.level~=level or math.abs(old.radius-radius)>0.1 then changed=true end
                end
            end
        end
        for name in pairs(previous) do if not current[name] then changed=true end end
        previous=current
        return changed
    end
    function C.install(refresh)
        local pending=false
        LoopAsync(250,function()
            if not pending then
                pending=true
                ExecuteInGameThread(function()
                    local ok,changed=E.guard('base change observer',C.check)
                    pending=false
                    if ok and changed then refresh() end
                end)
            end
            return false
        end)
    end
    return C
end

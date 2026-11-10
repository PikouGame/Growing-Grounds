-- UE4SS 2281fa31 wrappers are checked against its live-object map by IsValid.
-- Cache them to avoid full-name searches each frame; also reject address reuse.
return function(E,Motion)
    local B,states,queued={},{},false
    local objects={}
    local function path(o)
        local p=assert(o:GetFullName():match('^%S+ (.+)$'))
        objects[p]=o;return p
    end
    local function resolve(p)
        if not p then return end
        local cached=objects[p]
        if cached then
            if E.valid(cached) and cached:GetFullName():match('^%S+ (.+)$')==p then return cached end
            objects[p]=nil;return nil
        end
        local o=StaticFindObject(p)
        if E.valid(o) then objects[p]=o;return o end
    end
    local Ribbon=dofile(E.root..'src/ribbon.lua')(E,{
        path=path,resolve=resolve,forget=function(p) objects[p]=nil end,
    })
    local function now(actor)
        return resolve('/Script/Engine.Default__KismetSystemLibrary'):GetGameTimeInSeconds(actor)
    end
    local function dedicated(actor)
        return resolve('/Script/Pal.Default__PalUtility'):IsDedicatedServer(actor)
    end
    local scale=dofile(E.root..'src/ring.lua')(E)
    local function upgradeScreens(s)
        local screens={}
        -- Discover once when an upgrade starts, never on animation ticks.
        for _,screen in ipairs(E.objects.all('WBP_IngameMenu_Mission_C')) do
            if E.valid(screen) and screen:IsActivated() then
                local base=screen:GetBaseCampModel()
                if E.valid(base) and base:GetFullName()==s.base then screens[#screens+1]=path(screen) end
            end
        end
        if #screens>0 then return screens end
    end
    local function clearScreens(s)
        for _,p in ipairs(s.upgradeScreens or {}) do objects[p]=nil end
        s.upgradeScreens=nil
    end
    local function waitForScreen(s,time)
        if not s.upgradeScreens then return end
        local ok,open=E.guard('upgrade screen state',function()
            for _,p in ipairs(s.upgradeScreens) do
                local screen=resolve(p)
                if screen and screen:IsActivated() then return true end
            end
            return false
        end)
        if ok and open then return end
        clearScreens(s)
        E.log(ok and 'Base Upgrade closed; releasing the prepared effect'
            or 'upgrade screen state unavailable; continuing the effect')
        if s.animation and s.animation.waiting and not(s.ribbon and s.ribbon.wave) then
            s.animation.waiting=nil;s.animation.start=time
        end
    end
    local schedule
    local function tick()
        queued=false
        -- Count and elapsed-time limits are shared by every active base.
        -- Each run samples fresh terrain. Spread work over short, bounded
        -- batches rather than retaining heights between upgrades.
        local active,budget,deadline=false,Ribbon.sampleLimit,os.clock()+Ribbon.sampleBudget
        for key,s in pairs(states) do
            if s.animation or s.ribbon then
                local actor=resolve(s.actor)
                if not actor then Ribbon.cleanup(s);clearScreens(s);states[key]=nil
                else
                    local ok=E.guard('boundary animation',function()
                        local time=now(actor)
                        waitForScreen(s,time)
                        if s.animation then
                            if time<s.animation.start then
                                scale(actor,s.radius,true);Ribbon.cleanup(s);clearScreens(s);Motion.finish(s);return
                            end
                            local radius,t=Motion.sample(s,time)
                            scale(actor,radius)
                            if t>=1 then
                                scale(actor,s.radius,true);Motion.finish(s)
                                E.log('upgrade animation settled at '..s.radius..' cm')
                            end
                        end
                        if s.ribbon then
                            local ribbonOK,used=E.guard('contour effect',function()
                                return Ribbon.step(s,actor,time,budget,deadline)
                            end)
                            if ribbonOK then budget=budget-used
                            else
                                Ribbon.cleanup(s)
                                -- An unavailable visual must never strand the boundary.
                                if s.animation and s.animation.waiting and not s.upgradeScreens then
                                    s.animation.waiting=nil;s.animation.start=time
                                end
                            end
                        end
                        if s.animation or s.ribbon then active=true end
                    end)
                    if not ok then
                        E.guard('boundary fallback',function() scale(actor,s.radius,true) end)
                        Ribbon.cleanup(s);clearScreens(s);Motion.finish(s)
                    end
                end
            end
        end
        if active then schedule() end
    end
    schedule=function()
        if queued then return end
        queued=true
        ExecuteInGameThreadWithDelay(16,tick)
    end
    local function start(s,actor)
        Ribbon.cleanup(s)
        clearScreens(s)
        local ok,found=E.guard('upgrade screen capture',function() return upgradeScreens(s) end)
        s.upgradeScreens=ok and found or nil
        scale(actor,s.animation.from)
        local prepared=E.guard('contour preparation',function() Ribbon.prepare(s,actor) end)
        if not prepared then Ribbon.cleanup(s) end
        if s.upgradeScreens or (s.ribbon and s.ribbon.wave) then s.animation.waiting=true end
        if s.upgradeScreens then E.log('preparing effect while Base Upgrade is open; playback waits for close') end
        E.log('upgrade animation started: '..s.animation.from..' -> '..s.radius..' cm')
        schedule()
    end
    function B.update(actor,base,id,radius)
        local actorPath=path(actor)
        local key=id..'|'..actorPath
        local previous=states[key]
        local enabled=E.config.upgradeAnimation~=false and not E.config.resetToVanilla and not dedicated(actor)
        local s,action=Motion.observe(previous,base:GetLevel(),radius,now(actor),enabled)
        if previous and s~=previous then Ribbon.cleanup(previous);clearScreens(previous) end
        s.actor,s.base,s.live=actorPath,base:GetFullName(),true;states[key]=s
        if action=='start' then start(s,actor) elseif not s.animation then scale(actor,s.radius) end
    end
    function B.beginRefresh() for _,s in pairs(states) do s.live=false end end
    function B.endRefresh()
        for key,s in pairs(states) do
            if not s.live then Ribbon.cleanup(s);clearScreens(s);objects[s.actor]=nil;states[key]=nil end
        end
    end
    return B
end

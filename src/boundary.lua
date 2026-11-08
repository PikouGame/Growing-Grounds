-- UE4SS 2281fa31 wrappers are checked against its live-object map by IsValid.
-- Cache them to avoid full-name searches each frame; also reject address reuse.
return function(E,Motion)
    local B,states,queued={},{},false
    local Range=E.range or dofile(E.root..'src/range.lua')
    E.boundaryObjects=E.boundaryObjects or {}
    local objects=E.boundaryObjects
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
    local function scale(actor,radius,force)
        for _,field in ipairs({'AreaRange','AreaRange1'}) do
            local c=actor[field]
            if E.valid(c) then
                local n=radius/50+(field=='AreaRange1' and 0.01 or 0)
                local v=c.RelativeScale3D
                if force or math.abs(v.X-n)>0.001 or math.abs(v.Y-n)>0.001 then
                    c:SetRelativeScale3D({X=n,Y=n,Z=v.Z})
                end
            end
        end
    end
    local function upgradeScreens(s)
        if not E.objects then return end
        local screens={}
        -- Discover once when an upgrade/replay starts, never on animation ticks.
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
        -- batches rather than retaining heights between upgrades/replays.
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
                            local job=s.ribbon
                            local measure=E.config.debug and job.wave and not job.wave.started
                                and not(s.upgradeScreens and job.wave.mesh)
                            local started=measure and os.clock()
                            local phase=job.sampled and 'mesh' or 'terrain'
                            local ribbonOK,used=E.guard('contour effect',function()
                                return Ribbon.step(s,actor,time,budget,deadline)
                            end)
                            if started then
                                local elapsed=(os.clock()-started)*1000
                                local stats=job.preparation or {steps=0,total=0,longest=0,terrain=0,mesh=0}
                                job.preparation=stats
                                stats.steps=stats.steps+1;stats.total=stats.total+elapsed
                                stats[phase]=stats[phase]+elapsed
                                stats.longest=math.max(stats.longest,elapsed)
                                if ribbonOK and job.wave.started then
                                    E.log(string.format('wave preparation: %d updates, %.1f ms work (terrain %.1f, mesh %.1f), %.1f ms longest update',
                                        stats.steps,stats.total,stats.terrain,stats.mesh,stats.longest))
                                end
                            end
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
        ExecuteWithDelay(16,function() ExecuteInGameThread(tick) end)
    end
    local function start(s,actor,screens)
        Ribbon.cleanup(s)
        clearScreens(s)
        local ok,found=E.guard('upgrade screen capture',function() return screens or upgradeScreens(s) end)
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
    function B.replay()
        local count=0
        for _,s in pairs(states) do
            local actor=resolve(s.actor)
            if actor and not s.animation and s.level>1 and not dedicated(actor) then
                local visible=actor.AreaRange:IsVisible()
                local screens
                if not visible then
                    local ok,found=E.guard('replay screen capture',function() return upgradeScreens(s) end)
                    if ok then screens=found end
                end
                if visible or screens then
                    local policy=E.policy and E.policy(actor) or E.config
                    local previous=Range.percent(s.level-1,policy)/Range.percent(s.level,policy)
                    s.animation={from=s.radius*previous,start=now(actor)}
                    start(s,actor,screens);count=count+1
                end
            end
        end
        E.log('visual-only replay: '..count..' eligible boundaries; gameplay radius unchanged')
    end
    function B.shutdown()
        for _,s in pairs(states) do
            local actor=resolve(s.actor)
            if actor then E.guard('animation reload restore',function() scale(actor,s.radius,true) end) end
            Ribbon.cleanup(s)
            clearScreens(s)
        end
        states={}
    end
    return B
end

-- UE4SS 2281fa31 wrappers are checked against its live-object map by IsValid.
-- Cache them to avoid full-name searches each frame; also reject address reuse.
return function(E,Motion)
    local B,states,queued={},{},false
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
    local schedule
    local function tick()
        queued=false
        local active,budget=false,4
        for key,s in pairs(states) do
            if s.animation or s.ribbon then
                local actor=resolve(s.actor)
                if not actor then Ribbon.cleanup(s);states[key]=nil
                else
                    local ok=E.guard('boundary animation',function()
                        local time=now(actor)
                        if s.animation then
                            if time<s.animation.start then
                                scale(actor,s.radius,true);Ribbon.cleanup(s);Motion.finish(s);return
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
                                return Ribbon.step(s,actor,time,budget)
                            end)
                            if ribbonOK then budget=budget-used else Ribbon.cleanup(s) end
                        end
                        if s.animation or s.ribbon then active=true end
                    end)
                    if not ok then
                        E.guard('boundary fallback',function() scale(actor,s.radius,true) end)
                        Ribbon.cleanup(s);Motion.finish(s)
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
    local function start(s,actor)
        Ribbon.cleanup(s)
        scale(actor,s.animation.from)
        local ok=E.guard('contour preparation',function() Ribbon.prepare(s,actor) end)
        if not ok then Ribbon.cleanup(s) end
        E.log('upgrade animation started: '..s.animation.from..' -> '..s.radius..' cm')
        schedule()
    end
    function B.update(actor,base,id,radius)
        local actorPath=path(actor)
        local key=id..'|'..actorPath
        local previous=states[key]
        local enabled=E.config.upgradeAnimation~=false and not E.config.resetToVanilla and not dedicated(actor)
        local s,action=Motion.observe(previous,base:GetLevel(),radius,now(actor),enabled)
        if previous and s~=previous then Ribbon.cleanup(previous) end
        s.actor,s.live=actorPath,true;states[key]=s
        if action=='start' then start(s,actor) elseif not s.animation then scale(actor,s.radius) end
    end
    function B.beginRefresh() for _,s in pairs(states) do s.live=false end end
    function B.endRefresh()
        for key,s in pairs(states) do
            if not s.live then Ribbon.cleanup(s);objects[s.actor]=nil;states[key]=nil end
        end
    end
    function B.replay()
        local count=0
        for _,s in pairs(states) do
            local actor=resolve(s.actor)
            if actor and not s.animation and s.level>1 and actor.AreaRange:IsVisible() and not dedicated(actor) then
                s.animation={from=s.radius*(1+0.05*(s.level-2))/(1+0.05*(s.level-1)),start=now(actor)}
                start(s,actor);count=count+1
            end
        end
        E.log('visual-only replay: '..count..' visible boundaries; gameplay radius unchanged')
    end
    function B.shutdown()
        for _,s in pairs(states) do
            local actor=resolve(s.actor)
            if actor then E.guard('animation reload restore',function() scale(actor,s.radius,true) end) end
            Ribbon.cleanup(s)
        end
        states={}
    end
    return B
end

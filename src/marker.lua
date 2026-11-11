-- While Base Upgrade is open: a breathing next-boundary glow or a lower,
-- steady dotted maximum. Terrain is sampled once per showing; only material
-- brightness changes afterwards, with no further writes for a steady maximum.
return function(E,A,Ribbon,maximum)
    local M={height=300,fadeIn=0.35,fadeOut=0.25,period=2.4,alpha=0.6,light=3}
    local key=maximum and 'maximumMarker' or 'marker'
    local failed=key..'Failed'
    local label=maximum and 'maximum boundary' or 'next boundary'
    if maximum then M.height=150;M.alpha=0.45;M.light=2 end
    local function smooth(t) t=math.max(0,math.min(1,t));return t*t*(3-2*t) end
    -- Brightness 0..1 after `shown` seconds on screen and, once dismissed,
    -- `closing` seconds of fading. nil when nothing is left to see.
    function M.level(shown,closing)
        if closing and closing>=M.fadeOut then return end
        -- A slow breath between full and three quarters draws the eye from the Palbox.
        local breath=maximum and 1 or 0.875+0.125*math.cos(2*math.pi*shown/M.period)
        return smooth(shown/M.fadeIn)*breath*(closing and 1-smooth(closing/M.fadeOut) or 1)
    end
    function M.cleanup(s)
        local job=s[key]
        if not job then return end
        Ribbon.release(job)
        for p in pairs(job.screens) do A.forget(p) end
        s[key]=nil
    end
    -- The reward rows report what their screen shows: the radius after the
    -- next upgrade, or false when there is none to announce.
    function M.aim(s,actor,radius,screen)
        local job=s[key]
        if not radius then
            if job then job.dismissed=true end -- fades out on its next update
            return
        end
        -- One failed setup is not repeated on every refresh of the same screen.
        if s[failed] and math.abs(s[failed]-radius)<=0.1 then return end
        if not job or job.dismissed or job.closing or math.abs(job.radius-radius)>0.1 then
            M.cleanup(s)
            job=Ribbon.job(actor,radius)
            job.dotted=maximum
            job.screens={}
            s[key]=job
        end
        job.screens[A.path(screen)]=true
    end
    function M.fail(s)
        local job=s[key]
        if not job then return end
        s[failed]=job.radius
        M.cleanup(s)
    end
    function M.step(s,actor,time,budget,deadline,open)
        local job=s[key]
        if not job then return 0 end
        if (job.dismissed or not open) and not job.closing then
            -- Nothing visible yet: leave without a flash.
            if not job.shown then M.cleanup(s);return 0 end
            job.closing=time
        end
        if job.nextPoint<job.count then
            if budget<1 or os.clock()>=deadline then return 0 end
            return (Ribbon.heights(job,actor,budget,deadline))
        end
        local c=A.resolve(job.component)
        if not c then
            if job.component then M.cleanup(s);return 0 end -- destroyed with its Palbox
            if budget<1 or os.clock()>=deadline then return 0 end
            -- The gradient upside down: brightest on the ground, fading upwards.
            local vertices,indices,normals,uv=Ribbon.band(job,M.height,0,511.5/512,0.5/512)
            assert(#indices>0,'No terrain under the '..label)
            c=Ribbon.component(job,actor)
            c:CreateMeshSection(0,vertices,indices,normals,uv,{},{},false)
            local mid=Ribbon.glow(job,actor,c,0,false)
            if maximum then
                mid:SetVectorParameterValue(FName('Color01'),{R=0.05,G=2.0,B=1.4,A=1})
            end
            return budget -- at most one mesh section created per update
        end
        if not job.shown then
            job.shown=time
            c:SetHiddenInGame(false,false);c:SetVisibility(true,false)
            E.log(string.format('%s marker shown at %.0f cm: %d/%d terrain samples',
                label,job.radius,job.hits,job.count))
        end
        local level=time>=job.shown and M.level(time-job.shown,job.closing and time-job.closing)
        if not level then M.cleanup(s);return 0 end
        local mid=assert(A.resolve(job.materials[1]),'Marker material expired')
        if job.brightness~=level then
            mid:SetScalarParameterValue(FName('AlphaScale01'),M.alpha*level)
            mid:SetScalarParameterValue(FName('RGBScale01'),M.light*level)
            job.brightness=level
        end
        return 0
    end
    return M
end

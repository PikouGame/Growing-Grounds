-- Palbox ground wave, then the accepted rising contour. One component;
-- sampled geometry stays fixed and a material offset moves the ground light.
return function(E,A)
    local R={layers=2,duration=2.8,sampleLimit=64,sampleBudget=0.003}
    local Wave=dofile(E.root..'src/wave.lua')
    local materialPath='/Game/Pal/Effect/Material_Instances/Particle_basic_color/MI_LightUpGlow.MI_LightUpGlow'
    local function smooth(t) t=math.max(0,math.min(1,t));return t*t*(3-2*t) end
    function R.envelope(elapsed,height)
        local t=math.max(0,math.min(1,elapsed/R.duration))
        local rise=height*(1-(1-t)^3) -- keeps moving until fully invisible
        local appear=smooth(elapsed/0.06)
        local fade=1-smooth((elapsed-1.6)/1.2)
        -- Soften the tail before the flash, retaining a glow through the
        -- finish. Both parts share the final fade while still moving.
        local trail=appear*(1-0.4*smooth((elapsed-0.65)/0.6))*fade
        local flash=smooth((elapsed-1.3)/0.25)*(1-smooth((elapsed-1.65)/0.35))
        return rise,appear*fade,trail,(1+4*flash)*fade
    end
    function R.pose(job,elapsed,rise)
        -- Gradually compress relief about its highest sampled point. Lower
        -- sections move upwards, never down through the terrain. Retain 35%
        -- of the original relief: a softer contour rather than a flat hoop.
        -- One component transform also keeps the head/trail joined, without
        -- rebuilding sections or doing any more terrain queries while rising.
        local zScale=1-0.65*smooth(elapsed/1.4)
        return {Rotation={X=0,Y=0,Z=0,W=1},
            Translation={X=job.center.X,Y=job.center.Y,
                Z=job.center.Z+rise+(1-zScale)*(job.crest or 0)},
            Scale3D={X=1,Y=1,Z=zScale}}
    end
    function R.geometry(job,layer)
        local vertices,indices,normals,uv={},{},{},{}
        local top=layer==0 and 12 or -12
        local bottom=layer==0 and -12 or -252
        -- Shared texture coordinates meet exactly: one unbroken gradient tail.
        local vTop=layer==0 and 0.5/512 or 32/512
        local vBottom=layer==0 and 32/512 or 511.5/512
        for i=0,job.count do
            local p=job.points[i%job.count+1]
            local angle=2*math.pi*i/job.count
            local x,y=job.radius*math.cos(angle),job.radius*math.sin(angle)
            local z=p and p.Z or 0
            vertices[#vertices+1]={X=x,Y=y,Z=z+top}
            vertices[#vertices+1]={X=x,Y=y,Z=z+bottom}
            for _=1,2 do normals[#normals+1]={X=math.cos(angle),Y=math.sin(angle),Z=0} end
            uv[#uv+1]={X=0.5,Y=vTop}
            uv[#uv+1]={X=0.5,Y=vBottom}
            if i<job.count and p and job.points[(i+1)%job.count+1] then
                local a=2*i
                for _,n in ipairs({a,a+1,a+2,a+2,a+1,a+3}) do indices[#indices+1]=n end
            end
        end
        return vertices,indices,normals,uv
    end
    function R.prepare(s,actor)
        if E.config.upgradeRibbon==false then return end
        local v=actor.AreaRange:K2_GetComponentLocation()
        local height=tonumber(E.config.upgradeEffectHeight) or 600
        if height~=height then height=600 end
        s.ribbon={radius=s.radius,count=math.min(160,math.ceil(math.max(64,2*math.pi*s.radius/300)/8)*8),
            center={X=v.X,Y=v.Y,Z=v.Z},points={},nextPoint=0,nextLayer=0,
            height=math.max(100,math.min(2000,height)),materials={},hits=0}
        -- Meet the currently visible boundary, then bounce it to the new radius.
        if E.config.upgradeWave~=false then
            s.ribbon.wave=Wave.new(s.ribbon,s.animation and s.animation.from or s.radius)
        end
    end
    function R.cleanup(s)
        local job=s.ribbon
        if not job then return end
        local c=A.resolve(job.component)
        if c then
            E.guard('ribbon cleanup',function()
                c:SetVisibility(false,false)
                local owner=c:GetOwner()
                if E.valid(owner) then c:K2_DestroyComponent(owner) end
            end)
        end
        if job.component then A.forget(job.component) end
        if job.texture then A.forget(job.texture) end
        if job.wave and job.wave.texture then A.forget(job.wave.texture) end
        for _,p in ipairs(job.materials) do A.forget(p) end
        s.ribbon=nil
    end
    local function create(job,actor)
        local class=assert(A.resolve('/Script/ProceduralMeshComponent.ProceduralMeshComponent'),
            'Procedural mesh runtime unavailable')
        local c=actor:AddComponentByClass(class,false,{
            Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1},
        },false)
        assert(E.valid(c),'Could not create contour component')
        job.component=A.path(c)
        c:SetVisibility(false,false)
        c:SetCollisionEnabled(0)
        c:SetGenerateOverlapEvents(false)
        c:SetIsReplicated(false)
        c:SetCastShadow(false)
        c:K2_SetWorldTransform({Rotation={X=0,Y=0,Z=0,W=1},Translation=job.center,
            Scale3D={X=1,Y=1,Z=1}},false,{},true)
        return c
    end
    local function material(job,actor,c,layer,ground)
        local parent=A.resolve(materialPath)
        if not parent then LoadAsset(materialPath);parent=A.resolve(materialPath) end
        assert(parent,'Native glow material unavailable')
        local mid=c:CreateDynamicMaterialInstance(layer,parent,FName('None'))
        assert(E.valid(mid),'Contour material unavailable')
        job.materials[layer+1]=A.path(mid)
        local tint=ground and {R=0.10,G=1.5,B=4.0,A=1}
            or layer==0 and {R=0.7,G=2.0,B=3.5,A=1} or {R=0.05,G=1.4,B=3.0,A=1}
        mid:SetVectorParameterValue(FName('Color01'),tint)
        mid:SetVectorParameterValue(FName('Color02'),{R=0,G=0.9,B=2.5,A=1})
        local holder=ground and job.wave or job
        local texture=A.resolve(holder.texture)
        if not texture then
            texture=A.resolve('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(
                actor,E.root..(ground and 'assets/ground-wave.png' or 'assets/contour-gradient.png'))
            assert(E.valid(texture),'Glow gradient unavailable')
            holder.texture=A.path(texture)
        end
        mid:SetTextureParameterValue(FName('Texture01'),texture)
        for _,suffix in ipairs({'01','02'}) do
            for _,name in ipairs({'OffsetU_','OffsetV_','ScrollingU_','ScrollingV_',
                'DistortionScaleU_','DistortionScaleV_'}) do
                mid:SetScalarParameterValue(FName(name..suffix),0)
            end
            mid:SetScalarParameterValue(FName('TilingU_'..suffix),1)
            mid:SetScalarParameterValue(FName('TilingV_'..suffix),1)
        end
        mid:SetScalarParameterValue(FName('DistortionScale'),0)
        mid:SetScalarParameterValue(FName('RGBScale02'),0)
        mid:SetScalarParameterValue(FName('AlphaScale01'),0)
        mid:SetScalarParameterValue(FName('AlphaScale02'),0)
        if ground then
            mid:SetScalarParameterValue(FName('SoftEdge'),8)
            mid:SetScalarParameterValue(FName('RGBScale01'),5)
        end
        return mid
    end
    local function terrain(lib,job,actor,x,y)
        local color={R=0,G=0,B=0,A=0}
        local out={}
        x,y=x+job.center.X,y+job.center.Y
        local found=lib:LineTraceSingleForObjects(actor,{X=x,Y=y,Z=job.center.Z+5000},
            {X=x,Y=y,Z=job.center.Z-5000},{0},true,{actor},0,out,true,color,color,0)
        local hit=out.OutHit or out
        if found and hit.ImpactPoint then return hit.ImpactPoint.Z-job.center.Z+12 end
    end
    function R.sample(s,actor,budget,deadline)
        local job=s.ribbon
        if not job then return 0 end
        deadline=deadline or os.clock()+R.sampleBudget
        if budget<1 or os.clock()>=deadline then return 0 end
        -- Validate this stable library once per batch, not for every sample.
        local lib=A.resolve('/Script/Engine.Default__KismetSystemLibrary')
        local used=0
        if job.nextPoint<job.count then
            while job.nextPoint<job.count and used<budget and os.clock()<deadline do
                local i=job.nextPoint
                job.nextPoint,used=i+1,used+1
                local angle=2*math.pi*i/job.count
                local z=terrain(lib,job,actor,job.radius*math.cos(angle),job.radius*math.sin(angle))
                if z then
                    job.points[i+1]={Z=z}
                    job.hits=job.hits+1
                    job.crest=math.max(job.crest or z,z)
                else job.points[i+1]=false end
            end
            if job.nextPoint<job.count then return used end
        end
        if job.wave and not job.wave.ready then
            used=used+Wave.sample(job.wave,job,function(x,y) return terrain(lib,job,actor,x,y) end,budget-used,deadline)
        end
        if not job.wave or job.wave.ready then
            job.sampled=true
        end
        return used
    end
    function R.step(s,actor,time,budget,deadline)
        local job=s.ribbon
        if not job then return 0 end
        deadline=deadline or os.clock()+R.sampleBudget
        if not job.sampled then return R.sample(s,actor,budget,deadline) end
        if job.nextLayer<R.layers then
            if budget<1 or os.clock()>=deadline then return 0 end
            local c=A.resolve(job.component) or create(job,actor)
            local layer=job.nextLayer
            local vertices,indices,normals,uv=R.geometry(job,layer)
            -- Stable eight-argument reflected API; no collision cooking.
            c:CreateMeshSection(layer,vertices,indices,normals,uv,{},{},false)
            material(job,actor,c,layer,false)
            if job.wave then c:SetMeshSectionVisible(layer,false) end
            job.nextLayer=layer+1
            return budget -- at most one mesh section created per update
        end
        if job.wave then
            local w=job.wave
            local c=A.resolve(job.component)
            assert(c,'Wave component expired')
            if not w.mesh then
                if budget<1 or os.clock()>=deadline then return 0 end
                local vertices,indices,normals,uv=Wave.geometry(w)
                assert(#indices>0,'No continuous terrain available for Palbox wave')
                c:CreateMeshSection(2,vertices,indices,normals,uv,{},{},false)
                material(job,actor,c,2,true)
                w.mesh=true
                if s.upgradeScreens then E.log('effect setup ready; waiting for Base Upgrade to close') end
                return budget
            end
            if not w.started and s.upgradeScreens then return 0 end
            local mid=assert(A.resolve(job.materials[3]),'Wave material expired')
            if not w.started then
                w.started=time
                c:SetHiddenInGame(false,false);c:SetVisibility(true,false)
                E.log(string.format('Palbox wave started: %d/%d ground samples; wave -> bounce -> rise',w.hits,#w.points))
            end
            if not w.arrived then
                local p,done=Wave.progress(time-w.started)
                mid:SetScalarParameterValue(FName('OffsetV_01'),0.45*p)
                mid:SetScalarParameterValue(FName('AlphaScale01'),smooth((time-w.started)/0.12))
                if done then
                    w.arrived=time
                    if s.animation then s.animation.waiting=nil;s.animation.start=time end
                    E.log('Palbox wave reached boundary; bounce started')
                end
                return 0
            elseif not w.hidden then
                local fade=1-smooth((time-w.arrived)/Wave.fade)
                mid:SetScalarParameterValue(FName('AlphaScale01'),fade)
                mid:SetScalarParameterValue(FName('RGBScale01'),5*fade)
                if fade==0 then c:SetMeshSectionVisible(2,false);w.hidden=true end
            end
        end
        if s.animation then return 0 end -- hidden until the bounce fully settles
        local c=A.resolve(job.component)
        if not c then R.cleanup(s);return 0 end
        if not job.started then
            job.started=time
            if job.wave then
                c:SetMeshSectionVisible(2,false)
                c:SetMeshSectionVisible(0,true);c:SetMeshSectionVisible(1,true)
            end
            c:SetHiddenInGame(false,false)
            c:SetVisibility(true,false)
            E.log(string.format('contour rise started: %d/%d terrain samples, %d continuous sections, %.0f cm height; relief eases to 35%%',
                job.hits,job.count,R.layers,job.height))
        end
        local elapsed=time-job.started
        if elapsed<0 or elapsed>=R.duration then R.cleanup(s);return 0 end
        local rise,headAlpha,trailAlpha,headLight=R.envelope(elapsed,job.height)
        c:K2_SetWorldTransform(R.pose(job,elapsed,rise),false,{},true)
        for i=1,R.layers do
            local p=job.materials[i]
            local mid=A.resolve(p)
            if mid then
                local alpha=i==1 and headAlpha or trailAlpha*0.95
                local light=i==1 and headLight*4 or trailAlpha*5
                mid:SetScalarParameterValue(FName('AlphaScale01'),alpha)
                -- Emissive intensity makes the flash/fade visible even when
                -- the material's opacity expression would otherwise saturate.
                mid:SetScalarParameterValue(FName('RGBScale01'),light)
            end
        end
        return 0
    end
    return R
end

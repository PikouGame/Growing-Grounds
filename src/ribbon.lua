-- Terrain-shaped rising contour: one component, no Niagara simulations.
return function(E,A)
    local R={layers=2,duration=2.8}
    local materialPath='/Game/Pal/Effect/Material_Instances/Particle_basic_color/MI_LightUpGlow.MI_LightUpGlow'
    local function smooth(t) t=math.max(0,math.min(1,t));return t*t*(3-2*t) end
    function R.envelope(elapsed,height)
        local t=math.max(0,math.min(1,elapsed/R.duration))
        local rise=height*(1-(1-t)^3) -- keeps moving until fully invisible
        local appear=smooth(elapsed/0.12)
        local fade=1-smooth((elapsed-1.6)/1.2)
        -- Soften the tail before the flash, retaining a glow through the
        -- finish. Both parts share the final fade while still moving.
        local trail=appear*(1-0.4*smooth((elapsed-0.65)/0.6))*fade
        local flash=smooth((elapsed-1.3)/0.25)*(1-smooth((elapsed-1.65)/0.35))
        return rise,appear*fade,trail,(1+4*flash)*fade
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
        local height=tonumber(E.config.upgradeEffectHeight) or 800
        if height~=height then height=800 end
        s.ribbon={radius=s.radius,count=math.ceil(math.max(64,2*math.pi*s.radius/300)/8)*8,
            center={X=v.X,Y=v.Y,Z=v.Z},points={},nextPoint=0,nextLayer=0,
            height=math.max(100,math.min(2000,height)),materials={},hits=0}
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
    function R.step(s,actor,time,budget)
        local job=s.ribbon
        if not job then return 0 end
        if job.nextPoint<job.count then
            local lib=A.resolve('/Script/Engine.Default__KismetSystemLibrary')
            local color={R=0,G=0,B=0,A=0}
            local used=0
            while job.nextPoint<job.count and used<budget do
                local i=job.nextPoint
                job.nextPoint,used=i+1,used+1
                local angle=2*math.pi*i/job.count
                local x,y=job.center.X+job.radius*math.cos(angle),job.center.Y+job.radius*math.sin(angle)
                local out={}
                local found=lib:LineTraceSingleForObjects(actor,{X=x,Y=y,Z=job.center.Z+5000},
                    {X=x,Y=y,Z=job.center.Z-5000},{0},true,{actor},0,out,true,color,color,0)
                local hit=out.OutHit or out
                if found and hit.ImpactPoint then
                    job.points[i+1]={Z=hit.ImpactPoint.Z-job.center.Z+12}
                    job.hits=job.hits+1
                else job.points[i+1]=false end
            end
            return used
        end
        if job.nextLayer<R.layers then
            if budget<1 then return 0 end
            local c=A.resolve(job.component) or create(job,actor)
            local parent=A.resolve(materialPath)
            if not parent then LoadAsset(materialPath);parent=A.resolve(materialPath) end
            assert(parent,'Native glow material unavailable')
            local layer=job.nextLayer
            local vertices,indices,normals,uv=R.geometry(job,layer)
            -- Stable eight-argument reflected API; no collision cooking.
            c:CreateMeshSection(layer,vertices,indices,normals,uv,{},{},false)
            local mid=c:CreateDynamicMaterialInstance(layer,parent,FName('None'))
            assert(E.valid(mid),'Contour material unavailable')
            job.materials[#job.materials+1]=A.path(mid)
            -- Brighter pale-cyan core, saturated cyan trail for daylight contrast.
            local tint=layer==0 and {R=0.7,G=2.0,B=3.5,A=1} or {R=0.05,G=1.4,B=3.0,A=1}
            mid:SetVectorParameterValue(FName('Color01'),tint)
            mid:SetVectorParameterValue(FName('Color02'),{R=0,G=0.9,B=2.5,A=1})
            local texture=A.resolve(job.texture)
            if not texture then
                local rendering=A.resolve('/Script/Engine.Default__KismetRenderingLibrary')
                texture=rendering:ImportFileAsTexture2D(actor,E.root..'assets/contour-gradient.png')
                assert(E.valid(texture),'Contour gradient unavailable')
                job.texture=A.path(texture)
            end
            -- Material reference retains the imported texture across GC. Disable
            -- the native scrolling/line layers that broke the trail into stripes.
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
            job.nextLayer=layer+1
            return budget -- at most one mesh section created per update
        end
        if s.animation then return 0 end -- hidden until the bounce fully settles
        local c=A.resolve(job.component)
        if not c then R.cleanup(s);return 0 end
        if not job.started then
            job.started=time
            c:SetHiddenInGame(false,false)
            c:SetVisibility(true,false)
            E.log(string.format('contour rise started: %d/%d terrain samples, %d continuous sections, %.0f cm height',
                job.hits,job.count,R.layers,job.height))
        end
        local elapsed=time-job.started
        if elapsed<0 or elapsed>=R.duration then R.cleanup(s);return 0 end
        local rise,headAlpha,trailAlpha,headLight=R.envelope(elapsed,job.height)
        c:K2_SetWorldLocation({X=job.center.X,Y=job.center.Y,Z=job.center.Z+rise},false,{},true)
        for i,p in ipairs(job.materials) do
            local mid=A.resolve(p)
            if mid then
                local alpha=i==1 and headAlpha or trailAlpha*0.95
                local light=i==1 and headLight*4 or trailAlpha*5
                mid:SetScalarParameterValue(FName('AlphaScale01'),alpha)
                mid:SetScalarParameterValue(FName('AlphaScale02'),0)
                -- Emissive intensity makes the flash/fade visible even when
                -- the material's opacity expression would otherwise saturate.
                mid:SetScalarParameterValue(FName('RGBScale01'),light)
                mid:SetScalarParameterValue(FName('RGBScale02'),0)
            end
        end
        return 0
    end
    return R
end

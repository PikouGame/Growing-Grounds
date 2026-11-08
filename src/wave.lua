-- Static terrain surface for the Palbox pulse. The material moves the light;
-- geometry and ground traces never run again during the visible sweep.
local W={duration=2.4,fade=0.3}
function W.new(job,radius)
    radius=radius or job.radius
    local w={rings={},points={},nextPoint=1,hits=0,radius=radius}
    local steps=math.max(1,math.min(18,math.ceil(radius/400)))
    local function ring(radius,count,edge)
        local r={first=#w.points+1,count=count};w.rings[#w.rings+1]=r
        for i=0,count-1 do
            local a=2*math.pi*i/count
            local p={X=radius*math.cos(a),Y=radius*math.sin(a),radius=radius}
            if edge then p.edge=i+1 end -- reuse heights only for the same circle
            w.points[#w.points+1]=p
        end
    end
    ring(0,1)
    for k=1,steps do
        local count=k==steps and job.count or math.max(8,math.ceil(job.count*k/steps/8)*8)
        ring(radius*k/steps,count,k==steps and math.abs(radius-job.radius)<0.1)
    end
    return w
end
function W.sample(w,job,trace,budget,deadline)
    local used=0
    deadline=deadline or os.clock()+0.002
    while w.nextPoint<=#w.points do
        local p=w.points[w.nextPoint]
        if p.edge then
            local edge=job.points[p.edge]
            p.Z=edge and edge.Z or nil
        else
            if used>=budget or os.clock()>=deadline then break end
            p.Z=trace(p.X,p.Y)
            used=used+1
        end
        if p.Z then w.hits=w.hits+1 end
        w.nextPoint=w.nextPoint+1
    end
    w.ready=w.nextPoint>#w.points
    return used
end
function W.geometry(w,job)
    local vertices,indices,normals,uv={},{},{},{}
    for _,p in ipairs(w.points) do
        vertices[#vertices+1]={X=p.X,Y=p.Y,Z=p.Z or 0}
        normals[#normals+1]={X=0,Y=0,Z=1}
        -- UV+offset stays inside [0,.9]. Black padding prevents repeated rings
        -- even when the native material uses a wrapping texture sampler.
        uv[#uv+1]={X=0.5,Y=0.45*(1-p.radius/w.radius)}
    end
    local function triangle(a,b,c)
        local pa,pb,pc=w.points[a],w.points[b],w.points[c]
        if not(pa.Z and pb.Z and pc.Z) then return end
        local function continuous(p,q)
            local dx,dy,dz=p.X-q.X,p.Y-q.Y,p.Z-q.Z
            return dz*dz<=4*(dx*dx+dy*dy)+1 -- do not bridge a cliff with a glowing ramp
        end
        if not(continuous(pa,pb) and continuous(pb,pc) and continuous(pc,pa)) then return end
        indices[#indices+1]=a-1;indices[#indices+1]=b-1;indices[#indices+1]=c-1
    end
    local function at(r,i) return r.first+i%r.count end
    for k=2,#w.rings do
        local inner,outer=w.rings[k-1],w.rings[k]
        if inner.count==1 then
            for j=0,outer.count-1 do triangle(inner.first,at(outer,j),at(outer,j+1)) end
        else
            -- Merge the two angular sequences, closing the seam with shared
            -- vertices. Fewer samples near the Palbox keep preparation bounded.
            local i,j=0,0
            while i<inner.count or j<outer.count do
                local a,b=(i+1)*outer.count,(j+1)*inner.count
                if a<b then triangle(at(inner,i),at(outer,j),at(inner,i+1));i=i+1
                elseif b<a then triangle(at(inner,i),at(outer,j),at(outer,j+1));j=j+1
                else
                    triangle(at(inner,i),at(outer,j),at(outer,j+1))
                    triangle(at(inner,i),at(outer,j+1),at(inner,i+1))
                    i,j=i+1,j+1
                end
            end
        end
    end
    return vertices,indices,normals,uv
end
function W.progress(elapsed)
    local t=math.max(0,math.min(1,elapsed/W.duration))
    return t*(2-t),t==1
end
return W

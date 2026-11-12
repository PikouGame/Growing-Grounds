-- Narrow, separated strips on the ground. Both edges and each dash midpoint
-- are sampled: hills change the surface, never the height of an upright wall.
local D={width=40,lift=2}
function D.prepare(job)
    local count=math.max(16,math.min(192,math.ceil(2*math.pi*job.radius/400)))
    job.samplePoints={}
    job.groundLift=D.lift
    for i=0,count-1 do
        for step=0,2 do
            local angle=2*math.pi*(i+step/4)/count
            for _,r in ipairs({job.radius-D.width/2,job.radius+D.width/2}) do
                job.samplePoints[#job.samplePoints+1]={X=r*math.cos(angle),Y=r*math.sin(angle)}
            end
        end
    end
    job.count=#job.samplePoints
end
function D.geometry(job)
    local vertices,indices,normals,uv={},{},{},{}
    for i,p in ipairs(job.samplePoints) do
        local ground=job.points[i]
        vertices[i]={X=p.X,Y=p.Y,Z=ground and ground.Z or 0}
        normals[i]={X=0,Y=0,Z=1}
        uv[i]={X=0.5,Y=0.5/512}
    end
    local function triangle(a,b,c)
        if not(job.points[a] and job.points[b] and job.points[c]) then return end
        local pa,pb,pc=vertices[a],vertices[b],vertices[c]
        local function continuous(p,q)
            local dx,dy,dz=p.X-q.X,p.Y-q.Y,p.Z-q.Z
            return dz*dz<=2.25*(dx*dx+dy*dy)+1
        end
        -- Omit missing terrain and cliffs rather than stretching over them.
        if not(continuous(pa,pb) and continuous(pb,pc) and continuous(pc,pa)) then return end
        indices[#indices+1]=a-1;indices[#indices+1]=b-1;indices[#indices+1]=c-1
    end
    for first=1,job.count,6 do
        for step=0,1 do
            local a=first+step*2
            triangle(a,a+1,a+2);triangle(a+2,a+1,a+3)
        end
    end
    return vertices,indices,normals,uv
end
return D

local root=assert(arg[1],'pass root with trailing slash')
local W=dofile(root..'src/wave.lua')
local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a)..' != '..tostring(b)) end
for _,radius in ipairs({3500,4900,7000,14000}) do
    local count=math.min(160,math.ceil(math.max(64,2*math.pi*radius/300)/8)*8)
    local job={radius=radius,count=count,points={}}
    for i=1,count do job.points[i]={Z=12} end
    local w=W.new(job)
    assert(#w.points<=1600,'setup size must remain bounded at the +300% bonus cap')
    local calls=0
    while not w.ready do
        local before=calls
        local used=W.sample(w,job,function() calls=calls+1;return 12 end,4)
        assert(used==calls-before and used<=4)
    end
    assert(calls==#w.points-count,'boundary samples must be reused')
    local vertices,indices,normals,uv=W.geometry(w,job)
    assert(#vertices==#w.points and #normals==#vertices and #uv==#vertices)
    local area,edges=0,{}
    for i=1,#indices,3 do
        local ids={indices[i],indices[i+1],indices[i+2]}
        local a,b,c=vertices[ids[1]+1],vertices[ids[2]+1],vertices[ids[3]+1]
        local cross=(b.X-a.X)*(c.Y-a.Y)-(b.Y-a.Y)*(c.X-a.X)
        assert(cross>0,'all triangles wind consistently without degeneracy')
        area=area+cross/2
        for k=1,3 do
            local x,y=ids[k],ids[k%3+1]
            local key=math.min(x,y)..':'..math.max(x,y)
            edges[key]=(edges[key] or 0)+1
        end
    end
    local perimeter=0
    for _,n in pairs(edges) do assert(n==1 or n==2);if n==1 then perimeter=perimeter+1 end end
    assert(perimeter==count,'no interior cracks or open angular seam')
    near(area/(radius*radius),count*math.sin(2*math.pi/count)/2)
    for _,p in ipairs(uv) do
        assert(p.Y>=-1e-10 and p.Y<=0.45)
        for _,t in ipairs({0,0.5,1}) do assert(p.Y+0.45*t>=-1e-10 and p.Y+0.45*t<=0.900001) end
    end
    -- One missing terrain sample cannot be silently filled with a flat patch.
    local middle=math.floor(#w.points/2);w.points[middle].Z=nil
    local _,hole=W.geometry(w,job)
    assert(#hole<#indices)
    for _,id in ipairs(hole) do assert(id~=middle-1) end
    w.points[middle].Z=100000
    local _,cliff=W.geometry(w,job)
    for _,id in ipairs(cliff) do assert(id~=middle-1,'do not bridge sharp vertical relief') end
end
local previous=-1
local endFrame=math.floor(W.duration*100+0.5)
for i=0,endFrame do
    local p,done=W.progress(i/100)
    assert(p>=previous and p>=0 and p<=1 and done==(i==endFrame));previous=p
end
near(W.progress(0),0);near(W.progress(W.duration),1)
-- The shared deadline, not only the sample count, limits an expensive scene.
local savedClock=os.clock
local clock=0
os.clock=function() return clock end
local job={radius=4900,count=104,points={}}
local w=W.new(job)
local used=W.sample(w,job,function() clock=clock+0.001;return 12 end,48,0.002)
assert(used==2 and not w.ready,'sampling must yield when the shared time budget is spent')
assert(W.sample(w,job,function() error('expired deadline must not trace') end,48,0.002)==0)
clock=0;w=W.new(job)
assert(W.sample(w,job,function() clock=clock+0.003;return 12 end,48,0.002)==1,
    'a slow native call cannot be interrupted, but no further sample may start')
clock=0;w=W.new(job)
assert(W.sample(w,job,function() return 12 end,48,0.002)==48,
    'cheap traces can fill the batch without exceeding the elapsed-time deadline')
os.clock=savedClock
print('PASS: bounded adaptive ground grid, closed surface, shared boundary samples, holes/cliffs, nonrepeating UVs, sweep endpoints')

-- Presentation state only. No UObject references or gameplay writes.
local M = {duration=1.15, wait=10}
local function smooth(t) return t*t*(3-2*t) end
function M.sample(s, now)
    if not s.animation then return s.radius, 1 end
    local a = s.animation
    if a.waiting then return a.from,0 end -- the Palbox wave reaches the edge first
    local t = math.max(0, math.min(1, (now-a.start)/M.duration))
    if now >= a.start+M.duration then t=1 end
    local k
    if t < 0.68 then k = 1.06*smooth(t/0.68)
    else k = 1.06-0.06*smooth((t-0.68)/0.32) end
    return a.from+(s.radius-a.from)*k, t
end
function M.new(level, radius, now)
    return {level=level, radius=radius, last=now}
end
function M.observe(s, level, radius, now, enabled)
    if not s or now < s.last or now-s.last > 12 or not enabled or radius < s.radius-0.1 then
        return M.new(level,radius,now), 'snap'
    end
    s.last = now
    -- Require both a level increase and a larger replicated radius. Either
    -- property may arrive first; retain the previous presentation meanwhile.
    if level > s.level and radius > s.radius+0.1 then
        local from = M.sample(s,now)
        s.level, s.radius, s.pending = level, radius, nil
        s.animation = {from=from,start=now}
        return s, 'start'
    end
    if level ~= s.level or math.abs(radius-s.radius)>0.1 then
        s.pending = s.pending or now
        if now-s.pending >= M.wait then return M.new(level,radius,now), 'snap' end
    else s.pending = nil end
    return s, 'keep'
end
function M.finish(s) s.animation = nil end
return M

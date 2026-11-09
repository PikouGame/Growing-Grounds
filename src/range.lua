-- Shared, game-independent calculation. This is NOT a UE4SS entry point.
-- Runtime integration must supply the original (unmodified) radius and the
-- server-authoritative guild/base level. Never feed the modified radius back in.
local Range = {}

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function validLevel(level)
    assert(finite(level) and level >= 1 and level % 1 == 0,
        "base level must be a positive integer")
end

-- 200% is a hard ceiling as well as the default. Invalid administrator input
-- falls back to defaults; neither a corrupt file nor NaN can disable the cap.
function Range.settings(settings)
    settings = settings or {}
    local growth, cap = settings.growthPercentPerLevel, settings.maxRangePercent
    if not finite(growth) then growth = 5 end
    if not finite(cap) then cap = 200 end
    return {growthPercentPerLevel=math.max(0, math.min(20, growth)),
        maxRangePercent=math.max(100, math.min(200, cap))}
end

function Range.percent(level, settings)
    validLevel(level)
    local policy = Range.settings(settings)
    return math.min(policy.maxRangePercent, 100 + policy.growthPercentPerLevel * (level - 1))
end

function Range.radius(originalRadius, level, settings)
    assert(finite(originalRadius) and originalRadius > 0,
        "original radius must be finite and positive")
    local result = originalRadius * (Range.percent(level, settings) / 100)
    assert(finite(result), "calculated radius overflow")
    return result
end

-- Reserve full-sized bases, including future upgrades, at placement time.
function Range.placementDistance(originalRadius, settings)
    assert(finite(originalRadius) and originalRadius > 0, 'invalid original radius')
    return originalRadius * Range.settings(settings).maxRangePercent / 100 * 2
end

-- Legacy worlds can already contain nearby bases. Share only the free space
-- between their vanilla circles, proportionally to maximum possible growth.
-- Reserve future growth too: one guild upgrading cannot shrink its neighbour.
-- Never use previous results: order/reloads cannot ratchet the radius down.
-- XY distance is intentional: vertically stacked bases must not bypass spacing.
function Range.separate(bases)
    local targets, conflicts = {}, {}
    for i, b in ipairs(bases) do
        assert(finite(b.baseline) and b.baseline > 0 and finite(b.desired)
            and b.desired >= b.baseline and finite(b.maximum) and b.maximum >= b.desired
            and finite(b.x) and finite(b.y), 'invalid base geometry')
        targets[i] = b.desired
    end
    for i = 1, #bases do
        for j = i + 1, #bases do
            local a, b = bases[i], bases[j]
            local dx, dy = a.x - b.x, a.y - b.y
            local distance = math.sqrt(dx * dx + dy * dy)
            local free = distance - a.baseline - b.baseline
            local ga, gb = a.maximum - a.baseline, b.maximum - b.baseline
            if free < 0 then
                -- Never shrink below vanilla or destroy/move somebody's base.
                targets[i], targets[j] = a.baseline, b.baseline
                conflicts[#conflicts + 1] = {i=i, j=j, distance=distance}
            elseif ga + gb > free then
                targets[i] = math.min(targets[i], a.baseline + free * ga / (ga + gb))
                targets[j] = math.min(targets[j], b.baseline + free * gb / (ga + gb))
            end
        end
    end
    return targets, conflicts
end

return Range

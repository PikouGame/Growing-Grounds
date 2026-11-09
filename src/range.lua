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

-- Public settings use bonuses: +100% doubles the original radius.
-- Legacy totals retain the old 100..200 clamp before conversion, so updating
-- cannot enlarge a world whose old config exceeded the former hard ceiling.
function Range.settings(settings)
    settings = settings or {}
    local growth, cap = settings.growthPercentPerLevel, settings.maxRangeBonusPercent
    if cap == nil and finite(settings.maxRangePercent) then
        cap = math.max(100, math.min(200, settings.maxRangePercent)) - 100
    end
    if not finite(growth) then growth = 4 end
    if not finite(cap) then cap = 100 end
    local slots = settings.maxChestBonusSlots
    if not finite(slots) then slots = 20 end
    return {growthPercentPerLevel=math.max(0, math.min(20, growth)),
        maxRangeBonusPercent=math.max(0, math.min(300, cap)),
        maxChestBonusSlots=math.max(0, math.min(40, math.floor(slots)))}
end

function Range.percent(level, settings)
    validLevel(level)
    local policy = Range.settings(settings)
    return 100 + math.min(policy.maxRangeBonusPercent, policy.growthPercentPerLevel * (level - 1))
end

-- The chest cap is spread over every base level, the way the game rescales
-- its own base count: level 1 adds nothing, the last level adds the whole cap.
-- maxLevel is the size of the game's level table; 35 in Palworld 1.0.
function Range.storageBonus(level, settings, maxLevel)
    validLevel(level)
    local cap = Range.settings(settings).maxChestBonusSlots
    if not (finite(maxLevel) and maxLevel >= 2 and maxLevel % 1 == 0) then maxLevel = 35 end
    local upgrades = maxLevel - 1
    -- Nearest whole slot. Integer numerators keep an exact half rounding up.
    return math.floor((2 * cap * math.min(level - 1, upgrades) + upgrades) / (2 * upgrades))
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
    return originalRadius * (1 + Range.settings(settings).maxRangeBonusPercent / 100) * 2
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

-- Shared, game-independent calculation. This is NOT a UE4SS entry point.
-- Runtime integration must supply the original (unmodified) radius and the
-- server-authoritative guild/base level. Never feed the modified radius back in.
local Range = {}

-- The one source of the setting maxima: clamps, sliders and the preview decoder derive from it.
Range.limits = {maxRangeBonusPercent=300, maxChestBonusSlots=42, maxPalboxBonusPages=64}
Range.chestSlotStep = 6

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
-- A legacy growth per level of 0 was the other way to switch range off: it
-- still does. Any other legacy growth value is ignored.
function Range.settings(settings)
    settings = settings or {}
    local cap = settings.maxRangeBonusPercent
    if cap == nil and finite(settings.maxRangePercent) then
        cap = math.max(100, math.min(200, settings.maxRangePercent)) - 100
    end
    if not finite(cap) then cap = 100 end
    if settings.growthPercentPerLevel == 0 then cap = 0 end
    local slots = settings.maxChestBonusSlots
    if not finite(slots) then slots = 18 end
    local limits = Range.limits
    slots = math.max(0, math.min(limits.maxChestBonusSlots, slots))
    slots = math.floor(slots / Range.chestSlotStep + 0.5) * Range.chestSlotStep
    local pages = settings.maxPalboxBonusPages
    if not finite(pages) then pages = 32 end
    pages = math.floor(math.max(0, math.min(limits.maxPalboxBonusPages, pages)) + 0.5)
    return {maxRangeBonusPercent=math.max(0, math.min(limits.maxRangeBonusPercent, cap)),
        maxChestBonusSlots=slots, maxPalboxBonusPages=pages}
end

-- A cap spread evenly over the game's base levels: level 1 gives 0, the last
-- level gives the whole cap, and each level between rounds to the nearest whole
-- unit. maxLevel is the size of the game's level table; 35 in Palworld 1.0.
local function spread(cap, level, maxLevel)
    validLevel(level)
    if not (finite(maxLevel) and maxLevel >= 2 and maxLevel % 1 == 0) then maxLevel = 35 end
    local upgrades = maxLevel - 1
    local done = level - 1
    -- A fractional cap is only reached exactly, at the last level.
    if done >= upgrades then return cap end
    -- Integer numerators keep an exact half rounding up.
    return math.min(cap, math.floor((2 * cap * done + upgrades) / (2 * upgrades)))
end

function Range.percent(level, settings, maxLevel)
    return 100 + spread(Range.settings(settings).maxRangeBonusPercent, level, maxLevel)
end

-- A replicated cap is already server-authored. Do not round a legacy server's
-- 20 or 40 to our new settings grid and display slots it did not grant.
function Range.storageAtCap(level, cap, maxLevel)
    assert(finite(cap) and cap >= 0 and cap % 1 == 0 and cap <= Range.limits.maxChestBonusSlots,
        'invalid chest bonus cap')
    return spread(cap, level, maxLevel)
end

function Range.storageBonus(level, settings, maxLevel)
    return Range.storageAtCap(level, Range.settings(settings).maxChestBonusSlots, maxLevel)
end

-- One whole Palbox page per upgrade, starting with none at level 1. This
-- bonus is deliberately independent of the size of the game's level table.
function Range.palboxAtCap(level, cap)
    validLevel(level)
    assert(finite(cap) and cap >= 0 and cap % 1 == 0 and cap <= Range.limits.maxPalboxBonusPages,
        'invalid Palbox bonus cap')
    return math.min(level - 1, cap)
end

function Range.palboxBonus(level, settings)
    return Range.palboxAtCap(level, Range.settings(settings).maxPalboxBonusPages)
end

function Range.radius(originalRadius, level, settings, maxLevel)
    assert(finite(originalRadius) and originalRadius > 0,
        "original radius must be finite and positive")
    local result = originalRadius * (Range.percent(level, settings, maxLevel) / 100)
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

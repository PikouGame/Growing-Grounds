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

function Range.percent(level)
    validLevel(level)
    return 100 + 5 * (level - 1)
end

function Range.radius(originalRadius, level)
    assert(finite(originalRadius) and originalRadius > 0,
        "original radius must be finite and positive")
    local result = originalRadius * (Range.percent(level) / 100)
    assert(finite(result), "calculated radius overflow")
    return result
end

function Range.reward(originalRadius, level, maximumLevel)
    validLevel(level)
    validLevel(maximumLevel)
    assert(level <= maximumLevel, "base level exceeds game maximum")
    local current = Range.radius(originalRadius, level)
    local nextLevel = math.min(level + 1, maximumLevel)
    local nextRadius = Range.radius(originalRadius, nextLevel)
    return {
        label = "Base Range",
        currentRadius = current,
        nextRadius = nextRadius,
        currentPercent = Range.percent(level),
        nextPercent = Range.percent(nextLevel),
        atMaximum = level == maximumLevel,
    }
end

return Range

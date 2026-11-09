return {
    -- Host/server defaults. Local worlds can override these in World Settings.
    -- Each level after 1 adds this percentage of the ORIGINAL radius (0..20).
    growthPercentPerLevel = 5,
    -- Total radius in percent, not bonus/area. 100..200; 200 is a hard ceiling.
    -- Standard 35m radius: 200% = 70m. Reached at level21 with 5% growth.
    maxRangePercent = 200,
    -- To uninstall cleanly: set true on the SERVER, restart, load the world,
    -- verify restored radii in UE4SS.log, save, then remove the mod.
    resetToVanilla = false,
    -- Presentation only: Palbox wave, then a brief boundary bounce and rising glow.
    upgradeAnimation = true,
    -- One rising terrain-shaped contour with a soft trailing glow.
    upgradeRibbon = true,
    -- Blue terrain-following pulse from the Palbox before the boundary bounce.
    upgradeWave = true,
    -- Height in centimetres above the sampled terrain profile.
    upgradeEffectHeight = 600,
}

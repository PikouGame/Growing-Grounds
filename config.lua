return {
    -- Host/server defaults. Local worlds can override these in World Settings.
    -- Each level after 1 adds this percentage of the ORIGINAL radius (0..20).
    growthPercentPerLevel = 5,
    -- Maximum radius BONUS: +100% doubles the radius (35m -> 70m).
    -- World Settings: 0..+300%. +300% means 4x radius, not area.
    -- Set either cap to 0 to disable that bonus. Occupied extra chest slots are preserved.
    -- Old maxRangePercent totals remain supported without changing their effect.
    maxRangeBonusPercent = 100,
    -- +1 chest slot per upgrade, starting at level 2. Bonus cap: 0..40.
    maxChestBonusSlots = 20,
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

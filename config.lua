return {
    -- Host/server defaults. Local worlds can override these in World Settings.
    -- Maximum radius BONUS, reached at the last base level and spread evenly over
    -- the levels before it: +100% doubles the radius (35m -> 70m).
    -- World Settings: 0..+300%. +300% means 4x radius, not area.
    -- Set either cap to 0 to disable that bonus. Occupied extra chest slots are preserved.
    -- Old maxRangePercent totals remain supported without changing their effect.
    -- An old growthPercentPerLevel line is ignored, except 0, which still switches range off.
    maxRangeBonusPercent = 100,
    -- Bonus chest slots at the last base level (0..40), spread evenly over the
    -- levels before it: with 20, +1 at level 2, 5 at level 10, 20 at level 35.
    maxChestBonusSlots = 20,
    -- To uninstall cleanly: set true on the SERVER, restart, load the world,
    -- wait for "reset complete" in UE4SS.log, save, then remove the mod.
    resetToVanilla = false,
    -- Presentation only. Master switch for the whole celebration: Palbox wave,
    -- brief boundary bounce and rising glow. false turns all of it off.
    upgradeAnimation = true,
    -- Glow effects: one rising terrain-shaped contour with a soft trailing glow.
    -- false turns them off, and the wave below with them; the bounce stays.
    upgradeRibbon = true,
    -- Blue terrain-following pulse from the Palbox before the boundary bounce.
    -- Needs upgradeRibbon = true.
    upgradeWave = true,
    -- Height in centimetres above the sampled terrain profile (kept within 100..2000).
    upgradeEffectHeight = 600,
}

return {
    -- Host/server defaults. Local worlds can override these in World Settings.
    -- Independent radius gain per base upgrade (0..20%; default 4).
    -- Zero disables range growth without changing the cap below.
    growthPercentPerLevel = 4,
    -- Maximum radius BONUS (0..300%; default 100). +100% doubles the radius.
    -- Growth stops at this cap; a low per-level gain may not reach it at level 35.
    -- Whole-percent rewards. Legacy maxRangePercent totals remain supported.
    maxRangeBonusPercent = 100,
    -- Bonus chest slots at the last base level (0..42, in steps of 6), spread
    -- evenly over the levels: with 18, +1 at level 2, 5 at level 10, 18 at level 35.
    -- Other values round to the nearest step (20 -> 18; 40 -> 42).
    maxChestBonusSlots = 18,
    -- TOTAL regular Palbox boxes, not extra boxes or Global Palbox storage.
    -- Both settings: 1..96. Start cannot exceed maximum (it is lowered if needed).
    -- Spread whole boxes across all base levels, reaching the total cap at the last.
    -- Defaults: 32 at level 1 -> 64 at level 35. Example: start 1, maximum 16.
    -- Set both equal for a fixed capacity. Occupied/locked/open boxes are kept.
    -- Legacy maxPalboxBonusPages is read as 32 + bonus when no total cap is set.
    startingPalboxBoxes = 32,
    maxPalboxBoxes = 64,
    -- To uninstall cleanly: set true on the SERVER, restart, load the world,
    -- wait for the chest reset in UE4SS.log; every player must also empty their
    -- bonus Palbox boxes and recover the native box count. See INSTALL.txt.
    -- Save, then remove the mod.
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

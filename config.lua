return {
    -- Automatic archives after a clean exit; 120s quiet period, shared 1 GiB cap.
    -- Windows is automatic; Proton needs the one-time setup in BACKUPS.txt.
    automaticBackups = true,
    -- Host/server defaults. Local worlds can override these in World Settings.
    -- Maximum radius BONUS, reached at the last base level and spread evenly over
    -- the levels before it: +100% doubles the radius (35m -> 70m).
    -- World Settings: 0..+300%. +300% means 4x radius, not area.
    -- Set any cap to 0 to disable that bonus. Occupied extra storage is preserved.
    -- Old maxRangePercent totals remain supported without changing their effect.
    -- An old growthPercentPerLevel line is ignored, except 0, which still switches range off.
    maxRangeBonusPercent = 100,
    -- Bonus chest slots at the last base level (0..42, in steps of 6), spread
    -- evenly over the levels: with 18, +1 at level 2, 5 at level 10, 18 at level 35.
    -- Other values round to the nearest step (20 -> 18; 40 -> 42).
    maxChestBonusSlots = 18,
    -- Extra regular Palbox boxes, not individual Pal slots or Global Palbox
    -- storage. One box per base upgrade: level 1 = 0; levels 33..35 = +32.
    -- Cap 0..64, default 32. A higher cap still grants only one per upgrade.
    maxPalboxBonusPages = 32,
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

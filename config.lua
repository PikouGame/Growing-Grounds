return {
    -- To uninstall cleanly: set true on the SERVER, restart, load the world,
    -- verify restored radii in UE4SS.log, save, then remove the mod.
    resetToVanilla = false,
    -- Enable extra logs and hot reload for development; not required to play.
    debug = false,
    -- Presentation only; a server-confirmed upgrade expands and settles in 1.6s.
    upgradeAnimation = true,
    -- One rising terrain-shaped contour with a soft trailing glow.
    upgradeRibbon = true,
    -- Height in centimetres above the sampled terrain profile.
    upgradeEffectHeight = 800,
}

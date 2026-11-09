# Growing Grounds

Give your base room to grow—and enjoy the moment it does.

Growing Grounds adds **5% of the original base radius per level**, starting at
level 2, with a configurable cap of **200%**. The Base Upgrade screen shows your
current and next range using Palworld's own reward-row layout.

## A little celebration for every upgrade

A blue wave travels from the Palbox across the terrain. When it reaches the
boundary, the circle expands with a gentle bounce, then a glowing contour rises
and fades with its trail.

If Base Upgrade is open, the effect prepares after the upgrade is confirmed and
waits for you to close the screen. It plays once the screen is closed and setup
is ready. There is no fixed countdown, no terrain reuse between animations, and
no speculative scanning while you play. The outward wave lasts 2.4 seconds;
the rising effect reaches 6 metres by default.

## Your world's settings

- **Growth per level:** 0–20% of the original radius; default 5%.
- **Maximum radius:** 100–200% of the original radius; default 200%.
- Local worlds have two Growing Grounds sliders at the bottom of custom World
  Settings. Dedicated-server owners configure the same values in `config.lua`.
- Nearby bases can limit growth further. New Palboxes reserve room for both
  bases to reach the cap: 140 m between centres with the default 35 m base and
  200% cap. Stronger native restrictions remain in place.

For a standard 35 m base, level 9 is 49 m (140%). With default growth, level 21
reaches the 70 m cap. Growth is additive, not compounded.

## Install or update

Requires a compatible **UE4SS loader for Palworld**, installed separately.
Install Growing Grounds on the **host/server and clients**; update both sides
for this version's settings and server-supplied next-range preview.

1. Save and close the game/server, and keep a world backup.
2. Copy the `BaseRangeGrowth` folder into your existing UE4SS `Mods` folder.
   A manual loader normally uses `Pal/Binaries/Win64/ue4ss/Mods/`.
   An existing Workshop loader uses `Mods/NativeMods/UE4SS/Mods/`.
3. Preserve your `config.lua` preferences and any `world-settings.ini` / `.bak`
   files when updating. Add new options from the supplied default config as needed.
4. Restart the server and clients. Allow up to five seconds for the initial row.

**Updating from 0.1.1:** the new 200% ceiling and spacing limits can reduce a
previously expanded base. Buildings outside the new boundary may lose base
coverage. Please keep a backup before updating.

See [INSTALL.txt](INSTALL.txt) for configuration, diagnostics and removal.
Use your existing loader installation; the mod does not bundle UE4SS or require
PalSchema. Steam Workshop deployment of this mod remains unverified.

## What changed in 0.1.2-alpha

- Palbox-to-boundary wave, slower outward travel and a shorter rising effect.
- Playback waits for Base Upgrade to close, with fresh, bounded terrain setup.
- Cached engine-object tracking replaces repeated whole-game searches that
  caused the reported five-second freezes on the test setup.
- A lightweight check of tracked base levels/radii every 250 ms avoids waiting
  for the five-second reconciliation when native level hooks miss a change.
- Per-world settings, a 200% ceiling and spacing-aware growth limits.
- Server-supplied current/next percentages and a refined four-arrow range icon.

**Visual timing:** Known visual issue: the celebration can still start late after closing the Palbox. This does not postpone the actual base-radius upgrade. A new lightweight change observer is included; its improvement during a natural upgrade has not yet been verified in game.

## Testing and current limits

Observed with Palworld **v1.0.5.102999** and UE4SS Palworld fork **2281fa31**,
using Windows game/server executables through Proton/Wine. Server/client radius
replication, the 140% → 145% preview, and the screen-close animation replay were
checked in game. The author approved the slower wave and screen-close behavior.
The former periodic freezes stopped on the test setup; broader hardware
performance has not been established.

This is an alpha. World Settings save/cancel/new-world flows, placement rejection,
Pal work and resource access throughout expanded areas, the full reset lifecycle,
conflicts with other range mods, and native Windows OS execution still need
broader in-game verification. The extra reward row is currently English.
If a valid server preview is unavailable, only the current range is shown.

The server owns gameplay radius. Animation changes the visible boundary only.
Existing bases are not moved or deleted. Overlapping original base circles do
not receive extra growth; other nearby bases may reach a lower cap.

## Configuration and preview

Gameplay options: `growthPercentPerLevel`, `maxRangePercent`, `resetToVanilla`.
Visual options: `upgradeAnimation`, `upgradeWave`, `upgradeRibbon`,
`upgradeEffectHeight` (centimetres).

**Ctrl+Shift+F7** replays the effect without changing your level or gameplay
radius. It also works inside Base Upgrade: close the screen to see the prepared
wave. **Ctrl+Shift+F10** writes a diagnostic report. Debug logging and hot reload
are disabled by default; developers can enable `debug=true` in `config.lua`.

## Share your experience

We'd love to see how Growing Grounds fits into your world! Leave a comment,
share a clip, or [report a bug](https://github.com/PikouGame/Growing-Grounds/issues)
so we can investigate and improve it. Game/UE4SS versions, your host/client setup
and steps to reproduce a problem are especially helpful. Please remove personal
information from logs before sharing them.

## Development

Run the Lua checks from this directory:

```sh
lua tests/test_range.lua ./
lua tests/test_settings.lua ./
lua tests/test_objects.lua ./
lua tests/test_preview.lua ./
lua tests/test_ui.lua ./
lua tests/test_wave.lua ./
lua tests/test_motion.lua ./
python3 tools/package.py
python3 tools/release.py
```

Release archives use an explicit runtime allowlist. Research exports, private
sidecars, logs and loader binaries are excluded. The internal folder/mod ID stays
`BaseRangeGrowth`. [Workshop notes](publishing/WORKSHOP.txt) describe the unverified
Workshop packaging route.

## Credits and permissions

Built with OpenAI Codex under lelorax's direction, including code,
documentation and the original icon/glow assets. The author chose the behavior,
tested it in game and supplies real gameplay media. No generated gameplay
imagery or third-party game files are bundled.

Growing Grounds is unofficial. Palworld and its game assets belong to their
respective owners. Follow [Pocketpair's mod guidelines](https://guideline.palworldgame.com/palworld-mod-guideline).

All rights reserved. Downloading and using the mod is allowed. Redistribution,
published modifications and reuse require permission; see [LICENSE.txt](LICENSE.txt).

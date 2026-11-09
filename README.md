# Growing Grounds

Give your base room to grow—and enjoy the moment it does.

Growing Grounds adds **5% of the original base radius per level**, starting at
level 2, with a default bonus cap of **+100%** (double the original radius). The Base Upgrade screen shows your
current and next bonus with metres beside each value: **45% 50.8m → 50% 52.5m**.
The numbers follow Palworld's own reward-row layout.

Chests gain **one extra slot per base upgrade**, up to **20 bonus slots** by
default. Guild Chests receive the bonus once for their shared inventory.

## A little celebration for every upgrade

A blue wave travels from the Palbox across the terrain. When it reaches the
boundary, the circle expands with a gentle bounce, then a glowing contour rises
and fades with its trail.

If Base Upgrade is open, the effect prepares after the upgrade is confirmed and
waits for you to close the screen. It plays once the screen is closed and setup
is ready. There is no fixed countdown, no terrain reuse between animations, and
no speculative scanning while you play. The outward wave lasts 2.4 seconds;
the rising effect lifts 6 metres by default and gradually softens the terrain relief.

## Your world's settings

- **Growth per level:** 0–20% of the original radius; default 5%.
- **Maximum range bonus:** 0 to +300%; default +100%. A +300% bonus means four times the original radius.
- **Bonus chest slots:** +1 per base upgrade from level 2, capped at 20 by default; adjustable from 0 to 40. Guild Chests share one bonus.
- Local worlds have three Growing Grounds sliders at the bottom of custom World
  Settings. Dedicated-server owners configure the same values in `config.lua`.
- Nearby bases can limit growth further. New Palboxes reserve room for both
  bases to reach the cap: 140 m between centres with the default 35 m base and
  +100% bonus cap. Stronger native restrictions remain in place.

For a standard 35 m base, level 9 is 49 m (+40%). With default growth, level 21
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

**Older configurations:** `maxRangePercent=200` is read as a **+100% bonus**,
with the previous cap preserved. New configurations use `maxRangeBonusPercent=100`.
Existing worlds keep their effective limit; saving World Settings converts the
old key automatically. Choose a higher cap explicitly if you want more room.

See [INSTALL.txt](INSTALL.txt) for configuration and removal.
Use your existing loader installation; the mod does not bundle UE4SS or require
PalSchema. Steam Workshop deployment of this mod remains unverified.

## What changed in 0.1.5-alpha

Base Upgrade now previews bonus chest slots alongside range. Set either cap to **0 (Off)** to disable that feature and hide its row. When an upgrade is ready, the next radius in metres follows Palworld’s turquoise highlight. Current metres keep their mint tint.

## What changed in 0.1.4-alpha

The range cap now uses bonus percentages in World Settings and `config.lua`.
The default remains +100%; +300% is the new upper limit. Legacy totals retain
their previous effective cap. Chest capacity now follows base level, including shared Guild Chest storage.
When a lower cap would remove occupied slots, those slots stay accessible until
they are emptied. This version is installed on the test client and dedicated
server. Growth, save/reload, client replication and item transfers have been
checked with native inventories, including occupied overflow across a restart.

## What changed in 0.1.3-alpha

- Gain percentages and compact mint metre labels, with aligned numeric columns.
- A quicker bounce/lift and a rising contour that gradually straightens.
- Removed development keyboard shortcuts, hot reload and profiling code.
- Shared text styling and boundary scaling; one release builder and fewer repeated material writes.

The celebration can still start late after closing the Palbox. This does not
postpone the gameplay radius change. No growth, cap or spacing defaults changed.

## Testing and current limits

Observed with Palworld **v1.0.5.102999** and UE4SS Palworld fork **2281fa31**,
using Windows game/server executables through Proton/Wine. Server/client radius
replication, the 140% → 145% preview, and the screen-close animation replay were
checked in game. The author approved the slower wave and screen-close behavior.
The former periodic freezes stopped on the test setup; broader hardware
performance has not been established.

The 0.1.5 candidate passes ten standalone regression suites. Native tests also
cover empty-slot removal, garbage collection and shared Guild Chest sizing.
The three World Settings rows were checked through the normal new-world menu;
the form was cancelled without creating a world. An earlier intermittent client
crash remains unattributed; this release is not claimed to fix it.

This is an alpha. Saving World Settings and starting a new world, placement rejection,
Pal work and resource access throughout expanded areas, the full reset lifecycle,
conflicts with other range mods, and native Windows OS execution still need
broader in-game verification. The added reward and settings labels are currently English.
If a valid server preview is unavailable, only the current range is shown.

The server owns gameplay radius. Animation changes the visible boundary only.
Existing bases are not moved or deleted. Overlapping original base circles do
not receive extra growth; other nearby bases may reach a lower cap.

## Configuration

Gameplay options: `growthPercentPerLevel`, `maxRangeBonusPercent`, `maxChestBonusSlots`, `resetToVanilla`.
Visual options: `upgradeAnimation`, `upgradeWave`, `upgradeRibbon`,
`upgradeEffectHeight` (centimetres).

There are no mod keyboard shortcuts or hot reload. An old `debug=true` setting
is ignored. Animations start automatically after a qualifying base upgrade.

## Share your experience

We'd love to see how Growing Grounds fits into your world! Leave a comment,
share a clip, or [report a bug](https://github.com/PikouGame/Growing-Grounds/issues)
so we can investigate and improve it. Game/UE4SS versions, your host/client setup
and steps to reproduce a problem are especially helpful. Please remove personal
information from logs before sharing them.

## Development

Run the Lua checks from this directory:

```sh
lua tests/test_main.lua ./
lua tests/test_changes.lua ./
lua tests/test_range.lua ./
lua tests/test_settings.lua ./
lua tests/test_storage.lua ./
lua tests/test_objects.lua ./
lua tests/test_preview.lua ./
lua tests/test_ui.lua ./
lua tests/test_wave.lua ./
lua tests/test_motion.lua ./
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

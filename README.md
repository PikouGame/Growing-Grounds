# Growing Grounds

Give your base room to grow—and enjoy the moment it does.

Growing Grounds makes your base's radius grow with its level. Choose both the
**gain per upgrade** and the **maximum bonus**, independently. Defaults:
**+4% per upgrade, capped at +100%** (double radius). The Base Upgrade screen
shows whole-percent rewards with metres: **36% 47.6m → 40% 49m**.

Chests grow with your base: **18 bonus slots** by default, arriving steadily
from your first upgrade to the final base level. Guild Chests receive the bonus
once for their shared inventory.

Choose how many regular **Palbox boxes** you start with and their **total cap**.
Defaults: **32 at base level 1 → 64 at the last level**. Whole boxes unlock
steadily across all base levels. You can instead choose **1 → 16**, or set both
values equal for a fixed capacity. Each player follows their guild level once;
extra bases do not multiply storage. The Global Palbox is separate.

The restored independent range controls and starting/total-cap Palbox feature
are **unreleased development changes**. The
published 0.2.0-beta still uses the earlier extra-box cap. New native-game
validation is pending; automated checks do not establish live save compatibility.

## A little celebration for every upgrade

A blue wave travels from the Palbox across the terrain. When it reaches the
boundary, the circle expands with a gentle bounce, then a glowing contour rises
and fades with its trail.

If Base Upgrade is open, the effect prepares after the upgrade is confirmed and
waits for you to close the screen. It plays once the screen is closed and setup
is ready. There is no fixed countdown, no terrain reuse between animations, and
no speculative scanning while you play. The outward wave lasts 2.4 seconds;
the rising effect lifts 6 metres by default and gradually softens the terrain relief.

## Save files

Automatic GG backups are archived and removed from this development build,
including the companion and bundled Python runtime. Palworld's own backups
are unchanged. Existing GG archives remain available; this update does not
remove them. See [INSTALL.txt](INSTALL.txt) when replacing a build that used
the old companion or Proton launcher.

## Your world's settings

- **Range bonus per upgrade:** 0 to 20%; default 4%. 0 disables range growth without erasing the maximum.
- **Maximum range bonus:** 0 to +300%; default +100%. A +300% bonus means four times the original radius. This is a ceiling; a low gain may not reach it by level 35.
- **Bonus chest slots:** 18 by default, spread evenly over all base levels; adjustable from 0 to 42 in steps of six. Guild Chests share one bonus.
- **Starting Palbox boxes:** 1–96; default 32. This is the total at base level 1.
- **Maximum total Palbox boxes:** 1–96; default 64, including the starting boxes.
  Raising the start above the maximum raises the maximum; lowering the maximum
  below the start lowers the start. Existing occupied, locked or open boxes remain
  until cleared/closed, even if they exceed the chosen capacity.
- Local worlds have five Growing Grounds sliders beside the native base/building
  controls in custom World Settings. Dedicated-server owners configure the same values in `config.lua`.
- Old `maxPalboxBonusPages` settings migrate to a starting count of 32 and a total
  cap of 32 + the old bonus. The new spread replaces the old +1-per-upgrade rule.
  Explicit `maxPalboxBoxes` takes precedence. Update both server and clients.
- Nearby bases can limit growth further. New Palboxes reserve room for both
  bases to reach the cap: 140 m between centres with the default 35 m base and
  +100% bonus cap. Stronger native restrictions remain in place.

For a standard 35 m base with the defaults, level 11 is 49 m (+40%) and
level 26 reaches the cap of 70 m (+100%), retained through level 35. Each level's
bonus is a whole percent of the original radius.

## Install or update

Requires a compatible **UE4SS loader for Palworld**, installed separately.
The loader must provide `ExecuteInGameThreadWithDelay` and
`LoopInGameThreadWithDelay` (available in the tested Palworld fork **2281fa31**).
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
Existing `growthPercentPerLevel` values are used again, independently of the
cap, within 0–20%. `0` keeps range growth off; a missing value defaults to 4%.

See [INSTALL.txt](INSTALL.txt) for configuration and removal.
Use your existing loader installation; the mod does not bundle UE4SS or require
PalSchema. Steam Workshop deployment of this mod remains unverified.

## Published 0.2.0-beta history

This section describes the published build. The development settings above
restore independent range growth and replace the Palbox bonus cap with totals.

Three bonuses, native reward rows and the game's own languages.
The Palbox bonus has been checked in dedicated-server and solo tests through
Proton/Wine. Native Windows validation of this beta is still pending.

- **Palbox boxes grow with each base upgrade:** +1 box per upgrade, with a
  configurable bonus cap of 0–64 (32 by default). Reducing the cap keeps occupied
  extra boxes until they are emptied.
- **Chest bonus caps use multiples of six:** 18 by default, up to 42. Existing
  caps round to the nearest step (20 becomes 18; 40 becomes 42). Slots still
  arrive gradually, one at a time. Occupied overflow slots remain until emptied.
- **Open chests show their native and extra capacity** just above the slot grid,
  for example "24 + 10 slots". The count reflects the actual inventory, including
  occupied extra slots retained after reducing a cap. The label follows the
  game's language and disappears when the chest has no extra slots.
- **The range bonus is spread over all base levels**, like the chest slots.
  The maximum you choose (+100% by default) is reached at the last base level,
  35, and every level before it brings its share. The "growth per level"
  setting is gone: one slider sets the whole curve.
- **Existing bases follow the new curve right away, and most get smaller.**
  With the default cap and a 35 m base, level 11 goes from 49 m to 45.2 m
  (from 52.5 m if your world kept the older 5% growth); from level 2 to 34 the
  bonus is lower than before, and only the last level gives the full +100%.
  Check buildings near the edge and keep a backup before updating. A maximum
  of +136% gives the previous 4% per level exactly; levels above 26 then keep
  growing (82.6 m at level 35) and new Palboxes reserve more room.
- **The mod speaks the game's language**: rows, World Settings and tooltips in
  the 17 languages Palworld ships.
- That published build included automatic local backups with a shared 1 GiB limit.
  The system is archived and removed from the current development build.
- Fixed reward-column alignment at 720p. Removed the experimental dotted and
  blue next-boundary previews; numeric reward rows and the upgrade celebration remain.
- A world that had switched range off with growth 0 stays off.

## Earlier versions

The notes of each earlier version are in [publishing/](publishing/), one
`release-<version>.txt` per version.

## Testing and current limits

Tested with Palworld **v1.0.5.102999** and UE4SS Palworld fork **2281fa31**,
using the Windows game and server executables through Proton/Wine, on a
dedicated server with one client. Checked in game across the alpha versions: radius replication
from server to client, the Base Upgrade rows, chest growth and shrinking with
occupied slots kept across a restart, and the upgrade celebration.

For the beta, the dedicated-server test checked Palbox growth, client slot
replication, occupied boxes retained after lowering the cap, and empty-box
shrinking and regrowth. An older solo world expanded to 50 boxes at base level
19. Two Pals placed in box 50 remained in their slots after saving, restoring a
verified archive and restarting the game. The English Base Upgrade panel's
five rows were also checked in game.

### Known limits

This is a beta. These still need broader in-game verification:

- larger guilds with multiple simultaneous clients;
- other Palbox capacity mods installed alongside;
- saving World Settings and starting a new world;
- placement rejection near another base;
- Pal work and resource access throughout the expanded area;
- the full reset and removal lifecycle;
- other range mods installed alongside;
- native Windows for this beta, long sessions and other hardware.

The mod's texts follow the game's language, in the 17 languages Palworld
ships. They were written with the game's own vocabulary but not reviewed by
native speakers: corrections are welcome. The celebration can
start late after closing the Palbox; the gameplay radius is already updated.

On a client, while the server's preview is missing or out of date, Base Upgrade keeps
its last complete Growing Grounds values, or shows no Growing Grounds row on a first open.
At the maximum base level only the next value is hidden. With `resetToVanilla=true`
all Growing Grounds rows are hidden.

The server owns gameplay radius. Animation changes the visible boundary only.
Existing bases are not moved or deleted. Overlapping original base circles do
not receive extra growth; other nearby bases may reach a lower cap.

## Configuration

Gameplay options: `growthPercentPerLevel`, `maxRangeBonusPercent`, `maxChestBonusSlots`,
`startingPalboxBoxes`, `maxPalboxBoxes`, `resetToVanilla`.
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
lua tests/test_palbox.lua ./
lua tests/test_main.lua ./
lua tests/test_changes.lua ./
lua tests/test_range.lua ./
lua tests/test_settings.lua ./
lua tests/test_storage.lua ./
lua tests/test_chest_ui.lua ./
lua tests/test_objects.lua ./
lua tests/test_preview.lua ./
lua tests/test_ui.lua ./
lua tests/test_wave.lua ./
lua tests/test_motion.lua ./
lua tests/test_texts.lua ./
python3 tools/release.py
```

Release archives use an explicit runtime allowlist. Research exports, private
sidecars, logs and loader binaries are excluded. The internal folder/mod ID stays
`BaseRangeGrowth`. [Workshop notes](publishing/WORKSHOP.txt) describe the unverified
Workshop packaging route.

## Credits and permissions

Built with OpenAI Codex and Claude under lelorax's direction, including code,
documentation and the original icon/glow assets. The author chose the behavior,
tested it in game and supplies real gameplay media. No generated gameplay
imagery or third-party game files are bundled.

Growing Grounds is unofficial. Palworld and its game assets belong to their
respective owners. Follow [Pocketpair's mod guidelines](https://guideline.palworldgame.com/palworld-mod-guideline).

All rights reserved. Downloading and using the mod is allowed. Redistribution,
published modifications and reuse require permission; see [LICENSE.txt](LICENSE.txt).

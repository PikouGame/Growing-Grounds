# Growing Grounds (GG)

Internal mod ID: `BaseRangeGrowth`. The installed folder and development ZIP
keep this ID for compatibility.

Adds 5% of the original base radius for each base level after level 1.
The native Base Upgrade menu shows **Base Range**, an original four-arrow
icon, and current/next percentages such as **135% → 140%**.

The server controls the radius. The client mod displays the reward row and
updated boundary. See [INSTALL.txt](INSTALL.txt) for setup and reset instructions.

## Version 0.1.1-alpha

This update adds the upgrade celebration. Upgrades animate the visible boundary for 1.6 seconds, then lift a
terrain-shaped line with a soft trailing glow. It climbs quickly then slows;
the continuous gradient trail softens before the leading edge flashes, then
both fade together during the final slowing movement, without a pause.
The new effect uses one procedural mesh, a native Palworld material and no
Niagara particle simulations. No game assets are bundled. Gameplay stays exact.
Ctrl+Shift+F7 reloads presentation code and replays visible boundaries in debug
mode. Caching game-object lookups removed the reported replay slowdown.
The contour was tested through in-game replay and its appearance approved by
the author. Performance has not been benchmarked across hardware.

Observed on Palworld v1.0.5.102999 with UE4SS fork `2281fa31`, running Windows
executables through Wine/Proton. Server/client radius replication was observed
at level 8: 35 m became 47.25 m. The player confirmed the label and icon stay
correct after reopening the menu following the reconstruction fix.

Not verified: construction, stored-resource use and Pal work throughout the
expanded ring; new Palboxes; reset lifecycle; native
Windows OS execution. This remains an alpha release.
The player observed an actual upgrade updating the radius after a short delay.

## Build and checks

Run from this directory:

```sh
lua tests/test_range.lua ./
lua tests/test_ui.lua ./
lua tests/test_motion.lua ./
python3 tools/package.py
python3 tools/release.py
```

The packager writes `build/BaseRangeGrowth-0.1.1-alpha.zip` and a SHA-256 checksum.
It includes only an explicit list of mod files. Local inspection libraries in
`lib/` are not required to run the Lua tests or create the mod ZIP.

`release.py` creates the versioned manual ZIP and a separate Workshop preparation
ZIP, with SHA-256 checksums. The Workshop route is not yet verified; see
[publishing/WORKSHOP.txt](publishing/WORKSHOP.txt). Neither archive bundles UE4SS.

## Permissions

All rights reserved. Downloading and using the mod is allowed; redistribution,
published modifications and reuse require permission. See [LICENSE.txt](LICENSE.txt).

## Share your experience

We’d love to hear how Growing Grounds fits into your world! Leave a comment, share your experience, or [report a bug](https://github.com/PikouGame/Growing-Grounds/issues) so we can investigate and improve it. Include game/UE4SS versions and reproduction steps, and remove personal information from logs.

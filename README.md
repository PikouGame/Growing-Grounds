# Growing Grounds (GG)

Internal mod ID: `BaseRangeGrowth`. The installed folder and development ZIP
keep this ID for compatibility.

Adds 5% of the original base radius for each base level after level 1.
The native Base Upgrade menu shows **Base Range**, an original four-arrow
icon, and current/next percentages such as **135% → 140%**.

The server controls the radius. The client mod displays the reward row and
updated boundary. See [INSTALL.txt](INSTALL.txt) for setup and reset instructions.

## Development status

Observed on Palworld v1.0.5.102999 with UE4SS fork `2281fa31`, running Windows
executables through Wine/Proton. Server/client radius replication was observed
at level 8: 35 m became 47.25 m. The player confirmed the label and icon stay
correct after reopening the menu following the reconstruction fix.

Not verified: construction, stored-resource use and Pal work throughout the
expanded ring; actual base upgrades and new Palboxes; reset lifecycle; native
Windows OS execution. This remains a development candidate.

## Build and checks

Run from this directory:

```sh
lua tests/test_range.lua ./
lua tests/test_ui.lua ./
python3 tools/package.py
```

The packager writes `build/BaseRangeGrowth-0.1.0-dev.zip` and a SHA-256 checksum.
It includes only an explicit list of mod files. Local inspection libraries in
`lib/` are not required to run the Lua tests or create the mod ZIP.

# Kurtlar Vadisi: Shadow of the City

Public development repository for a GTA San Andreas 1.0 US MoonLoader campaign.

This repository is intentionally a source-and-mod project, not a copy of the
GTA San Andreas installation. Original game files, loader binaries, logs,
backups, bundled third-party tools, and audio are excluded. Install the
dependencies separately, then clone this repository directly into the game
directory or copy the tracked folders into it.

## Included

- `moonloader/KV_Main.lua` — MoonLoader entry point.
- `moonloader/KurtlarVadisi/` — campaign code, mission modules, systems,
  configuration, UI images, and development placeholders.
- `cleo/README.md` — CLEO integration note; CLEO itself is installed locally.
- `modloader/KurtlarVadisi/` — project character/model assets used by the
  campaign. The duplicated `*.dff1`/`*.txd1` recovery copies are excluded.
- `KurtlarVadisi/source/` — editable Blender model, textures, build scripts,
  mission tests, and asset inspection helpers.
- `docs/` — dependency and development notes.

## Required local dependencies

Install these into the GTA San Andreas 1.0 US game directory before running:

1. An ASI loader compatible with the game version.
2. CLEO 4.4+ (only required for CLEO scripts/opcodes used during development).
3. MoonLoader 0.26.x for the Lua campaign.
4. ModLoader for the character/model assets.
5. Blender 5.x plus DragonFF for editing/exporting DFF/TXD assets.
6. Sanny Builder 4.x only if the SCM/CLEO side of the project is extended.

Do not commit the dependency binaries to this repository. Use the official
release pages for each dependency and follow their licenses.

## Installation

From a clean GTA San Andreas 1.0 US installation:

1. Install the dependencies above.
2. Copy/clone the tracked `moonloader/` and `modloader/` folders into the game
   directory, preserving their names.
3. Start the game and check `moonloader/KurtlarVadisi/debug/kv.log` locally if
   a runtime issue occurs. Logs are ignored by Git.
4. Keep save files and generated output outside commits.

The campaign currently contains the foundation and Mission 001. Mission 002
is registered as a locked placeholder until its implementation is ready.

## Development workflow

- Add new missions under `moonloader/KurtlarVadisi/missions/`.
- Register them in `moonloader/KurtlarVadisi/config/missions.lua`.
- Keep reusable logic in `systems/` and data in `config/`, `locations/`, and
  `dialogue/`.
- Edit the player model in `KurtlarVadisi/source/polat.blend`, then export the
  runtime model into the local `KurtlarVadisi/staging/` folder.
- Run the Lua/unit-style checks in `KurtlarVadisi/source/mission001/` where
  applicable. In-game verification is still required for mission behavior.

## Rights and attribution

GTA San Andreas, CLEO, MoonLoader, ModLoader, DragonFF, Sanny Builder, and
any referenced media remain the property of their respective authors. This
repository does not grant rights to redistribute those dependencies or the
original game. Add attribution and licensing information before publishing
new third-party assets.

KurtlarVadisi - Runtime Assets
Shadow of the City - Development Build

OVERVIEW
This ModLoader package contains character, vehicle and other runtime assets
used by Kurtlar Vadisi: Shadow of the City.

POLAT PLAYER MODEL
Polat Alemdar uses GTA San Andreas pedestrian model slot 113 (MAFBOSS).

Canonical model files:
skins/polat.dff
skins/polat.txd

Runtime aliases may also exist as:
gta3.img/mafboss.dff
gta3.img/mafboss.txd

ModLoader replaces model slot 113 in memory.
The original gta3.img is not modified directly.

PLAYER INITIALIZATION
Polat is handled automatically by the campaign runtime:

moonloader/KV_Main.lua
 -> moonloader/KurtlarVadisi/main.lua
 -> moonloader/KurtlarVadisi/systems/player_model.lua

The old standalone F5/F6 Polat player script is no longer part of the runtime.

DEVELOPMENT SOURCE
Editable Polat model:
KurtlarVadisi/source/polat.blend

Development textures:
KurtlarVadisi/source/textures/

Development tools:
KurtlarVadisi/source/tools/

POLAT POSTURE
The old experimental upright posture implementation has been preserved only
as development reference code:

KurtlarVadisi/source/tools/polat_posture_reference.lua

It must not be executed as a standalone MoonLoader script.

A future integrated implementation may be added as:

moonloader/KurtlarVadisi/systems/player_posture.lua

and controlled by player_model.lua.

CHARACTER ASSETS
Additional campaign characters such as Memati and Abdulhey may be stored in
this package for later missions.

Their presence in the asset package does not mean they appear in Mission 001.

ROLLBACK
1. Close GTA San Andreas.
2. Disable or move modloader/KurtlarVadisi.
3. Start the game again.

The original GTA San Andreas assets will then be used.

PROJECT
Kurtlar Vadisi: Shadow of the City
Vadi'nin Golgesi

Development status: Active

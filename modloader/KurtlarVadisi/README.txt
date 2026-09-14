KurtlarVadisi - Polat Alemdar player skin
Development build for the public Shadow of the City project.

CONTROLS
F5: activate Polat while standing on foot.
F6: restore CJ while standing on foot.
Wait for the on-screen success message. Switching is blocked in a vehicle,
while swimming/jumping, during pauses and when player control is disabled.

INSTALLATION USED IN THIS PROJECT
The canonical model files are skins/polat.dff and skins/polat.txd.
The byte-identical runtime aliases are gta3.img/mafboss.dff and mafboss.txd.
ModLoader replaces the existing pedestrian slot 113 (MAFBOSS) in memory.
This also changes NPCs using MAFBOSS. No new model ID or limit adjuster is needed.
The original gta3.img, peds.ide and CJ clothing assets are not edited.
The existing Triboos_Test mod in slot 120 is left intact.

MoonLoader 0.26 does not automatically run this nested moonloader folder here.
The small game-root moonloader/polat_player.lua bridge loads
modloader/KurtlarVadisi/moonloader/polat_player.lua.
Both that bridge and this ModLoader folder are required on another installation.
Restart the game after installing/changing model files.

SOURCE
The editable model is in the repository at KurtlarVadisi/source/polat.blend.
The model adapts a pre-existing user asset and is rebound to the original
MAFBOSS skeleton; it is not claimed to be a completely original sculpture.
DragonFF is used locally for DFF and TXD import/export.

ROLLBACK
Close the game. Move this KurtlarVadisi mod folder and the root
moonloader/polat_player.lua bridge outside their loader folders.
The original game assets then take effect again.

KNOWN EXISTING ISSUE
moonloader/triboos_test.lua calls changePlayerModel, which does not exist here.
That unrelated pre-existing script previously failed. This mod uses setPlayerModel.

Version: 0.1.0 development

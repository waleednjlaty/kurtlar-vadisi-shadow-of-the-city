Source record

- Blender: 5.2.0 LTS, fbe6228777e7.
- DragonFF was already installed in Blender extensions/user_default/dragonff.
- Build-local DragonFF source: https://github.com/Parik27/DragonFF (master archive downloaded 2026-09-11); bundled license retained under tools/DragonFF-master/LICENSE.
- Original reference skeleton: models/gta3.img, mafboss.dff. Extracted read-only by tools/inspect_base.py.
- Starting appearance mesh and clothing: the user's pre-existing modloader/Triboos_Test/triboss.dff and triboss.txd. Original author was not identified in that folder. Existing files remain unchanged.
- Public facial reference: https://www.kanald.com.tr/kurtlar-vadisi-pusu/foto-galeri/kurtlar-vadisi-pusu-280-bolumden-ilk-kareler
- Downloaded reference image: https://image.kanald.com.tr/i/kanald/100/0x0/569dfc68a781b630d8a557d1.jpg
- Face diffuse generated using the built-in image generation tool from existing_PA_Face.png and that reference, then baked in Blender onto reconstructed geometry.
- The abandoned first atlas and original-mesh draft are retained for provenance. They are not the installed model.

Face-generation prompt

Edit first image: production 1024x1024 diffuse face UV atlas for an existing 3D model of Polat Alemdar. Use second image only as his facial reference. STRICTLY keep the UV template and silhouette, positions of ears, nose, lips, eyes, hair boundary, all features at EXACT same normalized coordinates as first image. No relocating any part. This is an unwrapped flat UV face texture, not a headshot: keep the stretched distorted shape of the original! Enhance clean-shaven Polat/Necati Sasmaz likeness, neutral warm olive skin, strong thick black eyebrows, natural pores, full lips, serious neutral expression, short black hair on the top region. The eye sockets are closed/shadowed as original because eyeballs are separate meshes: no new staring eyeballs. Keep exact flat background skin edge fill. Remove orange color cast; use neutral diffuse lighting. No clothes, no extra atlas parts, no text or watermark.

Rebuild order (Blender background Python)

1. tools/inspect_base.py
2. tools/inspect_existing.py
3. tools/finalize_polat.py
4. tools/validate_export.py

Build outputs initially go to ../staging; installation is a separate file-copy step.
Approximate pose checks are not original GTA animation playback.

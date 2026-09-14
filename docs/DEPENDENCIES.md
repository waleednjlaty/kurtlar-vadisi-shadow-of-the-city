# Development dependencies

The public repository tracks the project files, not the complete game or the
loader installers.

| Component | Used for | Tracked here? |
| --- | --- | --- |
| ASI loader | Loading `.asi` plugins | No; install locally |
| CLEO 4.4+ | CLEO scripts and extra opcodes | No; install locally |
| MoonLoader 0.26.x | Lua campaign runtime | No; install locally |
| ModLoader | Streaming project models/assets | No; install locally |
| Blender 5.x + DragonFF | DFF/TXD authoring and export | Build scripts only |
| Sanny Builder 4.x | Optional SCM/CLEO authoring | No; install locally |

## What is deliberately excluded

- `GTA_SA.EXE`, `models/`, `audio/`, `anim/`, `movies/`, `text/`, and other
  original game data.
- Loader/plugin binaries such as `CLEO.asi`, `MoonLoader.asi`, and
  `modloader.asi`.
- Local logs, saves, crash reports, generated reports, and backup revisions.
- Bundled installers and third-party archives.
- MP3/WAV media from the local installation.

This keeps the repository suitable for a public GitHub project and avoids
publishing a redistributable copy of the game or third-party installers.

# Kurtlar Vadisi: Shadow of the City

Playable MoonLoader campaign for GTA San Andreas 1.0 US.

Mission 001 is opened from its world marker at the configured approach point. A later mission is never started automatically; add a real mission definition and module to `config/missions.lua` when it exists.

Free Roam ambient music is handled only by `systems/audio.lua`. It runs during gameplay while `mission_manager.isActive()` is false and the Pause Menu is closed, with a 10–15 second cooldown and no consecutive track repeats.

MoonLoader save events reset or restore the mod profile. The profile is embedded in `saveData` when supported and also written to `data/progress.ini` or `data/profiles/progress_slot_<n>.ini` when a slot is exposed.

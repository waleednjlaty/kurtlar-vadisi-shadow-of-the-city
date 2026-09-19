-- GTA SA SCM channels: 0..10 = stations, 11 = USER TRACKS, 12 = OFF.
-- Policy only. Future custom songs belong to a separate playlist.
return { missionOverride = true, offChannel = 12, defaultChannel = 0,
    settleMs = 750, pollMs = 750 }

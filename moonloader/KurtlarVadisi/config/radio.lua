-- Native GTA SA radio policy.
-- Outside missions the stock stations are replaced by GTA's own USER TRACKS
-- station.  Mission audio can still force the native radio OFF cleanly.
return {
    missionOverride = true,
    replaceNativeStations = true,
    userTracksChannel = 11,
    offChannel = 12,
    settleMs = 250,
    pollMs = 250
}

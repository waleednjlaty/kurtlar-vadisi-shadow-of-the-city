-- Custom in-car radio configuration.
-- Audio files stay local and are intentionally ignored by Git.
-- Put the playlist files in:
--   moonloader\KurtlarVadisi\radio\
return {
    missionOverride = true,
    offChannel = 12,
    defaultChannel = 0,
    settleMs = 750,
    pollMs = 500,

    customEnabled = true,
    playlistDir = 'moonloader\\KurtlarVadisi\\radio\\',
    volume = 0.35,
    retryMs = 5000,

    tracks = {
        '6Q2MfWVxCeY.m4a',
        '6Ujs0_z_amI.m4a',
        'LRvFDvkW1Ro.m4a',
        'm6Y3n6Wod4g.m4a',
        'naOnzfjPCcA.m4a',
        'NgGRTwPmIx4.m4a',
        'nvhMDDuS09w.m4a',
        'rfGGUnOPY5c.m4a',
        '4tf0icuedoI.m4a'
    }
}

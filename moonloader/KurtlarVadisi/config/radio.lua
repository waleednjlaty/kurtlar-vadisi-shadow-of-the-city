-- Custom in-car radio configuration.
-- Audio files stay local and are intentionally ignored by Git.
-- Install the prepared pack so these files exist under:
--   moonloader\KurtlarVadisi\radio\radio_01.mp3 ... radio_09.mp3
return {
    missionOverride = true,
    offChannel = 12,
    defaultChannel = 0,
    settleMs = 750,
    pollMs = 500,

    customEnabled = true,
    fallbackToNative = true,
    playlistDir = 'moonloader\\KurtlarVadisi\\radio\\',
    volume = 0.35,
    retryMs = 5000,

    tracks = {
        'radio_01.mp3',
        'radio_02.mp3',
        'radio_03.mp3',
        'radio_04.mp3',
        'radio_05.mp3',
        'radio_06.mp3',
        'radio_07.mp3',
        'radio_08.mp3',
        'radio_09.mp3'
    }
}

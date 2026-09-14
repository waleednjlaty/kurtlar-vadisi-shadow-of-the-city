-- Mission definitions only. Mission modules are loaded lazily when a marker is entered.
-- Add a real future mission here; do not register placeholders.
return {
    {
        id = '001',
        title = 'Geceye Donus',
        module = 'KurtlarVadisi.missions.mission_001_night_return',
        progressKey = '001_geceye_donus',
        requiresCompleted = {},
        status = 'available',
        marker = {
            -- Grove Street: visible from the New Game spawn, but far enough
            -- away that the player must walk into the marker to start.
            -- The mission's countryside approach/road route is unchanged.
            x = 2488.56,
            y = -1686.84,
            z = 13.34,
            radius = 9.0,
            colour = 2
        }
    }
}

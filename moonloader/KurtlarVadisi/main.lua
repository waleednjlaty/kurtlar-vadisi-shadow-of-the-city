local M = {}
function M.run()
    local manager = require 'KurtlarVadisi.systems.mission_manager'
    local audio = require 'KurtlarVadisi.systems.audio'
    local player = require 'KurtlarVadisi.systems.player_model'
    local radio = require 'KurtlarVadisi.systems.radio'
    local runtime = require 'KurtlarVadisi.systems.runtime'
    local log = require 'KurtlarVadisi.systems.logger'
    while true do
        wait(0)
        local paused = runtime.paused()
        local exists = doesCharExist(PLAYER_PED)
        local playing = exists and isPlayerPlaying(PLAYER_HANDLE)
        local inCar = playing and isCharInAnyCar(PLAYER_PED)
        audio.pause(paused)
        if not paused and playing then
            runtime.ready = true
            if not manager.initialized then manager.initialize() end
            local ready = manager.isActive()
            if not ready then
                local ok, value = xpcall(player.ensure, debug.traceback)
                ready = ok and value
                if not ok then log.exception('Player initialization', value); player.nextAt = getGameTimer() + 5000 end
            end
            manager.setGameplayReady(ready)
            radio.update({ mission = manager.isActive() })
            manager.updateMarkers()
            manager.update()
        elseif not paused and runtime.ready and exists and manager.isActive() then
            -- isPlayerPlaying becomes false on death/arrest. Handle failure
            -- while the current world's player handle still exists.
            manager.update()
        end
        audio.updateFreeRoam({ now = getGameTimer(), gameplay = playing,
            paused = paused, mission = manager.isActive(), inCar = inCar })
        if playing and not paused then manager.draw() end
    end
end
return M

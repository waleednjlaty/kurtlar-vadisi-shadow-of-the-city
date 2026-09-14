local log = require 'KurtlarVadisi.systems.logger'
local C = require 'KurtlarVadisi.config.characters'
local runtime = require 'KurtlarVadisi.systems.runtime'
local M = { requested = false, nextAt = 0, ready = false }
function M.reset() M.requested = false; M.nextAt = 0; M.ready = false; M.verify = false end
function M.ensure()
    if not runtime.worldReady() or not isPlayerPlaying(PLAYER_HANDLE) or isCharDead(PLAYER_PED) then return false end
    if getCharModel(PLAYER_PED) == C.polat then
        if M.requested then markModelAsNoLongerNeeded(C.polat); M.requested = false end
        if not M.ready then log.info('Gameplay player verified: Polat ID=' .. C.polat) end
        M.ready = true; M.verify = false; return true
    end
    M.ready = false
    if isCharInAnyCar(PLAYER_PED) or not isPlayerControlOn(PLAYER_HANDLE) then return false end
    local now = getGameTimer()
    if M.verify then
        M.verify = false; M.nextAt = now + 5000
        log.warn('Polat switch was not verified; retry deferred'); return false
    end
    if not M.requested then
        if now < M.nextAt then return false end
        assert(type(C.polat) == 'number' and C.polat > 0 and C.polat <= 311, 'Invalid Polat ped ID')
        requestModel(C.polat); M.requested = true; M.deadline = now + 10000
        return false
    end
    if hasModelLoaded(C.polat) then
        setPlayerModel(PLAYER_HANDLE, C.polat)
        markModelAsNoLongerNeeded(C.polat); M.requested = false; M.verify = true
        return false -- Verify PLAYER_PED and model on the following frame.
    end
    if now >= M.deadline then
        markModelAsNoLongerNeeded(C.polat); M.requested = false; M.nextAt = now + 5000
        log.warn('Polat model load timeout; current player preserved')
    end
    return false
end
return M

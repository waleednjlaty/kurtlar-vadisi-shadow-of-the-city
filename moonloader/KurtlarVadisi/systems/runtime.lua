-- Lifecycle token invalidates work yielded across New/Load Game.
local M = { epoch = 0, ready = false }
function M.reset() M.epoch = M.epoch + 1; M.ready = false end
function M.paused()
    if type(isPauseMenuActive) == 'function' and isPauseMenuActive() then return true end
    return type(isGamePaused) == 'function' and isGamePaused() == true
end
function M.worldReady()
    return M.ready and not M.paused() and doesCharExist(PLAYER_PED)
end
return M

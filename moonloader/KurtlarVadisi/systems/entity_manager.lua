local logger = require 'KurtlarVadisi.systems.logger'
local models = require 'KurtlarVadisi.systems.model_loader'
local runtime = require 'KurtlarVadisi.systems.runtime'
local M = { chars = {}, cars = {}, blips = {}, worldMarkers = {} }
function M.reset() M.chars, M.cars, M.blips, M.worldMarkers = {}, {}, {}, {} end

function M.isValidChar(handle)
    if not handle then return false end
    local ok, exists = pcall(doesCharExist, handle)
    return ok and exists
end

function M.isValidCar(handle)
    if not handle then return false end
    local ok, exists = pcall(doesVehicleExist, handle)
    return ok and exists
end

function M.isPlayerUsingCar(handle)
    if not M.isValidCar(handle) then return false end
    local ok, isUsing = pcall(isCharInCar, PLAYER_PED, handle)
    return ok and isUsing
end

function M.getGroundZ(x, y)
    -- 02CE is queried only after the player has reached the streamed airport area.
    local ok, groundZ = pcall(getGroundZFor3dCoord, x, y, 999.0)
    if not ok or type(groundZ) ~= 'number' then
        logger.error('Ground lookup failed at ' .. tostring(x) .. ', ' .. tostring(y))
        return nil
    end
    return groundZ
end

function M.spawnChar(pedType, model, x, y, z, heading, snapToGround)
    if not models.load(model) then return nil end
    if snapToGround then z = M.getGroundZ(x, y) end
    if type(z) ~= 'number' then
        models.release(model)
        logger.error('Refused to create ped without a verified ground Z')
        return nil
    end
    local ok, handle = pcall(createChar, pedType, model, x, y, z); models.release(model)
    if not ok or not M.isValidChar(handle) then logger.error('Could not create ped model ' .. tostring(model)); return nil end
    table.insert(M.chars, handle)
    if heading then setCharHeading(handle, heading) end
    return handle
end
function M.spawnCar(model, x, y, z, heading, snapToGround)
    if not models.load(model) then return nil end
    if snapToGround then z = M.getGroundZ(x, y) end
    if type(z) ~= 'number' then
        models.release(model)
        logger.error('Refused to create vehicle without a verified ground Z')
        return nil
    end
    local epoch = runtime.epoch
    local ok, handle = pcall(createCar, model, x, y, z); models.release(model)
    if not ok or not handle then logger.error('Could not create vehicle model ' .. tostring(model)); return nil end
    table.insert(M.cars, handle) -- Own it before yielding, including cancellation.
    wait(0) -- A newly-created vehicle is registered by the GTA world on the next frame.
    while epoch == runtime.epoch and runtime.paused() do wait(0) end
    if epoch ~= runtime.epoch or not runtime.worldReady() then return nil end
    if not M.isValidCar(handle) then logger.error('Vehicle handle was invalid after creation for model ' .. tostring(model)); return nil end
    if heading then setCarHeading(handle, heading) end
    return handle
end
function M.addBlip(x, y, z, colour)
    local ok, handle = pcall(addBlipForCoord, x, y, z)
    if not ok or not handle then return nil end
    if colour then changeBlipColour(handle, colour) end
    table.insert(M.blips, handle); return handle
end
local function forgetHandle(list, handle)
    for i = #list, 1, -1 do
        if list[i] == handle then table.remove(list, i) end
    end
end
function M.removeBlip(handle)
    if handle then
        local ok = pcall(removeBlip, handle)
        if ok then forgetHandle(M.blips, handle) end
    end
end
function M.addWorldMarker(x, y, z, colour)
    local ok, handle = pcall(createUser3dMarker, x, y, z, colour or 0)
    if not ok or not handle then return nil end
    table.insert(M.worldMarkers, handle); return handle
end
function M.removeWorldMarker(handle)
    if handle then
        local ok = pcall(removeUser3dMarker, handle)
        if ok then forgetHandle(M.worldMarkers, handle) end
    end
end
function M.cleanup()
    for _, h in ipairs(M.blips) do pcall(removeBlip, h) end
    for _, h in ipairs(M.worldMarkers) do pcall(removeUser3dMarker, h) end
    for _, h in ipairs(M.chars) do if M.isValidChar(h) then pcall(deleteChar, h) end end
    for _, h in ipairs(M.cars) do
        -- Releasing ownership lets GTA retire the car when unused. Do not
        -- delete it during an entry/exit task (isCharInCar misses that race).
        if M.isValidCar(h) then
            pcall(setCarProofs, h, false,false,false,false,false)
            pcall(markCarAsNoLongerNeeded, h)
        end
    end
    M.reset()
end

function M.safeCleanup()
    local ok, err = xpcall(M.cleanup, debug.traceback)
    if not ok then logger.error('Entity cleanup failed safely: ' .. tostring(err)); M.reset() end
    return ok
end
return M

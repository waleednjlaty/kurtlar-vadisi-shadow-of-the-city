local config = require 'KurtlarVadisi.config.radio'
local runtime = require 'KurtlarVadisi.systems.runtime'
local log = require 'KurtlarVadisi.systems.logger'
local M = { owner = nil, previous = {}, car = nil, nextAt = 0,
    lastStation = config.defaultChannel, freeRoamChecked = false }
local function playerCar()
    -- 00D9 can return -1 for a live vehicle in MoonLoader 0.26.5.
    -- 0811 reads the vehicle the actor is actually using.
    for _, name in ipairs({'getCarCharIsUsing', 'storeCarCharIsInNoSave', 'storeCarCharIsIn'}) do
        local getter = _G[name]
        if type(getter) == 'function' then
            local ok, car = pcall(getter, PLAYER_PED)
            if ok and type(car) == 'number' and car >= 0 and doesVehicleExist(car)
                and isCharInCar(PLAYER_PED, car) then return car end
        end
    end
    return nil
end
function M.reset()
    M.owner = nil; M.previous = {}; M.car = nil; M.nextAt = 0
    M.lastStation = config.defaultChannel; M.freeRoamChecked = false
end
function M.disableForMission(id)
    if config.missionOverride then
        M.owner = id or 'mission'; M.car = nil; M.nextAt = 0; M.freeRoamChecked = false
    end
end
function M.restoreAfterMission()
    M.owner = nil; M.car = nil; M.nextAt = 0; M.freeRoamChecked = false
    -- Restore when the same vehicle is occupied; never retune another vehicle.
end
function M.update(context)
    if not runtime.worldReady() or not isPlayerPlaying(PLAYER_HANDLE) then return end
    if not isCharInAnyCar(PLAYER_PED) then
        M.car = nil; M.freeRoamChecked = false; return
    end
    local car = playerCar()
    if not car then return end
    local now = getGameTimer()
    if M.car ~= car then
        M.car = car; M.nextAt = now + config.settleMs; M.freeRoamChecked = false; return
    end
    if now < M.nextAt then return end
    M.nextAt = now + config.pollMs
    if type(getRadioChannel) ~= 'function' or type(setRadioChannel) ~= 'function' then return end
    local ok, channel = pcall(getRadioChannel)
    if not ok or type(channel) ~= 'number' or channel < 0 or channel > 12 then return end
    for oldCar in pairs(M.previous) do
        if not doesVehicleExist(oldCar) then M.previous[oldCar] = nil end
    end
    if M.owner then
        if M.previous[car] == nil then
            M.previous[car] = channel
            if channel ~= config.offChannel then M.lastStation = channel end
        end
        if channel ~= config.offChannel then
            local applied, err = pcall(setRadioChannel, config.offChannel)
            if not applied then log.warn('Radio override unavailable: '..tostring(err)); return end
            log.info('Mission radio OFF (SCM 12), vehicle=' .. car)
        end
    elseif context and context.mission == true then
        return -- Another mission may choose its own radio policy.
    elseif M.previous[car] ~= nil then
        local previous = M.previous[car]; M.previous[car] = nil
        if channel == config.offChannel and previous >= 0 and previous <= 12 and previous ~= channel then
            local applied, err = pcall(setRadioChannel, previous)
            if not applied then M.previous[car] = previous; log.warn('Radio restore deferred: '..tostring(err)); return end
            log.info('Mission radio restored, station=' .. previous)
            channel = previous
        end
        if channel ~= config.offChannel then M.lastStation = channel end
        -- If the former station was OFF, the free-roam entry policy below
        -- still selects a station once the mission override has ended.
    end
    if not M.owner and not (context and context.mission == true) then
        if not M.freeRoamChecked then
            if channel == config.offChannel then
                local station = M.lastStation or config.defaultChannel
                local applied, err = pcall(setRadioChannel, station)
                if not applied then log.warn('Free-roam radio unavailable: '..tostring(err)); return end
                log.info('Free-roam radio ON, station=' .. station)
            end
            M.freeRoamChecked = true
        elseif channel ~= config.offChannel then
            -- Preserve the player's station choice for the next car.
            M.lastStation = channel
        end
    end
end
return M

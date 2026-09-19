local config = require 'KurtlarVadisi.config.radio'
local runtime = require 'KurtlarVadisi.systems.runtime'
local log = require 'KurtlarVadisi.systems.logger'

local M = {
    owner = nil,
    car = nil,
    nextAt = 0,
    lastApplied = nil
}

local function playerCar()
    -- 00D9 can return -1 for a live vehicle in MoonLoader 0.26.5.
    -- Prefer the opcodes that return the vehicle the actor is actually using.
    for _, name in ipairs({
        'getCarCharIsUsing',
        'storeCarCharIsInNoSave',
        'storeCarCharIsIn'
    }) do
        local getter = _G[name]
        if type(getter) == 'function' then
            local ok, car = pcall(getter, PLAYER_PED)
            if ok and type(car) == 'number' and car >= 0
                and doesVehicleExist(car)
                and isCharInCar(PLAYER_PED, car) then
                return car
            end
        end
    end
    return nil
end

local function setNativeChannel(channel, reason)
    if type(getRadioChannel) ~= 'function'
        or type(setRadioChannel) ~= 'function' then
        return false
    end

    local okRead, current = pcall(getRadioChannel)
    if not okRead or type(current) ~= 'number' then
        return false
    end

    if current == channel then
        M.lastApplied = channel
        return true
    end

    local okSet, err = pcall(setRadioChannel, channel)
    if not okSet then
        log.warn('Native radio change failed: ' .. tostring(err))
        return false
    end

    M.lastApplied = channel
    log.info('Native radio -> ' .. tostring(channel)
        .. (reason and (' (' .. reason .. ')') or ''))
    return true
end

function M.reset()
    M.owner = nil
    M.car = nil
    M.nextAt = 0
    M.lastApplied = nil
end

function M.disableForMission(id)
    if not config.missionOverride then return end
    M.owner = id or 'mission'
    M.nextAt = 0

    -- If the mission starts while Polat is already in a vehicle, mute the
    -- native radio immediately instead of waiting for the next settle period.
    if runtime.worldReady()
        and doesCharExist(PLAYER_PED)
        and isPlayerPlaying(PLAYER_HANDLE)
        and isCharInAnyCar(PLAYER_PED) then
        setNativeChannel(config.offChannel, 'mission start')
    end
end

function M.restoreAfterMission()
    M.owner = nil
    M.nextAt = 0
    M.lastApplied = nil

    -- Do not force anything if Polat is on foot.  The next vehicle entry will
    -- select USER TRACKS through the normal update path.
end

function M.update(context)
    if not runtime.worldReady()
        or not doesCharExist(PLAYER_PED)
        or not isPlayerPlaying(PLAYER_HANDLE) then
        return
    end

    if not isCharInAnyCar(PLAYER_PED) then
        M.car = nil
        M.nextAt = 0
        M.lastApplied = nil
        return
    end

    local car = playerCar()
    if not car then return end

    local now = getGameTimer()
    local missionActive = M.owner ~= nil
        or (context and context.mission == true)

    if M.car ~= car then
        M.car = car
        M.nextAt = now + (tonumber(config.settleMs) or 250)
        M.lastApplied = nil

        -- Mission music gets priority immediately.  Outside missions we can
        -- safely select USER TRACKS on the first vehicle frame as well.
        if missionActive then
            setNativeChannel(config.offChannel, 'mission vehicle')
        elseif config.replaceNativeStations then
            setNativeChannel(config.userTracksChannel, 'native replacement')
        end
        return
    end

    if now < M.nextAt then return end
    M.nextAt = now + (tonumber(config.pollMs) or 250)

    if missionActive then
        setNativeChannel(config.offChannel, 'mission override')
        return
    end

    if config.replaceNativeStations then
        -- Any attempt to select a stock station is redirected to GTA's own
        -- USER TRACKS station.  Audio, volume, in-car effects and radio state
        -- therefore remain owned by GTA rather than a MoonLoader AudioStream.
        setNativeChannel(config.userTracksChannel, 'native replacement')
    end
end

return M

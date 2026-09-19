local config = require 'KurtlarVadisi.config.radio'
local runtime = require 'KurtlarVadisi.systems.runtime'
local log = require 'KurtlarVadisi.systems.logger'

local M = {
    owner = nil,
    previous = {},
    car = nil,
    nextAt = 0,
    retryAt = 0,
    lastStation = config.defaultChannel,
    stream = nil,
    currentTrack = nil,
    lastTrack = nil,
    paused = false
}

local function fileExists(path)
    local f = io.open(path, 'rb')
    if not f then return false end
    f:close()
    return true
end

local function safeRelease(stream)
    if not stream then return end
    pcall(setAudioStreamState, stream, 0)
    pcall(releaseAudioStream, stream)
end

local function loadStream(path)
    local ok, a, b = pcall(loadAudioStream, path)
    if not ok then
        log.warn('Custom radio loadAudioStream failed: ' .. tostring(a))
        return nil
    end

    if type(a) == 'userdata' then return a end
    if type(a) == 'number' and b == nil and a ~= 0 then return a end
    if type(a) == 'boolean' and a
        and (type(b) == 'userdata' or type(b) == 'number')
        and b ~= 0 then
        return b
    end

    return nil
end

local function playerCar()
    -- 00D9 can return -1 for a live vehicle in MoonLoader 0.26.5.
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

local function radioRoot()
    return getGameDirectory() .. '\\' .. config.playlistDir
end

local function readChannel()
    if type(getRadioChannel) ~= 'function' then return nil end

    local ok, channel = pcall(getRadioChannel)
    if not ok or type(channel) ~= 'number' or channel < 0 or channel > 12 then
        return nil
    end

    return channel
end

local function setChannel(channel)
    if type(setRadioChannel) ~= 'function' then return false end
    local ok, err = pcall(setRadioChannel, channel)
    if not ok then
        log.warn('Radio channel change failed: ' .. tostring(err))
        return false
    end
    return true
end

local function forceNativeRadioOff()
    local channel = readChannel()
    if channel == nil then return false end
    if channel == config.offChannel then return true end
    return setChannel(config.offChannel)
end

local function restoreNativeRadio()
    local channel = readChannel()
    if channel == nil then return false end
    if channel ~= config.offChannel then
        M.lastStation = channel
        return true
    end

    local station = M.previous[M.car]
    if station == nil or station == config.offChannel then
        station = M.lastStation
    end
    if station == nil or station == config.offChannel then
        station = config.defaultChannel
    end

    return setChannel(station)
end

local function stopCustom(reason)
    if not M.stream then return end

    local stream = M.stream
    M.stream = nil
    M.currentTrack = nil
    safeRelease(stream)

    if reason then
        log.info('Custom radio stopped: ' .. tostring(reason))
    end
end

local function playableChoices()
    local root = radioRoot()
    local choices = {}

    for index, file in ipairs(config.tracks or {}) do
        if file ~= M.lastTrack and fileExists(root .. file) then
            choices[#choices + 1] = { index = index, file = file }
        end
    end

    -- If only one local track exists, allow it to repeat after it finishes.
    if #choices == 0 then
        for index, file in ipairs(config.tracks or {}) do
            if fileExists(root .. file) then
                choices[#choices + 1] = { index = index, file = file }
            end
        end
    end

    return choices
end

local function startCustom(now)
    if not config.customEnabled or M.owner or M.paused then return false end
    if M.stream then return true end

    local root = radioRoot()
    local choices = playableChoices()

    while #choices > 0 do
        local pick = math.random(1, #choices)
        local track = table.remove(choices, pick)
        local path = root .. track.file
        local stream = loadStream(path)

        if stream then
            local volumeOk = pcall(
                setAudioStreamVolume,
                stream,
                math.max(0.0, math.min(1.0, tonumber(config.volume) or 0.35))
            )
            local loopOk = pcall(setAudioStreamLooped, stream, false)
            local playOk = pcall(setAudioStreamState, stream, 1)

            if volumeOk and loopOk and playOk then
                M.stream = stream
                M.currentTrack = track.file
                M.lastTrack = track.file
                M.retryAt = 0

                pcall(
                    printStringNow,
                    string.format('KVS RADIO - TRACK %d/%d',
                        track.index, #(config.tracks or {})),
                    2500
                )

                log.info('Custom radio playing: ' .. track.file)
                return true
            end

            safeRelease(stream)
        end

        log.warn('Custom radio skipped unreadable track: ' .. track.file)
    end

    M.retryAt = now + (tonumber(config.retryMs) or 5000)
    log.warn('Custom radio: no playable local tracks found in ' .. root)
    return false
end

local function updateCustom(now)
    if not config.customEnabled or M.owner then
        stopCustom('disabled or mission override')
        return false
    end

    if M.stream then
        local ok, state = pcall(getAudioStreamState, M.stream)
        if not ok or state == 0 then
            stopCustom('track finished')
            M.retryAt = now
        else
            return true
        end
    end

    if now >= (M.retryAt or 0) then
        return startCustom(now)
    end

    return false
end

function M.pause(value)
    value = value == true
    if value == M.paused then return end
    M.paused = value

    if M.stream then
        pcall(setAudioStreamState, M.stream, value and 2 or 3)
        log.info('Custom radio ' .. (value and 'paused' or 'resumed'))
    end
end

function M.reset()
    stopCustom()
    M.owner = nil
    M.previous = {}
    M.car = nil
    M.nextAt = 0
    M.retryAt = 0
    M.lastStation = config.defaultChannel
    M.currentTrack = nil
    M.lastTrack = nil
    M.paused = false
end

function M.disableForMission(id)
    if not config.missionOverride then return end

    M.owner = id or 'mission'
    M.car = nil
    M.nextAt = 0
    M.retryAt = 0
    stopCustom('mission ' .. tostring(M.owner))
end

function M.restoreAfterMission()
    M.owner = nil
    M.car = nil
    M.nextAt = 0
    M.retryAt = 0
    -- The next in-car update starts the local station again.
end

function M.update(context)
    if not runtime.worldReady() or not isPlayerPlaying(PLAYER_HANDLE) then
        stopCustom('gameplay unavailable')
        return
    end

    if not isCharInAnyCar(PLAYER_PED) then
        if M.car and M.previous[M.car] ~= nil
            and M.previous[M.car] ~= config.offChannel then
            M.lastStation = M.previous[M.car]
        end

        if M.car then
            M.previous[M.car] = nil
        end

        stopCustom('player left vehicle')
        M.car = nil
        M.nextAt = 0
        return
    end

    local car = playerCar()
    if not car then return end

    local now = getGameTimer()

    if M.car ~= car then
        stopCustom('vehicle changed')
        M.car = car
        M.nextAt = now + (tonumber(config.settleMs) or 750)
        M.retryAt = M.nextAt
        return
    end

    if M.paused or now < M.nextAt then return end
    M.nextAt = now + (tonumber(config.pollMs) or 500)

    for oldCar in pairs(M.previous) do
        if not doesVehicleExist(oldCar) then
            M.previous[oldCar] = nil
        end
    end

    local channel = readChannel()
    if channel ~= nil and M.previous[car] == nil then
        M.previous[car] = channel
        if channel ~= config.offChannel then
            M.lastStation = channel
        end
    end

    if M.owner then
        forceNativeRadioOff()
        stopCustom('mission override')
        return
    end

    if context and context.mission == true then
        forceNativeRadioOff()
        stopCustom('mission active')
        return
    end

    if not config.customEnabled then
        stopCustom('custom radio disabled')
        restoreNativeRadio()
        return
    end

    -- Prevent the GTA station from mixing with our local playlist.
    forceNativeRadioOff()

    local customActive = updateCustom(now)
    if not customActive and config.fallbackToNative then
        restoreNativeRadio()
    end
end

return M

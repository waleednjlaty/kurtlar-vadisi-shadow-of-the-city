local M = {
    handle = nil,
    voice = nil,
    paused = false,
    musicVolume = 0.50
}


--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function fileExists(path)

    local f = io.open(path, 'rb')

    if f then
        f:close()
        return true
    end

    return false
end


--------------------------------------------------
-- AUDIO LOADER
--
-- Supports BOTH MoonLoader APIs:
--
-- New:
--   AudioStream = loadAudioStream(path)
--
-- Legacy/opcode-style:
--   bool, handle = loadAudioStream(path)
--------------------------------------------------

local function loadStream(path)

    print(
        '[KVS] AUDIO: loadStream('
        .. tostring(path)
        .. ')'
    )


    local a, b =
        loadAudioStream(path)


    print(
        '[KVS] AUDIO: return #1 type='
        .. type(a)
        .. ' value='
        .. tostring(a)
    )


    print(
        '[KVS] AUDIO: return #2 type='
        .. type(b)
        .. ' value='
        .. tostring(b)
    )


    --------------------------------------------------
    -- MOONLOADER AudioStream userdata
    --------------------------------------------------

    if type(a) == 'userdata' then

        print(
            '[KVS] AUDIO: userdata AudioStream detected'
        )

        return a
    end


    --------------------------------------------------
    -- SOME BUILDS MAY RETURN HANDLE DIRECTLY
    --------------------------------------------------

    if type(a) == 'number'
        and b == nil then


        if a ~= 0 then

            print(
                '[KVS] AUDIO: numeric handle detected: '
                .. tostring(a)
            )

            return a
        end


        return nil
    end


    --------------------------------------------------
    -- LEGACY:
    -- bool success, handle
    --------------------------------------------------

    if type(a) == 'boolean' then

        if a
            and (type(b) == 'userdata' or type(b) == 'number')
            and b ~= 0 then


            print(
                '[KVS] AUDIO: legacy handle detected: '
                .. tostring(b)
            )

            return b
        end


        print(
            '[KVS] AUDIO: legacy load failed'
        )

        return nil
    end


    --------------------------------------------------
    -- FALLBACK
    --------------------------------------------------

    -- Unknown values are not valid native stream handles.


    print(
        '[KVS] AUDIO ERROR: '
        .. 'loadAudioStream returned no stream'
    )


    return nil
end


--------------------------------------------------
-- SAFE RELEASE
--------------------------------------------------

local function safeRelease(handle)

    if not handle then
        return
    end


    --------------------------------------------------
    -- STOP
    --------------------------------------------------

    local stopOk, stopError =
        pcall(
            setAudioStreamState,
            handle,
            0
        )


    if not stopOk then

        print(
            '[KVS] AUDIO: stop warning: '
            .. tostring(stopError)
        )
    end


    --------------------------------------------------
    -- RELEASE
    --------------------------------------------------

    local releaseOk, releaseError =
        pcall(
            releaseAudioStream,
            handle
        )


    if not releaseOk then

        print(
            '[KVS] AUDIO: release warning: '
            .. tostring(releaseError)
        )
    end
end


--------------------------------------------------
-- MUSIC PATH
--------------------------------------------------

--------------------------------------------------
-- FREE ROAM WALKING MUSIC (same loader/release API)
--------------------------------------------------

local ambient = {
    handle = nil,
    volume = 0.12,
    fadeMs = 2500,
    nextAt = nil,
    lastTrack = nil,
    fadeToken = nil,
    tracks = {
        'walk_01_Pusu2003.mp3',
        'walk_02_Gurbet2003.mp3',
        'walk_03_GurbetV2.mp3',
        'walk_04_10BinYil.mp3'
    }
}

local function scheduleAmbient(now)
    ambient.nextAt = now + math.random(10000, 15000)
end

function M.stopFreeRoam(fadeMs)
    ambient.nextAt = nil
    local stream = ambient.handle
    if not stream then return end

    if not fadeMs or fadeMs <= 0 then
        ambient.handle = nil
        ambient.fadeToken = nil
        safeRelease(stream)
        return
    end

    -- Repeated blocked frames must not restart the fade.
    if ambient.fadeToken then return end
    local token = {}
    ambient.fadeToken = token
    local started = getGameTimer()
    lua_thread.create(function()
        while ambient.handle == stream and ambient.fadeToken == token do
            wait(30)
            if ambient.handle ~= stream or ambient.fadeToken ~= token then return end
            if not M.paused then
                local progress = math.min(1, math.max(0, getGameTimer() - started) / fadeMs)
                local ok = pcall(setAudioStreamVolume, stream, ambient.volume * (1 - progress))
                if not ok or progress >= 1 then
                    M.stopFreeRoam()
                    return
                end
            end
        end
    end)
end

function M.setMissionActive(value)
    if value == true then
        M.stopFreeRoam(ambient.fadeMs)
    else
        ambient.nextAt = nil
    end
end

local function startAmbient()
    local choices = {}
    local root = getGameDirectory() .. '\\moonloader\\KurtlarVadisi\\playlist\\'
    for _, track in ipairs(ambient.tracks) do
        if track ~= ambient.lastTrack and fileExists(root .. track) then
            choices[#choices + 1] = track
        end
    end
    -- Even if only one file remains, never repeat the previous track.
    if #choices == 0 then return false end
    local track = choices[math.random(1, #choices)]
    local ok, stream = pcall(loadStream, root .. track)
    if not ok or not stream then return false end

    local volumeOk = pcall(setAudioStreamVolume, stream, ambient.volume)
    local loopOk = pcall(setAudioStreamLooped, stream, false)
    if not volumeOk or not loopOk then
        safeRelease(stream)
        return false
    end
    local playOk = pcall(setAudioStreamState, stream, 1)
    if not playOk then
        safeRelease(stream)
        return false
    end
    ambient.handle = stream
    ambient.lastTrack = track
    ambient.nextAt = nil
    print('[KVS] Walking ambient: ' .. track .. ' (12%)')
    return true
end

-- Main supplies gameplay, pause, mission and vehicle state.  Pausing takes
-- precedence over a transient isPlayerPlaying=false in the ESC menu so the
-- current free-roam track can resume instead of being released.
function M.updateFreeRoam(context)
    local c = context or {}
    local now = c.now or getGameTimer()
    -- Mission music always preempts an unfinished ambient fade.
    if c.mission == true then
        M.stopFreeRoam(ambient.fadeMs)
        return
    end
    if c.paused or M.paused then
        if not ambient.handle then
            ambient.nextAt = nil
        end
        return
    end
    if c.gameplay ~= true or c.inCar == true then
        -- GTA's own radio owns in-car audio outside missions.
        if c.inCar == true and ambient.handle then
            print('[KVS] Walking ambient stopped for vehicle')
        end
        M.stopFreeRoam()
        return
    end
    if ambient.fadeToken then return end

    if ambient.handle then
        local ok, state = pcall(getAudioStreamState, ambient.handle)
        if not ok or state == 0 then
            M.stopFreeRoam()
            scheduleAmbient(now)
        end
        return
    end

    if not ambient.nextAt or now < ambient.nextAt - 15000 then
        scheduleAmbient(now)
    elseif now >= ambient.nextAt then
        if not startAmbient() then
            -- Missing/unreadable tracks are retried without per-frame spam.
            scheduleAmbient(now)
        end
    end
end


function M.path()

    local path =
        getGameDirectory()
        .. '\\moonloader\\KurtlarVadisi\\audio\\missions\\miss1.mp3'


    if not fileExists(path) then

        error(
            'Missing mission music: '
            .. path
        )
    end


    print(
        '[KVS] Music found: '
        .. path
    )


    return path
end


--------------------------------------------------
-- START MUSIC
--------------------------------------------------

function M.start()

    -- Mission music has priority, including over a pending fade.
    M.stopFreeRoam()

    --------------------------------------------------
    -- ALREADY ACTIVE
    --------------------------------------------------

    if M.handle then

        print(
            '[KVS] AUDIO: music already active'
        )

        return true
    end


    --------------------------------------------------
    -- GET FILE
    --------------------------------------------------

    local path =
        M.path()


    print(
        '[KVS] AUDIO: starting miss1.mp3'
    )


    --------------------------------------------------
    -- LOAD
    --------------------------------------------------

    local handle =
        loadStream(path)


    if not handle then

        print(
            '[KVS] AUDIO ERROR: '
            .. 'could not create AudioStream'
        )

        return false
    end


    M.handle =
        handle


    M.paused =
        false


    print(
        '[KVS] AUDIO: valid stream='
        .. tostring(M.handle)
    )


    --------------------------------------------------
    -- CHECK LENGTH
    --------------------------------------------------

    local lengthOk, length =
        pcall(
            getAudioStreamLength,
            M.handle
        )


    if lengthOk and (type(length) ~= 'number' or length <= 0) then
        M.handle = nil
        safeRelease(handle)
        return false
    end
    if lengthOk then

        print(
            '[KVS] AUDIO: length='
            .. tostring(length)
        )

    else

        print(
            '[KVS] AUDIO: length check unavailable: '
            .. tostring(length)
        )
    end


    --------------------------------------------------
    -- VOLUME
    --------------------------------------------------

    print(
        '[KVS] AUDIO: setting volume='
        .. tostring(M.musicVolume)
    )


    local volumeOk, volumeError =
        pcall(
            setAudioStreamVolume,
            M.handle,
            M.musicVolume
        )


    if not volumeOk then

        print(
            '[KVS] AUDIO ERROR: volume failed: '
            .. tostring(volumeError)
        )

        safeRelease(
            M.handle
        )

        M.handle =
            nil

        return false
    end


    --------------------------------------------------
    -- LOOP
    --------------------------------------------------

    local loopOk, loopError =
        pcall(
            setAudioStreamLooped,
            M.handle,
            true
        )


    if not loopOk then

        print(
            '[KVS] AUDIO: loop warning: '
            .. tostring(loopError)
        )
    end


    --------------------------------------------------
    -- PLAY
    --------------------------------------------------

    print(
        '[KVS] AUDIO: BEFORE PLAY'
    )


    local playOk, playError =
        pcall(
            setAudioStreamState,
            M.handle,
            1
        )


    if not playOk then

        print(
            '[KVS] AUDIO ERROR: PLAY failed: '
            .. tostring(playError)
        )


        safeRelease(
            M.handle
        )


        M.handle =
            nil


        return false
    end


    print(
        '[KVS] AUDIO: AFTER PLAY'
    )


    --------------------------------------------------
    -- READ STATE
    --------------------------------------------------

    local stateOk, streamState =
        pcall(
            getAudioStreamState,
            M.handle
        )


    if stateOk then

        print(
            '[KVS] AUDIO: stream state='
            .. tostring(streamState)
        )
    end


    print(
        '[KVS] =================================='
    )

    print(
        '[KVS] CUSTOM MUSIC IS PLAYING'
    )

    print(
        '[KVS] =================================='
    )


    return true
end


--------------------------------------------------
-- VOLUME
--------------------------------------------------

function M.volume(value)

    value =
        tonumber(value)
        or M.musicVolume


    value =
        math.max(
            0.0,
            math.min(
                1.0,
                value
            )
        )


    M.musicVolume =
        value


    if M.handle then

        local ok, err =
            pcall(
                setAudioStreamVolume,
                M.handle,
                value
            )


        if not ok then

            print(
                '[KVS] AUDIO: volume warning: '
                .. tostring(err)
            )
        end
    end
end


--------------------------------------------------
-- PAUSE / RESUME
--------------------------------------------------

function M.pause(value)

    value =
        value == true


    if value == M.paused then
        return
    end


    M.paused =
        value

    ambient.nextAt = nil
    if ambient.handle then
        local ok = pcall(setAudioStreamState, ambient.handle, value and 2 or 3)
        if ok then print('[KVS] Walking ambient ' .. (value and 'paused' or 'resumed')) end
    end


    --------------------------------------------------
    -- MUSIC
    --------------------------------------------------

    if M.handle then

        if value then

            pcall(
                setAudioStreamState,
                M.handle,
                2
            )

        else

            pcall(
                setAudioStreamState,
                M.handle,
                3
            )
        end
    end


    --------------------------------------------------
    -- VOICE
    --------------------------------------------------

    if M.voice then

        if value then

            pcall(
                setAudioStreamState,
                M.voice,
                2
            )

        else

            pcall(
                setAudioStreamState,
                M.voice,
                3
            )
        end
    end
end


--------------------------------------------------
-- FADE OUT
--------------------------------------------------

function M.fadeOut(ms)
    if not M.handle or M.fadeToken then return end
    local stream, token = M.handle, {}
    M.fadeToken = token
    local duration = math.max(100, tonumber(ms) or 3000)
    local startVolume, started = M.musicVolume, getGameTimer()
    lua_thread.create(function()
        while M.handle == stream and M.fadeToken == token do
            wait(30)
            -- A stop/New Game during wait invalidates the userdata.
            if M.handle ~= stream or M.fadeToken ~= token then return end
            if not M.paused then
                local progress = math.min(1, math.max(0, getGameTimer()-started)/duration)
                pcall(setAudioStreamVolume, stream, startVolume*(1-progress))
                if progress >= 1 then return end
            end
        end
    end)
end


--------------------------------------------------
-- DIALOGUE VOICE
--------------------------------------------------

function M.dialogueVoice(file)

    M.stopFreeRoam()

    --------------------------------------------------
    -- REMOVE PREVIOUS VOICE
    --------------------------------------------------

    if M.voice then

        safeRelease(
            M.voice
        )

        M.voice =
            nil
    end


    if not file then
        return false
    end


    --------------------------------------------------
    -- FILE PATH
    --------------------------------------------------

    local path =
        getGameDirectory()
        .. '\\moonloader\\KurtlarVadisi\\audio\\'
        .. file


    if not fileExists(path) then

        print(
            '[KVS] Dialogue missing: '
            .. path
        )

        return false
    end


    --------------------------------------------------
    -- LOAD
    --------------------------------------------------

    local handle =
        loadStream(path)


    if not handle then

        print(
            '[KVS] Dialogue failed to load: '
            .. tostring(file)
        )

        return false
    end


    M.voice =
        handle


    --------------------------------------------------
    -- CONFIG
    --------------------------------------------------

    pcall(
        setAudioStreamVolume,
        M.voice,
        1.0
    )


    pcall(
        setAudioStreamLooped,
        M.voice,
        false
    )


    --------------------------------------------------
    -- PLAY
    --------------------------------------------------

    local ok, err =
        pcall(
            setAudioStreamState,
            M.voice,
            1
        )


    if not ok then

        print(
            '[KVS] Dialogue PLAY failed: '
            .. tostring(err)
        )


        safeRelease(
            M.voice
        )


        M.voice =
            nil


        return false
    end


    print(
        '[KVS] Dialogue playing: '
        .. tostring(file)
    )


    return true
end


--------------------------------------------------
-- STOP
--------------------------------------------------

function M.stop()
    M.fadeToken = nil

    M.stopFreeRoam()

    --------------------------------------------------
    -- MUSIC
    --------------------------------------------------

    if M.handle then

        local stream =
            M.handle


        M.handle =
            nil


        safeRelease(
            stream
        )
    end


    --------------------------------------------------
    -- VOICE
    --------------------------------------------------

    if M.voice then

        local stream =
            M.voice


        M.voice =
            nil


        safeRelease(
            stream
        )
    end


    M.paused =
        false


    print(
        '[KVS] Audio stopped'
    )
end


return M

local C =
    require 'KurtlarVadisi.config.characters'
local V =
    require 'KurtlarVadisi.config.vehicles'
local L =
    require 'KurtlarVadisi.config.locations'
local E =
    require 'KurtlarVadisi.systems.entity_manager'
local models =
    require 'KurtlarVadisi.systems.model_loader'
local objective =
    require 'KurtlarVadisi.systems.objective'
local camera =
    require 'KurtlarVadisi.systems.cinematic'
local dialogue =
    require 'KurtlarVadisi.systems.dialogue'
local audio =
    require 'KurtlarVadisi.systems.audio'
local radio =
    require 'KurtlarVadisi.systems.radio'
local weather =
    require 'KurtlarVadisi.systems.weather'
local log =
    require 'KurtlarVadisi.systems.logger'
local runtime = require 'KurtlarVadisi.systems.runtime'
local M = {
    id = '001',
    title = 'Geceye Donus',
    progressKey = '001_geceye_donus'
}
--------------------------------------------------
-- BASIC HELPERS
--------------------------------------------------
local function now()
    return getGameTimer()
end
local function elapsed()
    return now() - M.since
end
local function state(name)
    M.state = name
    M.since = now()
    M.events = {}
    log.info(
        'Mission 001 ' ..
        tostring(name)
    )
end
local function once(
    key,
    condition,
    callback
)
    if condition
        and not M.events[key] then
        M.events[key] = true
        callback()
    end
end
local function vehicleExists()
    return M.car
        and doesVehicleExist(M.car)
end
local function pedExists(ped)
    return ped
        and doesCharExist(ped)
end
local function distanceTo(
    car,
    point
)
    if not car
        or not doesVehicleExist(car) then
        return 999999.0
    end
    local x, y, z =
        getCarCoordinates(car)
    return math.sqrt(
        (x - point.x) ^ 2 +
        (y - point.y) ^ 2 +
        (z - point.z) ^ 2
    )
end
local function playerDistanceTo(point)
    if not doesCharExist(PLAYER_PED) then return 999999.0 end
    local x, y, z = getCharCoordinates(PLAYER_PED)
    return math.sqrt((x - point.x) ^ 2 + (y - point.y) ^ 2 + (z - point.z) ^ 2)
end
--------------------------------------------------
-- CLOSEST VEHICLE ROAD NODE
--------------------------------------------------
local function roadDistance(a, b)
    return math.sqrt(
        (a.x - b.x) ^ 2 +
        (a.y - b.y) ^ 2 +
        (a.z - b.z) ^ 2
    )
end
local function loadRoadArea(point)
    log.info(
        string.format(
            'ROAD: loading scene near %.2f %.2f %.2f',
            point.x,
            point.y,
            point.z
        )
    )
    requestCollision(
        point.x,
        point.y
    )
    loadScene(
        point.x,
        point.y,
        point.z
    )
    log.info(
        'ROAD: scene loaded'
    )
end
local function resolveStartRoadNode(point)
    loadRoadArea(point)
    local x, y, z, heading =
        getClosestCarNodeWithHeading(
            point.x,
            point.y,
            point.z
        )
    assert(
        type(x) == 'number'
        and type(y) == 'number'
        and type(z) == 'number'
        and type(heading) == 'number',
        'Could not resolve start vehicle road node'
    )
    local node = {
        x = x,
        y = y,
        z = z,
        heading = heading
    }
    local raw = {
        x = point.x,
        y = point.y,
        z = point.z
    }
    local delta =
        roadDistance(
            node,
            raw
        )
    log.info(
        string.format(
            'ROAD START: raw %.2f %.2f %.2f -> node %.2f %.2f %.2f heading %.2f delta %.2f',
            point.x,
            point.y,
            point.z,
            node.x,
            node.y,
            node.z,
            node.heading,
            delta
        )
    )
    assert(
        delta < 250.0,
        string.format(
            'Start road node is too far away: %.2f m',
            delta
        )
    )
    return node
end
local function resolveTargetRoadNode(point)
    loadRoadArea(point)
    local x, y, z =
        getClosestCarNode(
            point.x,
            point.y,
            point.z
        )
    assert(
        type(x) == 'number'
        and type(y) == 'number'
        and type(z) == 'number',
        'Could not resolve restaurant vehicle road node'
    )
    local node = {
        x = x,
        y = y,
        z = z
    }
    local raw = {
        x = point.x,
        y = point.y,
        z = point.z
    }
    local delta =
        roadDistance(
            node,
            raw
        )
    log.info(
        string.format(
            'ROAD TARGET: raw %.2f %.2f %.2f -> node %.2f %.2f %.2f delta %.2f',
            point.x,
            point.y,
            point.z,
            node.x,
            node.y,
            node.z,
            delta
        )
    )
    assert(
        delta < 250.0,
        string.format(
            'Restaurant road node is too far away: %.2f m',
            delta
        )
    )
    return node
end
--------------------------------------------------
-- CAMERA
--------------------------------------------------
local function lookAtPlayer(
    dx,
    dy,
    dz
)
    local x, y, z =
        getCharCoordinates(
            PLAYER_PED
        )
    camera.shot(
        x + dx,
        y + dy,
        z + dz,
        x,
        y,
        z + 0.5
    )
end
--------------------------------------------------
-- MODELS
--------------------------------------------------
local function requestAll()
    local required = {
        {
            name = 'Polat',
            id = C.polat
        },
        {
            name = 'Memati',
            id = C.memati
        },
        {
            name = 'Abdulhey',
            id = C.abdulhey
        },
        {
            name = 'Messenger',
            id = C.messenger
        },
        {
            name = V.displayName or 'Mission vehicle',
            id = V.bmw
        }
    }
    M.requested = {}
    log.info(
        'Mission 001: Starting model loading'
    )
    for _, model
        in ipairs(required) do
        assert(
            type(model.id) == 'number',
            'Invalid model ID: ' ..
            tostring(model.name)
        )
        log.info(
            'Loading model: ' ..
            model.name ..
            ' ID=' ..
            tostring(model.id)
        )
        local success =
            models.load(
                model.id,
                10000
            )
        assert(
            success,
            'Model load failed: ' ..
            tostring(model.name)
        )
        table.insert(
            M.requested,
            model.id
        )
        log.info(
            'Model loaded successfully: ' ..
            model.name ..
            ' ID=' ..
            tostring(model.id)
        )
    end
    requestAnimation(
        'DEALER'
    )
    log.info(
        'Mission 001: All required models loaded successfully'
    )
end
local function allModelsLoaded()
    for _, id
        in ipairs(M.requested or {}) do
        if not hasModelLoaded(id) then
            return false
        end
    end
    return true
end
local function releaseModels()
    for _, id
        in ipairs(M.requested or {}) do
        if hasModelLoaded(id) then
            pcall(markModelAsNoLongerNeeded, id)
        end
    end
    M.requested = {}
end
--------------------------------------------------
-- SPAWN ENTITIES
--------------------------------------------------
local function instantiate()
    log.info(
        'Mission 001: Instantiating mission entities'
    )
    --------------------------------------------------
    -- POLAT
    --------------------------------------------------
    assert(getCharModel(PLAYER_PED) == C.polat, 'Polat must be ready before mission start')
    --------------------------------------------------
    -- CAR
    --
    -- IMPORTANT:
    -- Spawn on actual vehicle road node,
    -- NOT raw L.approach coordinates.
    --------------------------------------------------
    local p =
        M.startRoad
    M.car = E.spawnCar(
        V.bmw,
        p.x,
        p.y,
        p.z + 0.5,
        p.heading,
        false
    )
    assert(
        vehicleExists(),
        'Mission vehicle creation failed'
    )
    changeCarColour(
        M.car,
        V.primaryColour or 0,
        V.secondaryColour or 0
    )
    setCarHealth(
        M.car,
        1000
    )
    setCarProofs(
        M.car,
        true,
        true,
        true,
        true,
        true
    )
    --------------------------------------------------
    -- ENGINE ON
    --------------------------------------------------
    setCarEngineOn(
        M.car,
        true
    )
    log.info(
        (V.displayName or 'Mission vehicle') .. ' created on road node. Handle=' ..
        tostring(M.car)
    )
    --------------------------------------------------
    -- MEMATI
    --------------------------------------------------
    local mematiOk, memati = pcall(
        createCharInsideCar,
        M.car,
        4,
        C.memati
    )
    M.memati = memati
    assert(
        mematiOk
        and pedExists(M.memati),
        'Memati creation failed'
    )
    table.insert(
        E.chars,
        M.memati
    )
    log.info(
        'Memati created successfully. Handle=' ..
        tostring(M.memati)
    )
    --------------------------------------------------
    -- ABDULHEY
    --------------------------------------------------
    local passengerCallOk, success, abdulhey = pcall(
        createCharAsPassenger,
        M.car,
        4,
        C.abdulhey,
        0
    )
    M.abdulhey = abdulhey
    assert(
        passengerCallOk
        and success
        and pedExists(M.abdulhey),
        'Abdulhey creation failed'
    )
    table.insert(
        E.chars,
        M.abdulhey
    )
    log.info(
        'Abdulhey created successfully. Handle=' ..
        tostring(M.abdulhey)
    )
    --------------------------------------------------
    -- NPC PROOFS
    --------------------------------------------------
    setCharProofs(
        M.memati,
        true,
        true,
        true,
        true,
        true
    )
    setCharProofs(
        M.abdulhey,
        true,
        true,
        true,
        true,
        true
    )
    --------------------------------------------------
    -- POLAT PASSENGER
    --------------------------------------------------
    warpCharIntoCarAsPassenger(
        PLAYER_PED,
        M.car,
        1
    )
    assert(
        isCharInCar(
            PLAYER_PED,
            M.car
        ),
        'Polat could not enter mission vehicle'
    )
    M.spawned = true
    log.info(
        'Seats: Memati driver; ' ..
        'Abdulhey passenger 0; ' ..
        'Polat passenger 1'
    )
    log.info(
        string.format(
            'CAR SPAWN POSITION: %.2f %.2f %.2f',
            p.x,
            p.y,
            p.z
        )
    )
    log.info(
        'Mission 001: Mission entities created successfully'
    )
end
--------------------------------------------------
-- GIVE DRIVE COMMAND
--------------------------------------------------
local function issueDriveCommand()
    assert(
        vehicleExists(),
        'Mission vehicle unavailable'
    )
    assert(
        pedExists(M.memati),
        'Memati unavailable'
    )
    assert(
        isCharInCar(
            M.memati,
            M.car
        ),
        'Memati is not inside mission vehicle'
    )
    assert(
        getDriverOfCar(
            M.car
        ) == M.memati,
        'Memati is not the mission vehicle driver'
    )
    local target =
        M.restaurantRoad
    local speed =
        math.max(
            tonumber(V.cinematicSpeed) or 12.0,
            12.0
        )
    setCarEngineOn(
        M.car,
        true
    )
    setCarCruiseSpeed(
        M.car,
        speed
    )
    setCarDrivingStyle(
        M.car,
        2
    )
    log.info(
        string.format(
            'MEMATI DRIVE: target %.2f %.2f %.2f speed %.2f',
            target.x,
            target.y,
            target.z,
            speed
        )
    )
    log.info(
        'MEMATI DRIVE: BEFORE taskCarDriveToCoord'
    )
    taskCarDriveToCoord(
        M.memati,
        M.car,
        target.x,
        target.y,
        target.z,
        speed,
        0,
        0,
        2
    )
    log.info(
        'MEMATI DRIVE: AFTER taskCarDriveToCoord'
    )
    M.lastDriveKick =
        now()
    M.lastDriveDistance =
        distanceTo(
            M.car,
            target
        )
end
--------------------------------------------------
-- ANTI-STUCK WATCHDOG
--------------------------------------------------
local function updateDrivingWatchdog()
    if not vehicleExists()
        or not pedExists(M.memati) then
        return
    end
    if getDriverOfCar(
        M.car
    ) ~= M.memati then
        log.info(
            'DRIVE WATCHDOG: Memati is no longer the driver'
        )
        return
    end
    local target =
        M.restaurantRoad
    local currentDistance =
        distanceTo(
            M.car,
            target
        )
    if currentDistance < 15.0 then
        return
    end
    if now()
        - (M.lastDriveKick or 0)
        < 3500 then
        return
    end
    local ok, speed =
        pcall(
            getCarSpeed,
            M.car
        )
    if not ok then
        speed = 0.0
    end
    speed =
        tonumber(speed)
        or 0.0
    local previousDistance =
        M.lastDriveDistance
        or currentDistance
    local progress =
        previousDistance
        - currentDistance
    log.info(
        string.format(
            'DRIVE WATCHDOG: speed=%.2f distance=%.2f progress=%.2f',
            speed,
            currentDistance,
            progress
        )
    )
    if math.abs(speed) < 0.5
        or progress < 0.5 then
        local driveSpeed =
            math.max(
                tonumber(V.cinematicSpeed) or 12.0,
                12.0
            )
        log.info(
            'DRIVE WATCHDOG: reissuing Memati drive task'
        )
        setCarEngineOn(
            M.car,
            true
        )
        setCarCruiseSpeed(
            M.car,
            driveSpeed
        )
        setCarDrivingStyle(
            M.car,
            2
        )
        taskCarDriveToCoord(
            M.memati,
            M.car,
            target.x,
            target.y,
            target.z,
            driveSpeed,
            0,
            0,
            2
        )
    end
    M.lastDriveDistance =
        currentDistance
    M.lastDriveKick =
        now()
end
--------------------------------------------------
-- START
--------------------------------------------------
function M.start()
    M.epoch = runtime.epoch
    assert(runtime.worldReady(), 'Mission requires gameplay')
    M.done = false
    M.spawned = false
    M.car = nil
    M.memati = nil
    M.abdulhey = nil
    M.messenger = nil
    M.requested = {}
    M.lastDriveKick = 0
    M.lastDriveDistance = nil
    radio.disableForMission(M.id)
    camera.begin() -- Black screen/control lock before scene streaming.
    M.origin = {
        getCharCoordinates(
            PLAYER_PED
        )
    }
    --------------------------------------------------
    -- LOAD START AREA, THEN RESOLVE ITS ROAD NODE
    --------------------------------------------------
    log.info(
        'Mission 001: resolving START road node'
    )
    M.startRoad =
        resolveStartRoadNode(
            L.approach
        )
    --------------------------------------------------
    -- LOAD RESTAURANT AREA, THEN RESOLVE TARGET NODE
    --------------------------------------------------
    log.info(
        'Mission 001: resolving RESTAURANT road node'
    )
    M.restaurantRoad =
        resolveTargetRoadNode(
            L.restaurant
        )
    --------------------------------------------------
    -- VALIDATE ROUTE
    --------------------------------------------------
    local routeDistance =
        roadDistance(
            M.startRoad,
            M.restaurantRoad
        )
    log.info(
        string.format(
            'MISSION ROUTE DISTANCE: %.2f',
            routeDistance
        )
    )
    assert(
        routeDistance > 30.0,
        string.format(
            'Mission route invalid: start and target are only %.2f m apart',
            routeDistance
        )
    )
    --------------------------------------------------
    -- RETURN STREAMING TO THE START AREA
    --------------------------------------------------
    loadRoadArea(
        M.startRoad
    )
    setCharCoordinates(
        PLAYER_PED,
        M.startRoad.x,
        M.startRoad.y,
        M.startRoad.z + 1.0
    )
    --------------------------------------------------
    -- MUSIC CHECK
    --------------------------------------------------
    audio.path()
    --------------------------------------------------
    -- SYSTEMS
    --------------------------------------------------
    dialogue.load()
    weather.start()
    setCurrentCharWeapon(
        PLAYER_PED,
        0
    )
    --------------------------------------------------
    -- MODELS
    --------------------------------------------------
    requestAll()
    log.info(
        string.format(
            'MISSION ROAD START: %.2f %.2f %.2f heading %.2f',
            M.startRoad.x,
            M.startRoad.y,
            M.startRoad.z,
            M.startRoad.heading
        )
    )
    log.info(
        string.format(
            'MISSION ROAD TARGET: %.2f %.2f %.2f',
            M.restaurantRoad.x,
            M.restaurantRoad.y,
            M.restaurantRoad.z
        )
    )
    --------------------------------------------------
    -- INTRO
    --------------------------------------------------
    state(
        'INTRO_BLACK_SCREEN'
    )
    log.info(
        'Mission 001 initialized'
    )
end
--------------------------------------------------
-- UPDATE
--------------------------------------------------
function M.update()
    assert(M.epoch == runtime.epoch and runtime.worldReady(), 'Mission lifecycle changed')
    weather.update()
    if M.spawned then
        assert(pedExists(M.memati) and not isCharDead(M.memati), 'Memati unavailable')
        assert(pedExists(M.abdulhey) and not isCharDead(M.abdulhey), 'Abdulhey unavailable')
    end
    local t =
        elapsed()
    --------------------------------------------------
    -- VEHICLE VALIDATION
    --------------------------------------------------
    if M.car then
        if not doesVehicleExist(
            M.car
        ) then
            error(
                'Mission vehicle disappeared'
            )
        end
        if isCarDead(
            M.car
        ) then
            error(
                'Mission vehicle destroyed'
            )
        end
    end
    --------------------------------------------------
    -- INTRO
    --------------------------------------------------
    if M.state ==
        'INTRO_BLACK_SCREEN' then
        camera.black = 1
        --------------------------------------------------
        -- SPAWN
        --------------------------------------------------
        once(
            'spawn',
            allModelsLoaded()
            and t > 700,
            function()
                instantiate()
                assert(M.epoch == runtime.epoch, 'Mission spawn cancelled by lifecycle change')
            end
        )
        --------------------------------------------------
        -- MUSIC
        --------------------------------------------------
        once(
            'music',
            M.spawned
            and t > 2800,
            function()
                log.info(
                    'MUSIC: before audio.start'
                )
                local success =
                    audio.start()
                assert(success, 'Mission music could not start')
                assert(success, 'Mission music could not start')
                log.info(
                    'MUSIC: audio.start returned ' ..
                    tostring(success)
                )
            end
        )
        --------------------------------------------------
        -- START CAR
        --------------------------------------------------
        once(
            'drive',
            M.spawned
            and t > 5000,
            function()
                log.info(
                    'CINEMATIC: issuing driving route'
                )
                issueDriveCommand()
                log.info(
                    'CINEMATIC: driving route active'
                )
                state(
                    'CAR_CINEMATIC'
                )
                dialogue.show(
                    'title',
                    5500
                )
            end
        )
    --------------------------------------------------
    -- CAR CINEMATIC
    --------------------------------------------------
    elseif M.state ==
        'CAR_CINEMATIC' then
        --------------------------------------------------
        -- ANTI-STUCK
        --------------------------------------------------
        updateDrivingWatchdog()
        --------------------------------------------------
        -- FADE FROM BLACK
        --------------------------------------------------
        camera.black =
            math.max(
                0,
                1 - t / 1800
            )
        --------------------------------------------------
        -- CAMERA
        --------------------------------------------------
        camera.carShot(
            M.car,
            math.min(
                4,
                math.floor(
                    t / 6500
                ) + 1
            )
        )
        --------------------------------------------------
        -- REACHED RESTAURANT ROAD NODE
        --------------------------------------------------
        if distanceTo(
            M.car,
            M.restaurantRoad
        ) < 10 then
            setCarCruiseSpeed(
                M.car,
                0
            )
            setCarForwardSpeed(
                M.car,
                0
            )
        end
        --------------------------------------------------
        -- DIALOGUE
        --------------------------------------------------
        if t > 26000 then
            state(
                'CAR_DIALOGUE'
            )
            dialogue.show(
                'memati_001',
                7200,
                'memati_001.wav'
            )
        end
    --------------------------------------------------
    -- CAR DIALOGUE
    --------------------------------------------------
    elseif M.state ==
        'CAR_DIALOGUE' then
        camera.carShot(
            M.car,
            4
        )
        --------------------------------------------------
        -- KEEP ROUTE ACTIVE
        --------------------------------------------------
        updateDrivingWatchdog()
        --------------------------------------------------
        -- POLAT REPLY
        --------------------------------------------------
        once(
            'reply',
            t > 7800,
            function()
                dialogue.show(
                    'polat_001',
                    10000,
                    'polat_001.wav'
                )
            end
        )
        --------------------------------------------------
        -- NEXT
        --------------------------------------------------
        if t > 18500 then
            dialogue.clear()
            state(
                'RESTAURANT_ARRIVAL'
            )
        end
    --------------------------------------------------
    -- RESTAURANT ARRIVAL
    --------------------------------------------------
    elseif M.state ==
        'RESTAURANT_ARRIVAL' then
        camera.carShot(
            M.car,
            3
        )
        --------------------------------------------------
        -- WAIT UNTIL CAR REACHES NODE
        --------------------------------------------------
        if not M.events.parked then
            if distanceTo(
                M.car,
                M.restaurantRoad
            ) < 12 then
                setCarCruiseSpeed(
                    M.car,
                    0
                )
                setCarForwardSpeed(
                    M.car,
                    0
                )
                carSetIdle(
                    M.car
                )
                taskLeaveCar(
                    PLAYER_PED,
                    M.car
                )
                M.events.parked =
                    now()
                log.info(
                    'Restaurant reached'
                )
            else
                updateDrivingWatchdog()
                if t > 90000 then
                    error(
                        'Vehicle could not reach restaurant'
                    )
                end
            end
        --------------------------------------------------
        -- POLAT LEFT CAR
        --------------------------------------------------
        elseif not isCharInAnyCar(
            PLAYER_PED
        ) then
            local x, y, z =
                getCharCoordinates(
                    PLAYER_PED
                )
            M.messenger =
                E.spawnChar(
                    4,
                    C.messenger,
                    x + 5,
                    y + 3,
                    z,
                    180,
                    false
                )
            assert(
                pedExists(
                    M.messenger
                ),
                'Messenger creation failed'
            )
            setCharProofs(
                M.messenger,
                true,
                true,
                true,
                true,
                true
            )
            taskGoStraightToCoord(
                M.messenger,
                x + 1,
                y,
                z,
                4,
                12000
            )
            state(
                'ENVELOPE_CUTSCENE'
            )
        elseif now()
            - M.events.parked
            > 15000 then
            error(
                'Player could not leave mission vehicle'
            )
        end
    --------------------------------------------------
    -- ENVELOPE CUTSCENE
    --------------------------------------------------
    elseif M.state ==
        'ENVELOPE_CUTSCENE' then
        if not pedExists(M.messenger) then
            error('Messenger disappeared during envelope cutscene')
        end
        lookAtPlayer(
            3,
            -4,
            1.4
        )
        once(
            'gesture',
            t > 5000,
            function()
                clearCharTasks(
                    M.messenger
                )
                taskLookAtChar(
                    M.messenger,
                    PLAYER_PED,
                    5000
                )
                taskLookAtChar(
                    PLAYER_PED,
                    M.messenger,
                    5000
                )
                if hasAnimationLoaded(
                    'DEALER'
                ) then
                    taskPlayAnim(
                        M.messenger,
                        'DEALER_DEAL',
                        'DEALER',
                        4.0,
                        false,
                        false,
                        false,
                        false,
                        2300
                    )
                    taskPlayAnim(
                        PLAYER_PED,
                        'DEALER_DEAL',
                        'DEALER',
                        4.0,
                        false,
                        false,
                        false,
                        false,
                        2300
                    )
                end
            end
        )
        once(
            'photo',
            t > 8000,
            function()
                dialogue.show(
                    'envelope',
                    6000
                )
                log.info(
                    'Envelope revealed: Selim Karahan'
                )
            end
        )
        once(
            'depart',
            t > 9000,
            function()
                local x, y, z =
                    getCharCoordinates(
                        M.messenger
                    )
                taskGoStraightToCoord(
                    M.messenger,
                    x + 14,
                    y + 10,
                    z,
                    4,
                    20000
                )
            end
        )
        once(
            'message',
            t > 14500,
            function()
                dialogue.show(
                    'wolves',
                    6000
                )
            end
        )
        if t > 21500 then
            dialogue.clear()
            clearCharTasks(
                PLAYER_PED
            )
            taskLeaveCar(
                M.memati,
                M.car
            )
            taskLeaveCar(
                M.abdulhey,
                M.car
            )
            state(
                'PLAYER_CONTROL'
            )
        end
    --------------------------------------------------
    -- PLAYER CONTROL
    --------------------------------------------------
    elseif M.state ==
        'PLAYER_CONTROL' then
        camera.carShot(
            M.car,
            3
        )
        once(
            'board',
            not isCharInAnyCar(
                M.memati
            )
            and
            not isCharInAnyCar(
                M.abdulhey
            ),
            function()
                taskEnterCarAsDriver(
                    PLAYER_PED,
                    M.car,
                    16000
                )
                taskEnterCarAsPassenger(
                    M.memati,
                    M.car,
                    16000,
                    0
                )
                taskEnterCarAsPassenger(
                    M.abdulhey,
                    M.car,
                    16000,
                    1
                )
            end
        )
        if M.events.board
            and
            getDriverOfCar(
                M.car
            ) == PLAYER_PED
            and
            isCharInCar(
                M.memati,
                M.car
            )
            and
            isCharInCar(
                M.abdulhey,
                M.car
            ) then
            camera.restore()
            local p =
                L.headquarters
            objective.set(
                'Karargaha git.',
                p.x,
                p.y,
                p.z,
                p.radius
            )
            dialogue.show(
                'objective',
                9000
            )
            state(
                'DRIVE_TO_BASE'
            )
        elseif t > 35000 then
            error(
                'Car boarding timed out'
            )
        end
    --------------------------------------------------
    -- DRIVE TO BASE
    --------------------------------------------------
    elseif M.state ==
        'DRIVE_TO_BASE' then
        local base = L.headquarters
        local carDistance = distanceTo(M.car, base)
        local polatDistance = playerDistanceTo(base)
        if isCharInCar(
            PLAYER_PED,
            M.car
        )
            and
            getDriverOfCar(
                M.car
            ) == PLAYER_PED
            and
            carDistance < base.radius
            and polatDistance < base.radius then
            log.info(string.format('HQ reached: vehicle %.2fm, Polat %.2fm', carDistance, polatDistance))
            objective.clear()
            dialogue.clear()
            camera.begin()
            camera.black = 0
            setCarForwardSpeed(
                M.car,
                0
            )
            setCarCruiseSpeed(
                M.car,
                0
            )
            taskLeaveCar(
                PLAYER_PED,
                M.car
            )
            taskLeaveCar(
                M.memati,
                M.car
            )
            taskLeaveCar(
                M.abdulhey,
                M.car
            )
            state(
                'BASE_CUTSCENE'
            )
        end
    --------------------------------------------------
    -- BASE CUTSCENE
    --------------------------------------------------
    elseif M.state ==
        'BASE_CUTSCENE' then
        local p =
            L.headquarters
        if t < 6500 then
            camera.shot(
                p.x - 18,
                p.y - 18,
                p.z + 11,
                p.x,
                p.y + 12,
                p.z + 5
            )
        else
            lookAtPlayer(
                3,
                -4,
                1.2
            )
        end
        once(
            'fade',
            t > 10500,
            function()
                audio.fadeOut(
                    3000
                )
            end
        )
        if t > 10500 then
            camera.black =
                math.min(
                    1,
                    (t - 10500)
                    / 3000
                )
        end
        if t > 14000 and (isCharInAnyCar(PLAYER_PED)
            or isCharInAnyCar(M.memati) or isCharInAnyCar(M.abdulhey)) then
            if t > 25000 then error('HQ exit timed out') end
            return
        end
        if t > 14000 then
            audio.stop()
            state(
                'MISSION_COMPLETE'
            )
            dialogue.show(
                'complete',
                6000
            )
            log.info(
                'Mission 001 completed'
            )
        end
    --------------------------------------------------
    -- COMPLETE
    --------------------------------------------------
    elseif M.state ==
        'MISSION_COMPLETE' then
        camera.black = 1
        if t > 6200 then
            M.done = true
        end
    end
end
--------------------------------------------------
-- DRAW
--------------------------------------------------
function M.draw()
    camera.draw()
    dialogue.draw()
end
--------------------------------------------------
-- CLEANUP
--------------------------------------------------
function M.cleanup(failed)
    if M.epoch ~= runtime.epoch then return end
    local function clean(label, fn)
        local ok, err = xpcall(fn, debug.traceback)
        if not ok then log.exception('Mission cleanup '..label, err) end
    end
    clean('radio', radio.restoreAfterMission)
    clean('dialogue', dialogue.clear)
    clean('audio', audio.stop)
    clean('objective', objective.clear)
    clean('player tasks', function()
        if doesCharExist(PLAYER_PED) and not isCharDead(PLAYER_PED) then clearCharTasks(PLAYER_PED) end
    end)
    clean('models', releaseModels)
    clean('animation', function()
        if hasAnimationLoaded('DEALER') then removeAnimation('DEALER') end
    end)
    clean('entities', E.cleanup)
    clean('weather', weather.stop)
    clean('camera', camera.restore)
    if failed and M.origin and isPlayerPlaying(PLAYER_HANDLE)
        and doesCharExist(PLAYER_PED) and not isCharDead(PLAYER_PED)
        and not isCharInAnyCar(PLAYER_PED) then
        clean('return to start', function()
            requestCollision(M.origin[1],M.origin[2])
            loadScene(M.origin[1],M.origin[2],M.origin[3])
            setCharCoordinates(PLAYER_PED,M.origin[1],M.origin[2],M.origin[3])
        end)
    end
end
return M

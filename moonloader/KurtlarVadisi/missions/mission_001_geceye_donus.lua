local C = require 'KurtlarVadisi.config.characters'
local V = require 'KurtlarVadisi.config.vehicles'
local L = require 'KurtlarVadisi.config.locations'
local E = require 'KurtlarVadisi.systems.entity_manager'
local objective = require 'KurtlarVadisi.systems.objective'
local camera = require 'KurtlarVadisi.systems.cinematic'
local dialogue = require 'KurtlarVadisi.systems.dialogue'
local audio = require 'KurtlarVadisi.systems.audio'
local radio = require 'KurtlarVadisi.systems.radio'
local weather = require 'KurtlarVadisi.systems.weather'
local log = require 'KurtlarVadisi.systems.logger'
local runtime = require 'KurtlarVadisi.systems.runtime'

local M = {
    id = '001',
    title = 'Geceye Donus',
    progressKey = '001_geceye_donus'
}

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
    log.info('Mission 001 ' .. tostring(name))
end

local function once(key, condition, callback)
    if condition and not M.events[key] then
        M.events[key] = true
        callback()
    end
end

local function vehicleExists()
    return M.car and doesVehicleExist(M.car)
end

local function pedExists(ped)
    return ped and doesCharExist(ped)
end

local function distanceToCar(car, point)
    if not car or not doesVehicleExist(car) then return 999999.0 end
    local x, y, z = getCarCoordinates(car)
    return math.sqrt((x - point.x) ^ 2 + (y - point.y) ^ 2 + (z - point.z) ^ 2)
end

local function playerDistanceTo(point)
    if not doesCharExist(PLAYER_PED) then return 999999.0 end
    local x, y, z = getCharCoordinates(PLAYER_PED)
    return math.sqrt((x - point.x) ^ 2 + (y - point.y) ^ 2 + (z - point.z) ^ 2)
end

local function roadDistance(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

local function loadRoadArea(point)
    requestCollision(point.x, point.y)
    loadScene(point.x, point.y, point.z)
end

local function resolveStartRoadNode(point)
    loadRoadArea(point)
    local x, y, z, heading = getClosestCarNodeWithHeading(point.x, point.y, point.z)
    assert(type(x) == 'number' and type(y) == 'number' and type(z) == 'number'
        and type(heading) == 'number', 'Could not resolve Mission 001 start road node')

    local node = {x = x, y = y, z = z, heading = heading}
    local delta = roadDistance(node, point)
    assert(delta < 250.0, string.format('Mission 001 start road node is too far away: %.2f m', delta))
    return node
end

local function lookAtPlayer(dx, dy, dz)
    local x, y, z = getCharCoordinates(PLAYER_PED)
    camera.shot(x + dx, y + dy, z + dz, x, y, z + 0.5)
end

local function validateMissionCar()
    if not M.car then return end
    if not doesVehicleExist(M.car) then error('BMW E46 disappeared') end
    if isCarDead(M.car) then error('BMW E46 was destroyed') end
end

local function spawnMissionCar()
    assert(getCharModel(PLAYER_PED) == C.polat, 'Polat must be ready before Mission 001 starts')

    local p = M.startRoad
    M.car = E.spawnCar(V.bmw, p.x, p.y, p.z + 0.5, p.heading, false)
    assert(vehicleExists(), 'BMW E46 creation failed')

    changeCarColour(M.car, V.primaryColour or 0, V.secondaryColour or 0)
    setCarHealth(M.car, 1000)
    setCarProofs(M.car, true, true, true, true, true)
    setCarEngineOn(M.car, true)

    local px, py, pz = getOffsetFromCarInWorldCoords(M.car, -2.2, 0.0, 0.5)
    setCharCoordinates(PLAYER_PED, px, py, pz)
    setCharHeading(PLAYER_PED, p.heading)
    taskEnterCarAsDriver(PLAYER_PED, M.car, 12000)

    log.info(string.format('BMW E46 spawned using model %d (%s)', V.bmw, V.modelName or 'primo'))
end

local function spawnMessenger()
    local x, y, z = getCharCoordinates(PLAYER_PED)
    M.messenger = E.spawnChar(4, C.messenger, x + 5.0, y + 3.0, z, 180.0, false)
    assert(pedExists(M.messenger), 'Messenger creation failed')

    setCharProofs(M.messenger, true, true, true, true, true)
    taskGoStraightToCoord(M.messenger, x + 1.2, y, z, 4, 12000)
    log.info('Unknown Messenger spawned for envelope exchange')
end

function M.start()
    M.epoch = runtime.epoch
    assert(runtime.worldReady(), 'Mission requires gameplay')

    M.done = false
    M.car = nil
    M.messenger = nil
    M.origin = {getCharCoordinates(PLAYER_PED)}

    radio.disableForMission(M.id)
    camera.begin()

    M.startRoad = resolveStartRoadNode(L.approach)
    loadRoadArea(M.startRoad)

    dialogue.load()
    weather.start()
    setCurrentCharWeapon(PLAYER_PED, 0)
    requestAnimation('DEALER')

    audio.path()
    spawnMissionCar()
    assert(M.epoch == runtime.epoch, 'Mission spawn cancelled by lifecycle change')

    state('INTRO_ENTER_CAR')
    log.info('Mission 001 initialized: Polat alone, BMW E46, night return')
end

function M.update()
    assert(M.epoch == runtime.epoch and runtime.worldReady(), 'Mission lifecycle changed')
    weather.update()
    validateMissionCar()

    local t = elapsed()

    if M.state == 'INTRO_ENTER_CAR' then
        camera.black = 1

        if vehicleExists() then
            camera.carShot(M.car, 1)
        end

        if isCharInCar(PLAYER_PED, M.car) and getDriverOfCar(M.car) == PLAYER_PED then
            local musicOk = audio.start()
            if not musicOk then log.warn('Mission music unavailable; continuing without it') end
            dialogue.show('title', 5000)
            state('INTRO_CINEMATIC')
        elseif t > 15000 then
            error('Polat could not enter the BMW E46')
        end

    elseif M.state == 'INTRO_CINEMATIC' then
        camera.black = math.max(0, 1 - t / 1800)
        camera.carShot(M.car, t < 2500 and 1 or 2)

        if t > 5000 then
            camera.restore()
            objective.set('Restorana git.', L.restaurant.x, L.restaurant.y, L.restaurant.z, L.restaurant.radius)
            dialogue.show('objective', 5000)
            state('DRIVE_TO_RESTAURANT')
        end

    elseif M.state == 'DRIVE_TO_RESTAURANT' then
        if objective.reached()
            and isCharInCar(PLAYER_PED, M.car)
            and getDriverOfCar(M.car) == PLAYER_PED then

            objective.clear()
            dialogue.clear()
            setCarForwardSpeed(M.car, 0)
            setCarCruiseSpeed(M.car, 0)

            camera.begin()
            camera.black = 0
            camera.carShot(M.car, 3)
            taskLeaveCar(PLAYER_PED, M.car)
            state('RESTAURANT_EXIT')
            log.info('Polat reached the restaurant alone')
        end

    elseif M.state == 'RESTAURANT_EXIT' then
        camera.black = 0
        camera.carShot(M.car, 3)

        if not isCharInAnyCar(PLAYER_PED) then
            spawnMessenger()
            state('ENVELOPE_CUTSCENE')
        elseif t > 15000 then
            error('Polat could not leave the BMW E46 at the restaurant')
        end

    elseif M.state == 'ENVELOPE_CUTSCENE' then
        if not pedExists(M.messenger) then
            error('Messenger disappeared during envelope cutscene')
        end

        camera.black = 0
        lookAtPlayer(3.0, -4.0, 1.4)

        once('gesture', t > 2800, function()
            clearCharTasks(M.messenger)
            taskLookAtChar(M.messenger, PLAYER_PED, 5000)
            taskLookAtChar(PLAYER_PED, M.messenger, 5000)

            if hasAnimationLoaded('DEALER') then
                taskPlayAnim(M.messenger, 'DEALER_DEAL', 'DEALER', 4.0,
                    false, false, false, false, 2300)
                taskPlayAnim(PLAYER_PED, 'DEALER_DEAL', 'DEALER', 4.0,
                    false, false, false, false, 2300)
            end
        end)

        once('envelope', t > 5200, function()
            dialogue.show('envelope', 7000)
            printStringNow('Selim Karahan  /  Pier 69  /  02:30', 7000)
            log.info('Envelope received: Selim Karahan / Pier 69 / 02:30')
        end)

        once('depart', t > 9800, function()
            local x, y, z = getCharCoordinates(M.messenger)
            taskGoStraightToCoord(M.messenger, x + 14.0, y + 10.0, z, 4, 20000)
        end)

        if t > 13800 then
            dialogue.clear()
            clearCharTasks(PLAYER_PED)
            camera.restore()

            objective.set('BMW E46 ile karargaha git.',
                L.headquarters.x, L.headquarters.y, L.headquarters.z, L.headquarters.radius)
            dialogue.show('objective', 6000)
            state('DRIVE_TO_BASE')
            log.info('Envelope scene complete; Polat leaves alone for HQ')
        end

    elseif M.state == 'DRIVE_TO_BASE' then
        local base = L.headquarters
        local carDistance = distanceToCar(M.car, base)
        local polatDistance = playerDistanceTo(base)

        if isCharInCar(PLAYER_PED, M.car)
            and getDriverOfCar(M.car) == PLAYER_PED
            and carDistance < base.radius
            and polatDistance < base.radius then

            objective.clear()
            dialogue.clear()
            setCarForwardSpeed(M.car, 0)
            setCarCruiseSpeed(M.car, 0)

            camera.begin()
            camera.black = 0
            taskLeaveCar(PLAYER_PED, M.car)
            state('BASE_CUTSCENE')
            log.info(string.format('HQ reached: BMW %.2fm, Polat %.2fm', carDistance, polatDistance))
        end

    elseif M.state == 'BASE_CUTSCENE' then
        local p = L.headquarters
        camera.black = 0

        if t < 6000 then
            camera.shot(p.x - 18.0, p.y - 18.0, p.z + 11.0,
                p.x, p.y + 12.0, p.z + 5.0)
        else
            lookAtPlayer(3.0, -4.0, 1.2)
        end

        once('fade_music', t > 7500, function()
            audio.fadeOut(2500)
        end)

        if t > 7500 then
            camera.black = math.min(1, (t - 7500) / 2500)
        end

        if t > 10500 then
            if isCharInAnyCar(PLAYER_PED) then
                if t > 20000 then error('Polat could not leave the BMW E46 at HQ') end
                return
            end

            audio.stop()
            dialogue.show('complete', 6000)
            state('MISSION_COMPLETE')
            log.info('Mission 001 completed: Geceye Donus')
        end

    elseif M.state == 'MISSION_COMPLETE' then
        camera.black = 1
        if t > 6200 then
            M.done = true
        end
    end
end

function M.draw()
    camera.draw()
    dialogue.draw()
end

function M.cleanup(failed)
    if M.epoch ~= runtime.epoch then return end

    local function clean(label, fn)
        local ok, err = xpcall(fn, debug.traceback)
        if not ok then log.exception('Mission cleanup ' .. label, err) end
    end

    clean('radio', radio.restoreAfterMission)
    clean('dialogue', dialogue.clear)
    clean('audio', audio.stop)
    clean('objective', objective.clear)
    clean('player tasks', function()
        if doesCharExist(PLAYER_PED) and not isCharDead(PLAYER_PED) then
            clearCharTasks(PLAYER_PED)
        end
    end)
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
            requestCollision(M.origin[1], M.origin[2])
            loadScene(M.origin[1], M.origin[2], M.origin[3])
            setCharCoordinates(PLAYER_PED, M.origin[1], M.origin[2], M.origin[3])
        end)
    end
end

return M

local entities = require 'KurtlarVadisi.systems.entity_manager'
local objective = require 'KurtlarVadisi.systems.objective'
local dialogue = require 'KurtlarVadisi.systems.dialogue'
local save = require 'KurtlarVadisi.systems.save'
local locations = require 'KurtlarVadisi.locations.los_santos'
local dialogueData = require 'KurtlarVadisi.dialogue.arrival'
local cinematic = require 'KurtlarVadisi.systems.cinematic'
local M = {
    id = '001',
    title = 'ARRIVAL',
    chapter = 1,

    stage = 0,

    source = nil,
    watcherCar = nil,

    ambushOne = nil,
    ambushTwo = nil
}


--------------------------------------------------
-- SCREEN FADE
--------------------------------------------------

local function screenFadeOut(duration)
    duration = duration or 1000

    doFade(0, duration)

    wait(duration + 100)
end


local function screenFadeIn(duration)
    duration = duration or 1000

    doFade(1, duration)

    wait(duration + 100)
end


--------------------------------------------------
-- UTILITY
--------------------------------------------------

local function showMissionTitle()

    printStringNow(
        'MISSION 01~n~ARRIVAL',
        5000
    )

end


local function getGroundZ(x, y)

    for i = 1, 60 do

        local z = entities.getGroundZ(x, y)

        if type(z) == 'number' then
            return z
        end

        wait(0)

    end

    return nil

end


--------------------------------------------------
-- SPAWN SOURCE
--------------------------------------------------

local function spawnSource()

    local place = locations.source

    local groundZ = getGroundZ(
        place.x,
        place.y
    )

    if not groundZ then
        return false
    end


    M.source = entities.spawnChar(
        4,
        7,
        place.x,
        place.y,
        groundZ,
        180.0,
        false
    )

    if not M.source then
        return false
    end


    freezeCharPosition(
        M.source,
        true
    )

    return true

end


--------------------------------------------------
-- SPAWN WATCHER CAR
--------------------------------------------------

local function spawnWatcherCar()

    local place = locations.watcher_car

    local groundZ = getGroundZ(
        place.x,
        place.y
    )

    if not groundZ then
        return false
    end


    M.watcherCar = entities.spawnCar(
        560,
        place.x,
        place.y,
        groundZ,
        place.heading,
        false
    )

    if not M.watcherCar then
        return false
    end

    return true

end


--------------------------------------------------
-- SPAWN AMBUSH
--------------------------------------------------

local function spawnAmbush()

    local one = locations.ambush_one
    local two = locations.ambush_two


    M.ambushOne = entities.spawnChar(
        4,
        285,
        one.x,
        one.y,
        one.z,
        one.heading,
        false
    )


    M.ambushTwo = entities.spawnChar(
        4,
        285,
        two.x,
        two.y,
        two.z,
        two.heading,
        false
    )


    if not M.ambushOne or not M.ambushTwo then
        return false
    end


    giveWeaponToChar(
        M.ambushOne,
        24,
        60
    )


    giveWeaponToChar(
        M.ambushTwo,
        24,
        60
    )


    taskKillCharOnFoot(
        M.ambushOne,
        PLAYER_PED
    )


    taskKillCharOnFoot(
        M.ambushTwo,
        PLAYER_PED
    )


    return true

end


--------------------------------------------------
-- MISSION START
--------------------------------------------------
function M.start()

    M.stage = 1

    --------------------------------------------------
    -- CINEMATIC OPENING
    --------------------------------------------------

    cinematic.start()

    cinematic.fadeOut(1000)

    --------------------------------------------------
    -- CAMERA 1
    -- WIDE LOS SANTOS AIRPORT SHOT
    --------------------------------------------------

    cinematic.createCamera(
        1610.0,
        -2300.0,
        28.0,

        1685.0,
        -2334.0,
        13.5
    )

    cinematic.fadeIn(1000)

    cinematic.wait(4000)

    --------------------------------------------------
    -- CAMERA 2
    -- MEETING AREA
    --------------------------------------------------

    cinematic.createCamera(
        1660.0,
        -2360.0,
        18.0,

        1685.0,
        -2334.0,
        13.5
    )

    cinematic.wait(3500)

    --------------------------------------------------
    -- CAMERA 3
    -- CLOSER SHOT
    --------------------------------------------------

    cinematic.createCamera(
        1700.0,
        -2315.0,
        16.0,

        1685.0,
        -2334.0,
        13.5
    )

    cinematic.wait(3000)

    --------------------------------------------------
    -- TITLE
    --------------------------------------------------

    printStringNow(
        'KURTLAR VADISI~n~SHADOW OF THE CITY',
        5000
    )

    cinematic.wait(4500)

    printStringNow(
        'MISSION 01~n~ARRIVAL',
        5000
    )

    cinematic.wait(4500)

    --------------------------------------------------
    -- END CINEMATIC
    --------------------------------------------------

    cinematic.fadeOut(800)

    cinematic.restoreCamera()

    cinematic.fadeIn(800)

    cinematic.stop()

    --------------------------------------------------
    -- MISSION BEGINS
    --------------------------------------------------

    printStringNow(
        'OBJECTIVE UPDATED',
        2500
    )

end


--------------------------------------------------
-- MISSION UPDATE
--------------------------------------------------

function M.update()


    --------------------------------------------------
    -- STAGE 1
    -- OPENING
    --------------------------------------------------

    if M.stage == 1 then

        dialogue.play(
            dialogueData.arrival
        )

        M.stage = 2


        objective.set(
            'GO TO THE AIRPORT MEETING POINT',
            locations.airport_meeting.x,
            locations.airport_meeting.y,
            locations.airport_meeting.z,
            locations.airport_meeting.radius
        )

        return

    end


    --------------------------------------------------
    -- STAGE 2
    -- AIRPORT ARRIVAL
    --------------------------------------------------

    if M.stage == 2 then

        if objective.reached() then

            objective.clear()

            M.stage = 3


            printStringNow(
                'OBJECTIVE UPDATED~n~FIND THE SOURCE',
                4000
            )


            if not spawnSource() then

                error(
                    'Failed to spawn source NPC'
                )

            end


            local x, y, z =
                getCharCoordinates(
                    M.source
                )


            objective.set(
                'APPROACH THE SOURCE',
                x,
                y,
                z,
                locations.source.radius
            )

        end

        return

    end


    --------------------------------------------------
    -- STAGE 3
    -- MEET THE SOURCE
    --------------------------------------------------

    if M.stage == 3 then

        if objective.reached() then

            objective.clear()

            M.stage = 4


            freezeCharPosition(
                PLAYER_PED,
                true
            )


            dialogue.play(
                dialogueData.meeting
            )


            freezeCharPosition(
                PLAYER_PED,
                false
            )

        end

        return

    end


    --------------------------------------------------
    -- STAGE 4
    -- SUSPICIOUS CAR
    --------------------------------------------------

    if M.stage == 4 then

        M.stage = 5


        printStringNow(
            'A SUSPICIOUS VEHICLE IS WATCHING THE MEETING',
            4000
        )


        if not spawnWatcherCar() then

            error(
                'Failed to spawn watcher vehicle'
            )

        end


        wait(1000)


        dialogue.play(
            dialogueData.watcher
        )

        return

    end


    --------------------------------------------------
    -- STAGE 5
    -- AMBUSH
    --------------------------------------------------

    if M.stage == 5 then

        M.stage = 6


        wait(1500)


        printStringNow(
            'AMBUSH!',
            3000
        )


        if not spawnAmbush() then

            error(
                'Failed to spawn ambush NPCs'
            )

        end


        dialogue.play(
            dialogueData.ambush
        )

        return

    end


    --------------------------------------------------
    -- STAGE 6
    -- ESCAPE
    --------------------------------------------------

    if M.stage == 6 then

        M.stage = 7


        dialogue.play(
            dialogueData.escape
        )


        objective.set(
            'ESCAPE TO THE SAFEHOUSE',
            locations.safehouse.x,
            locations.safehouse.y,
            locations.safehouse.z,
            locations.safehouse.radius
        )

        return

    end


    --------------------------------------------------
    -- STAGE 7
    -- SAFEHOUSE
    --------------------------------------------------

    if M.stage == 7 then

        if objective.reached() then

            objective.clear()

            M.stage = 8


            screenFadeOut(800)

            wait(300)

            screenFadeIn(800)


            dialogue.play(
                dialogueData.ending
            )

        end

        return

    end


    --------------------------------------------------
    -- STAGE 8
    -- COMPLETE
    --------------------------------------------------

    if M.stage == 8 then

        M.stage = 9


        printStringNow(
            'MISSION PASSED!~n~ARRIVAL',
            6000
        )


        save.complete(
            M.id,
            2
        )


        require(
            'KurtlarVadisi.systems.mission_manager'
        ).success()

        return

    end

end


--------------------------------------------------
-- SUCCESS
--------------------------------------------------

function M.success()

end


--------------------------------------------------
-- FAIL
--------------------------------------------------

function M.fail(reason)

    printStringNow(
        'MISSION FAILED~n~' ..
        (reason or 'Try Again'),
        5000
    )

end


--------------------------------------------------
-- CLEANUP
--------------------------------------------------

function M.cleanup()

    objective.clear()


    M.source = nil
    M.watcherCar = nil

    M.ambushOne = nil
    M.ambushTwo = nil

    M.stage = 0

end


return M
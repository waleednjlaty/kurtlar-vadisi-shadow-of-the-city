local M = {
    active = false
}


--------------------------------------------------
-- START CINEMATIC
--------------------------------------------------

function M.start()

    if M.active then
        return
    end

    M.active = true

    freezeCharPosition(
        PLAYER_PED,
        true
    )

end


--------------------------------------------------
-- SET CAMERA
--------------------------------------------------

function M.camera(
    camX,
    camY,
    camZ,

    lookX,
    lookY,
    lookZ,

    switchStyle
)

    switchStyle = switchStyle or 2


    setFixedCameraPosition(
        camX,
        camY,
        camZ,

        0.0,
        0.0,
        0.0
    )


    pointCameraAtPoint(
        lookX,
        lookY,
        lookZ,
        switchStyle
    )

end


--------------------------------------------------
-- WAIT
--------------------------------------------------

function M.wait(duration)

    wait(duration)

end


--------------------------------------------------
-- FADE OUT
--------------------------------------------------

function M.fadeOut(duration)

    duration = duration or 800

    doFade(
        false,
        duration
    )

    wait(duration + 100)

end


--------------------------------------------------
-- FADE IN
--------------------------------------------------

function M.fadeIn(duration)

    duration = duration or 800

    doFade(
        true,
        duration
    )

    wait(duration + 100)

end


--------------------------------------------------
-- END CINEMATIC
--------------------------------------------------

function M.stop()

    restoreCamera()

    freezeCharPosition(
        PLAYER_PED,
        false
    )

    M.active = false

end


return M
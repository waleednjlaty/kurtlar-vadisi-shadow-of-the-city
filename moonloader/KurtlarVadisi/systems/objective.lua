local entities = require 'KurtlarVadisi.systems.entity_manager'

local M = {
    current = nil
}

function M.clear()

    if M.current then

        if M.current.blip then
            entities.removeBlip(M.current.blip)
        end

        if M.current.worldMarker then
            entities.removeWorldMarker(M.current.worldMarker)
        end

    end

    M.current = nil

end

function M.set(text, x, y, z, radius)

    M.clear()

    printStringNow(
        'OBJECTIVE: ' .. text,
        5000
    )

    local blip = entities.addBlip(x, y, z, 2)

    local marker = entities.addWorldMarker(
        x,
        y,
        z + 1.0,
        0
    )

    M.current = {
        text = text,
        x = x,
        y = y,
        z = z,
        radius = radius or 5.0,
        blip = blip,
        worldMarker = marker
    }

end

function M.updateText(text)

    if not M.current then
        return
    end

    M.current.text = text

    printStringNow(
        'OBJECTIVE UPDATED: ' .. text,
        5000
    )

end

function M.reached()

    if not M.current then
        return false
    end

    local x, y, z = getCharCoordinates(PLAYER_PED)

    local dx = x - M.current.x
    local dy = y - M.current.y
    local dz = z - M.current.z

    local distanceSquared =
        dx * dx +
        dy * dy +
        dz * dz

    return distanceSquared <=
        M.current.radius * M.current.radius

end

function M.getCurrent()

    return M.current

end

return M
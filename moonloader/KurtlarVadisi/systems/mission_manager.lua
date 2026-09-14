local logger = require 'KurtlarVadisi.systems.logger'
local save = require 'KurtlarVadisi.systems.save'
local entities = require 'KurtlarVadisi.systems.entity_manager'
local audio = require 'KurtlarVadisi.systems.audio'
local runtime = require 'KurtlarVadisi.systems.runtime'
local registry = require 'KurtlarVadisi.config.missions'
local M = {missions={}, definitions={}, active=nil, state='IDLE', started=false,
    initialized=false, gameplayReady=false, markers={}, retryBlocked={}}

local function safe(label, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then logger.exception(label, err) end
    return ok
end
local function missionCompleted(d)
    return save.completed[d.id] == true or save.completed[d.progressKey] == true
end
local function prerequisitesMet(d)
    for _, id in ipairs(d.requiresCompleted or {}) do
        local done = save.completed[tostring(id)] == true
        for _, candidate in ipairs(M.definitions) do
            if candidate.id == tostring(id) and missionCompleted(candidate) then done = true end
        end
        if not done then return false end
    end
    return true
end
local function available(d)
    return not missionCompleted(d) and save.unlocked[d.id] == true and prerequisitesMet(d)
end
function M.isActive() return M.active ~= nil end
function M.getActiveId() return M.active and M.active.id or nil end
local function persist()
    if not save.commit() then logger.error('KV progress remains in memory; disk save failed') end
end
function M.initialize()
    if M.initialized or not runtime.worldReady() then return end
    save.load()
    M.definitions, M.missions = {}, {}
    for _, d in ipairs(registry) do
        assert(d.id and d.module and d.progressKey, 'Invalid mission definition')
        assert(not M.missions[d.id], 'Duplicate mission ID')
        M.definitions[#M.definitions+1], M.missions[d.id] = d, d
    end
    for _, d in ipairs(M.definitions) do
        if missionCompleted(d) or not prerequisitesMet(d) then save.setUnlocked(d.id, false)
        elseif d.id == '001' or save.unlocked[d.id] == nil then
            -- Mission 001 is the first real mission.  A stale native-save
            -- unlock=false must not hide its start marker when it is not
            -- completed and has no prerequisite.
            save.setUnlocked(d.id, true)
        end
    end
    M.initialized = true
    persist()
    logger.info('Mission registry initialized: '..#M.definitions..' real definition(s)')
end
local function clearMarkers()
    for _, marker in pairs(M.markers) do
        entities.removeBlip(marker.blip)
        entities.removeWorldMarker(marker.worldMarker)
    end
    M.markers = {}
end
function M.refreshMarkers()
    if not M.initialized or not M.gameplayReady or M.active or not runtime.worldReady() then return end
    local wanted = {}
    for _, d in ipairs(M.definitions) do
        if available(d) and d.marker then
            wanted[d.id] = d
        end
    end

    -- Reconcile instead of clearing/rebuilding every refresh.  This keeps
    -- valid handles alive and retries a transient native marker failure.
    for id, marker in pairs(M.markers) do
        if not wanted[id] then
            entities.removeBlip(marker.blip)
            entities.removeWorldMarker(marker.worldMarker)
            M.markers[id] = nil
        end
    end
    for id, d in pairs(wanted) do
        local p = d.marker
        local marker = M.markers[id]
        if not marker then
            marker = {x=p.x,y=p.y,z=p.z,radius=p.radius or 7,title=d.title,
                blip=nil,worldMarker=nil,logged=false}
            M.markers[id] = marker
        end
        if not marker.blip then marker.blip = entities.addBlip(p.x,p.y,p.z,p.colour or 2) end
        if not marker.worldMarker then marker.worldMarker = entities.addWorldMarker(p.x,p.y,p.z+1,0) end
        if not marker.logged then
            logger.info(string.format('Mission marker ready: %s at %.2f %.2f %.2f (blip=%s world=%s)',
                tostring(id), p.x, p.y, p.z, tostring(marker.blip), tostring(marker.worldMarker)))
            marker.logged = true
        end
    end
end
function M.setGameplayReady(value)
    local ready = value == true
    if ready == M.gameplayReady then return end
    M.gameplayReady = ready
    if not ready then
        if runtime.worldReady() then clearMarkers() end
    else
        local x, y, z = getCharCoordinates(PLAYER_PED)
        logger.info(string.format('Gameplay ready at %.2f %.2f %.2f', x, y, z))
        M.refreshMarkers()
    end
end
function M.start(id)
    if not M.initialized or not M.gameplayReady or M.active or not runtime.worldReady()
        or not isPlayerPlaying(PLAYER_HANDLE) or isCharInAnyCar(PLAYER_PED) then return false end
    local d = M.missions[id]
    if not d or not available(d) or M.retryBlocked[id] then return false end
    clearMarkers()
    local ok, mission = xpcall(function() return require(d.module) end, debug.traceback)
    if not ok or type(mission) ~= 'table' then
        logger.exception('Mission module '..tostring(id), mission)
        M.retryBlocked[id] = true
        M.refreshMarkers()
        return false
    end
    mission.id, mission.progressKey = d.id, d.progressKey
    local epoch = runtime.epoch
    M.active, M.state, M.started = mission, 'ACTIVE', true
    save.setActive(d.id)
    audio.setMissionActive(true)
    local started, err = xpcall(mission.start, debug.traceback)
    -- A model request may yield through New/Load. Its old mission must not
    -- fail/complete/clean up against handles belonging to the new world.
    if epoch ~= runtime.epoch or M.active ~= mission then return false end
    if not started then M.fail(err); return false end
    logger.info('Mission active: '..d.id)
    return true
end
local function fallbackCleanup()
    local operations = {
        {'radio','restoreAfterMission'}, {'dialogue','clear'}, {'audio','stop'},
        {'objective','clear'}, {'weather','stop'}, {'cinematic','restore'}
    }
    for _, entry in ipairs(operations) do
        local system = package.loaded['KurtlarVadisi.systems.'..entry[1]]
        if system and system[entry[2]] then safe('Cleanup '..entry[1], system[entry[2]]) end
    end
    entities.safeCleanup()
end
local function finish(failed)
    local mission = M.active
    if not mission or M.state == 'CLEANUP' then return end
    M.state = 'CLEANUP' -- Still active: ambient/markers must not race cleanup.
    safe('Mission cleanup', function() mission.cleanup(failed) end)
    fallbackCleanup()
    if failed then
        save.setActive(nil)
        M.retryBlocked[mission.id] = true -- Must leave the start marker before retry.
    else save.complete(mission.id, mission.progressKey) end
    M.active, M.started, M.state = nil, false, failed and 'FAILED' or 'COMPLETE'
    audio.setMissionActive(false)
    for _, d in ipairs(M.definitions) do
        if missionCompleted(d) then save.setUnlocked(d.id, false)
        elseif prerequisitesMet(d) and save.unlocked[d.id] == nil then save.setUnlocked(d.id, true) end
    end
    persist()
    M.refreshMarkers() -- Never automatically start another mission.
end
function M.fail(err)
    if not M.active then return end
    logger.exception('Mission '..tostring(M.getActiveId()), err)
    finish(true)
    if runtime.worldReady() then pcall(printStringNow, 'Mission stopped. Leave the marker and return to retry.',7000) end
end
function M.update()
    if not M.active or runtime.paused() then return end
    if not doesCharExist(PLAYER_PED) then return end -- Lifecycle callback owns unloading.
    if isCharDead(PLAYER_PED) or not isPlayerPlaying(PLAYER_HANDLE) then M.fail('Player dead or arrested'); return end
    local mission, epoch = M.active, runtime.epoch
    local ok, err = xpcall(mission.update, debug.traceback)
    if epoch ~= runtime.epoch or M.active ~= mission then return end
    if not ok then M.fail(err); return end
    if mission.done then finish(false) end
end
function M.updateMarkers()
    if not M.initialized or not M.gameplayReady or M.active or not runtime.worldReady()
        or not isPlayerPlaying(PLAYER_HANDLE) then return end
    M.refreshMarkers()
    if isCharInAnyCar(PLAYER_PED) then return end
    local x,y,z = getCharCoordinates(PLAYER_PED)
    for id,p in pairs(M.markers) do
        local distance2 = (x-p.x)^2+(y-p.y)^2+(z-p.z)^2
        if M.retryBlocked[id] then
            if distance2 > (p.radius+3)^2 then M.retryBlocked[id] = nil end
        elseif distance2 <= p.radius^2 then
            logger.info('Mission marker entered: '..tostring(id))
            M.start(id)
            return
        end
    end
end
function M.draw()
    if M.active and M.active.draw then
        local ok, err = xpcall(M.active.draw, debug.traceback)
        if not ok then M.fail(err) end
    end
end
function M.resetRuntime()
    runtime.reset()
    -- No GTA entity/camera/model opcodes in New/Load callbacks. Handles from
    -- the previous game are invalid even if a player pointer briefly exists.
    entities.reset()
    pcall(audio.stop)
    for _, name in ipairs({'player_model','radio'}) do
        local system = package.loaded['KurtlarVadisi.systems.'..name]
        if system and system.reset then system.reset() end
    end
    local camera = package.loaded['KurtlarVadisi.systems.cinematic']
    if camera then camera.active, camera.black = false, 0 end
    local objective = package.loaded['KurtlarVadisi.systems.objective']
    if objective then objective.current = nil end
    local dialogue = package.loaded['KurtlarVadisi.systems.dialogue']
    if dialogue then dialogue.clear() end
    local weather = package.loaded['KurtlarVadisi.systems.weather']
    if weather then weather.active = false end
    M.active, M.state, M.started, M.initialized, M.gameplayReady = nil,'IDLE',false,false,false
    M.markers, M.retryBlocked = {}, {}
end
function M.shutdown()
    if runtime.worldReady() then
        if M.active then safe('Shutdown mission', function() M.active.cleanup(true) end) end
        fallbackCleanup()
        clearMarkers()
    end
    M.resetRuntime()
end
return M

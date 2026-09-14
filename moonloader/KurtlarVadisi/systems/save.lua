local logger = require 'KurtlarVadisi.systems.logger'

local M = {
    version = 2,
    chapter = 1,
    mission = 1,
    currentMission = '001',
    activeMission = nil,
    lastCompletedMission = nil,
    completed = {},
    unlocked = {},
    choices = {},
    flags = {},
    initialized = false,
    lifecycleSeen = false,
    currentSlot = nil
}

local function rootPath()
    return getGameDirectory() .. '\\moonloader\\KurtlarVadisi\\data\\'
end

local function globalPath()
    return rootPath() .. 'progress.ini'
end

local function slotPath(slot)
    return rootPath() .. 'profiles\\progress_slot_' .. tostring(slot) .. '.ini'
end

local function ensureDirectories()
    if type(createDirectory) == 'function' then
        pcall(createDirectory, rootPath())
        pcall(createDirectory, rootPath() .. 'profiles\\')
    end
end

local function normalizeMissionId(value)
    if value == nil or value == '' then return nil end
    local numeric = tonumber(value)
    if numeric then return string.format('%03d', numeric) end
    return tostring(value)
end

local function clearState()
    M.version = 2
    M.chapter = 1
    M.mission = 1
    M.currentMission = '001'
    M.activeMission = nil
    M.lastCompletedMission = nil
    M.completed = {}
    M.unlocked = {}
    M.choices = {}
    M.flags = {}
end

local function readIni(path)
    local file = io.open(path, 'r')
    if not file then
        file = io.open(path .. '.bak', 'r')
        if file then logger.warn('Recovered progress from interrupted save: ' .. path) end
    end
    if not file then return false end

    clearState()
    for line in file:lines() do
        local key, value = line:match('^([^=]+)=(.*)$')
        if key == 'version' or key == 'save_version' then
            M.version = tonumber(value) or 2
        elseif key == 'chapter' then
            M.chapter = tonumber(value) or 1
        elseif key == 'mission' or key == 'current_mission' then
            M.currentMission = normalizeMissionId(value) or '001'
            M.mission = tonumber(M.currentMission) or 1
        elseif key == 'active_mission' then
            M.activeMission = normalizeMissionId(value)
        elseif key == 'last_completed_mission' or key == 'last_completed' then
            M.lastCompletedMission = normalizeMissionId(value)
        elseif key and key:match('^completed_') then
            local id = key:sub(11)
            M.completed[id] = value == '1'
            if value == '1' then
                local missionId = normalizeMissionId(id:match('^(%d%d%d)'))
                if missionId then M.completed[missionId] = true end
            end
        elseif key and key:match('^unlocked_') then
            M.unlocked[normalizeMissionId(key:sub(10)) or key:sub(10)] = value == '1'
        elseif key and key:match('^choice_') then
            M.choices[key:sub(8)] = value
        elseif key and key:match('^flag_') then
            M.flags[key:sub(6)] = value == '1'
        end
    end
    file:close()
    M.mission = tonumber(M.currentMission) or 1
    return true
end

local function writeIni(path)
    ensureDirectories()
    local temporary = path .. '.tmp'
    local backup = path .. '.bak'
    local file = io.open(temporary, 'w')
    if not file then
        logger.error('Could not open temporary save: ' .. path)
        return false
    end

    file:write('save_version=' .. tostring(M.version) .. '\n')
    file:write('chapter=' .. tostring(M.chapter) .. '\n')
    file:write('mission=' .. tostring(tonumber(M.currentMission) or 1) .. '\n')
    file:write('current_mission=' .. tostring(M.currentMission or '') .. '\n')
    file:write('active_mission=' .. tostring(M.activeMission or '') .. '\n')
    file:write('last_completed_mission=' .. tostring(M.lastCompletedMission or '') .. '\n')

    for id, done in pairs(M.completed) do
        if type(done) == 'boolean' then
            file:write('completed_' .. tostring(id) .. '=' .. (done and '1' or '0') .. '\n')
        end
    end
    for id, unlocked in pairs(M.unlocked) do
        file:write('unlocked_' .. tostring(id) .. '=' .. (unlocked and '1' or '0') .. '\n')
    end
    for id, value in pairs(M.choices) do
        file:write('choice_' .. tostring(id) .. '=' .. tostring(value) .. '\n')
    end
    for id, value in pairs(M.flags) do
        file:write('flag_' .. tostring(id) .. '=' .. (value and '1' or '0') .. '\n')
    end
    file:close()

    local prior = io.open(path, 'r')
    local hadPrevious = prior ~= nil
    if prior then
        prior:close()
        os.remove(backup)
        if not os.rename(path, backup) then
            os.remove(temporary)
            logger.error('Could not protect previous save; refusing replacement')
            return false
        end
    end
    if not os.rename(temporary, path) then
        if hadPrevious then os.rename(backup, path) end
        logger.error('Could not finalize save; previous progress restored')
        return false
    end
    os.remove(backup) -- Also clear a recovered backup only after replacement succeeds.
    return true
end

local function copyMap(source)
    local result = {}
    if type(source) ~= 'table' then return result end
    for key, value in pairs(source) do
        if type(key) == 'string' and (type(value) == 'boolean' or type(value) == 'string' or type(value) == 'number') then
            result[key] = value
        end
    end
    return result
end

function M.snapshot()
    return {
        saveVersion = M.version,
        chapter = M.chapter,
        currentMission = M.currentMission,
        activeMission = M.activeMission,
        lastCompletedMission = M.lastCompletedMission,
        completed = copyMap(M.completed),
        unlocked = copyMap(M.unlocked),
        choices = copyMap(M.choices),
        flags = copyMap(M.flags)
    }
end

function M.applySnapshot(data)
    if type(data) ~= 'table' or tonumber(data.saveVersion or data.version) ~= 2
        or type(data.completed) ~= 'table' or type(data.unlocked) ~= 'table' then return false end
    clearState()
    M.version = tonumber(data.saveVersion or data.version) or 2
    M.chapter = tonumber(data.chapter) or 1
    M.currentMission = normalizeMissionId(data.currentMission or data.mission) or '001'
    M.mission = tonumber(M.currentMission) or 1
    M.activeMission = nil -- Live mission entities/tasks cannot be resumed from a save.
    M.lastCompletedMission = normalizeMissionId(data.lastCompletedMission or data.lastCompleted)
    M.completed = copyMap(data.completed)
    M.unlocked = copyMap(data.unlocked)
    M.choices = copyMap(data.choices)
    M.flags = copyMap(data.flags)
    return true
end

function M.commit(path)
    return writeIni(path or (M.currentSlot and slotPath(M.currentSlot) or globalPath()))
end

function M.load()
    if M.initialized then return M end
    ensureDirectories()
    if not readIni(globalPath()) then clearState() end
    M.activeMission = nil
    M.initialized = true
    logger.info('Progress bootstrap loaded: mission ' .. tostring(M.currentMission))
    return M
end

local function slotFromValue(key, value)
    local keyText = tostring(key):lower()
    if type(value) == 'number' and keyText:find('slot', 1, true) and value >= 1 and value <= 8 then
        return tostring(math.floor(value))
    end
    if type(value) == 'string' then
        local slot = value:match('[Gg][Tt][Aa][Ss][Aa][Ss][Ff](%d+)')
        if not slot and keyText:find('slot', 1, true) then slot = value:match('(%d+)') end
        if slot and tonumber(slot) and tonumber(slot) >= 1 and tonumber(slot) <= 8 then
            return tostring(tonumber(slot))
        end
    end
    return nil
end

function M.extractSlot(saveData)
    if type(saveData) ~= 'table' then return nil end
    for key, value in pairs(saveData) do
        local slot = slotFromValue(key, value)
        if slot then return slot end
    end
    return nil
end

function M.newGame()
    clearState()
    M.initialized = true
    M.lifecycleSeen = true
    M.currentSlot = nil
    M.commit(globalPath())
    logger.info('New Game: Kurtlar Vadisi progress reset')
end

function M.onSaveGame(saveData)
    M.load()
    local slot = M.extractSlot(saveData)
    M.currentSlot = slot
    M.commit()

    if type(saveData) == 'table' and type(encodeJson) == 'function' then
        local ok, payload = pcall(encodeJson, M.snapshot())
        if ok and type(payload) == 'string' then
            -- MoonLoader's save callback persists this script-owned payload with
            -- the native save. It takes precedence over any sidecar on load.
            saveData.kurtlarVadisiProfileVersion = M.version
            saveData.kurtlarVadisiProfile = payload
        end
    end
    if type(saveData) ~= 'table' or type(saveData.kurtlarVadisiProfile) ~= 'string' then
        logger.warn('Native KV save payload unavailable; only local recovery progress was written')
    end
    M.lifecycleSeen = true
    logger.info('Save Game: progress written' .. (slot and (' for slot ' .. slot) or ' to fallback profile'))
    return saveData
end

function M.onLoadGame(saveData)
    M.load()
    local slot = M.extractSlot(saveData)
    M.currentSlot = slot
    local loaded = false

    if type(saveData) == 'table' and type(saveData.kurtlarVadisiProfile) == 'string'
        and type(decodeJson) == 'function' then
        local ok, data = pcall(decodeJson, saveData.kurtlarVadisiProfile)
        loaded = ok and M.applySnapshot(data)
    end

    if not loaded and slot then loaded = readIni(slotPath(slot)) end
    -- Never import another playthrough's global progress on a native Load Game.
    if not loaded then
        clearState()
        if slot then
            logger.info('Load Game: no Kurtlar Vadisi profile for slot ' .. slot .. '; using new profile')
        else
            logger.warn('Load Game: MoonLoader saveData exposed no slot/profile; using isolated default profile')
        end
    end

    M.activeMission = nil
    M.initialized = true
    M.lifecycleSeen = true
    logger.info('Load Game: progress restored for ' .. (slot and ('slot ' .. slot) or 'event payload/default'))
end

function M.setActive(id)
    M.activeMission = normalizeMissionId(id)
    M.currentMission = M.activeMission or M.currentMission
    M.mission = tonumber(M.currentMission) or 1
    return M.commit()
end

function M.complete(id, progressKey)
    local missionId = normalizeMissionId(id) or tostring(id)
    M.completed[missionId] = true
    if progressKey then M.completed[progressKey] = true end
    M.lastCompletedMission = missionId
    M.activeMission = nil
    M.currentMission = missionId
    M.mission = tonumber(missionId) or M.mission
    return M.commit()
end

function M.setUnlocked(id, value)
    M.unlocked[normalizeMissionId(id) or tostring(id)] = value == true
end

return M

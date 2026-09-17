script_name('Polat Alemdar Player')
script_author('KurtlarVadisi project')
script_version('0.2.0')

-- Uses the stock MAFBOSS slot through ModLoader. No CJ clothing files are replaced.
local POLAT_MODEL = 113
local pendingModel = nil
-- SA 1.0 US CPlayerPed::ProcessAnimGroups resets the player walk group.
-- Temporarily suppress just its six-byte assignment while Polat is active.
-- Never patch a different executable or another mod's hook; never write GTA_SA.EXE.
local GROUP_ASSIGN = 0x609A4E
local originalAssignment = {0x89, 0x86, 0xD4, 0x04, 0x00, 0x00}
local nopAssignment = {0x90, 0x90, 0x90, 0x90, 0x90, 0x90}
local postureOwned, postureUnsupported, posturePed = false, false, nil
local function matches(address, bytes)
    for i, b in ipairs(bytes) do
        if readMemory(address + i - 1, 1, false) ~= b then return false end
    end
    return true
end
local function writeBytes(address, bytes)
    for i, b in ipairs(bytes) do writeMemory(address + i - 1, 1, b, true) end
end
local function restorePosture(shuttingDown)
    if not postureOwned then return end
    if matches(GROUP_ASSIGN, nopAssignment) then
        writeBytes(GROUP_ASSIGN, originalAssignment)
        -- During shutdown the SCM engine may already be destroyed. Do not issue opcodes.
        if not shuttingDown and doesCharExist(PLAYER_PED) then setAnimGroupForChar(PLAYER_PED, 'PLAYER') end
        print('[Polat] Original player posture restored.')
    else
        print('[Polat] Posture bytes changed externally; left untouched.')
    end
    postureOwned, posturePed = false, nil
end
local function applyPosture()
    if postureUnsupported then return end
    if not postureOwned then
        if not matches(GROUP_ASSIGN, originalAssignment)
            or not matches(GROUP_ASSIGN + 6, {0xE8, 0xF7, 0xFB, 0xFF, 0xFF}) then
            postureUnsupported = true
            print('[Polat] Upright posture unavailable: executable bytes differ or another mod owns this hook.')
            return
        end
        writeBytes(GROUP_ASSIGN, nopAssignment)
        postureOwned = true
    end
    if posturePed ~= PLAYER_PED then
        setAnimGroupForChar(PLAYER_PED, 'MAN')
        posturePed = PLAYER_PED
        print('[Polat] Upright native MAN stance enabled.')
    end
end

local function notify(message)
    print('[Polat] ' .. message)
    printStringNow(message, 2500)
end

local function ready()
    return isPlayerPlaying(PLAYER_HANDLE) and doesCharExist(PLAYER_PED)
        and not isCharDead(PLAYER_PED) and not isGamePaused()
end

local function release()
    if pendingModel ~= nil then
        markModelAsNoLongerNeeded(pendingModel)
        pendingModel = nil
    end
end

local function switchModel(model)
    if not ready() then return end
    if not isPlayerControlOn(PLAYER_HANDLE) or isCharInAnyCar(PLAYER_PED)
        or isCharSwimming(PLAYER_PED) or isCharInAir(PLAYER_PED) then
        notify('Stand on foot before changing skin')
        return
    end
    if getCharModel(PLAYER_PED) == model then
        notify(model == 0 and 'CJ already active' or 'Polat already active')
        return
    end
    pendingModel = model
    requestModel(model)
    loadAllModelsNow()
    local started = getGameTimer()
    while not hasModelLoaded(model) do
        wait(0)
        if not ready() or getGameTimer() - started > 10000 then
            release()
            notify('Skin loading failed - see moonloader.log')
            return
        end
    end
    if not ready() or isCharInAnyCar(PLAYER_PED) or not isPlayerControlOn(PLAYER_HANDLE) then
        release()
        return
    end
    setPlayerModel(PLAYER_HANDLE, model)
    if model == 0 then buildPlayerModel(PLAYER_HANDLE) end
    if model == POLAT_MODEL then applyPosture() else restorePosture() end
    release()
    wait(0)
    if ready() and getCharModel(PLAYER_PED) == model then
        notify(model == 0 and 'CJ restored' or 'Polat Alemdar activated')
    else
        notify('Skin verification failed - see moonloader.log')
    end
end

function main()
    print('[Polat] Loaded. F5 = Polat with upright stance; F6 = CJ. Model slot 113.')
    while true do
        wait(0)
        if isPlayerPlaying(PLAYER_HANDLE) and doesCharExist(PLAYER_PED)
            and not isCharDead(PLAYER_PED) and getCharModel(PLAYER_PED) == POLAT_MODEL then
            applyPosture()
        else
            restorePosture()
        end
        if ready() then
            if isKeyJustPressed(0x74) then switchModel(POLAT_MODEL) end
            if isKeyJustPressed(0x75) then switchModel(0) end
        end
    end
end

function onExitScript()
    restorePosture(true)
    pendingModel = nil -- Streaming is released by the engine at shutdown.
end

script_name('Polat development validation')
local index, car, start = 0, nil, nil
local function say(s) print('[KV TEST] '..s);printStringNow(s,4000) end
local function load(id)
    requestModel(id);loadAllModelsNow()
    local t=getGameTimer()
    while not hasModelLoaded(id) do
        wait(0)
        if getGameTimer()-t>10000 then markModelAsNoLongerNeeded(id);error('Model load timeout: '..id) end
    end
end
local function weapon(id,model)
    load(model);giveWeaponToChar(PLAYER_PED,id,100);setCurrentCharWeapon(PLAYER_PED,id);markModelAsNoLongerNeeded(model)
    say('Weapon '..id..' equipped; model '..getCharModel(PLAYER_PED))
end
local steps={
    function() start={getCharCoordinates(PLAYER_PED)};say('Standing - model '..getCharModel(PLAYER_PED)) end,
    function() local x,y,z=getCharCoordinates(PLAYER_PED);taskGoStraightToCoord(PLAYER_PED,x,y+8,z,4,15000);say('Walking') end,
    function() local x,y,z=getCharCoordinates(PLAYER_PED);clearCharTasks(PLAYER_PED);taskGoStraightToCoord(PLAYER_PED,x,y-12,z,6,15000);say('Running') end,
    function() clearCharTasks(PLAYER_PED);taskJump(PLAYER_PED,true);say('Jump') end,
    function() weapon(22,346) end,
    function() weapon(30,355) end,
    function() weapon(25,349) end,
    function() weapon(4,335) end,
    function()
        clearCharTasks(PLAYER_PED);setCurrentCharWeapon(PLAYER_PED,0)
        local x,y,z=getCharCoordinates(PLAYER_PED);load(400);car=createCar(400,x+3,y,z);markModelAsNoLongerNeeded(400)
        taskEnterCarAsDriver(PLAYER_PED,car,15000);say('Entering validation car')
    end,
    function() assert(car and isCharInAnyCar(PLAYER_PED),'Player has not entered car');setCarForwardSpeed(car,5);say('Driving') end,
    function() assert(car);setCarForwardSpeed(car,0);taskLeaveCar(PLAYER_PED,car);say('Leaving car') end,
    function()
        assert(not isCharInAnyCar(PLAYER_PED),'Wait until out of car')
        clearCharTasks(PLAYER_PED);local h=getWaterHeightAtCoords(700,-2300,true)
        setCharCoordinates(PLAYER_PED,700,-2300,h);say('Swimming - verify in water')
    end,
    function()
        print('[KV TEST] Swimming flag: '..tostring(isCharSwimming(PLAYER_PED)))
        if start then setCharCoordinates(PLAYER_PED,start[1],start[2],start[3]) end
        clearCharTasks(PLAYER_PED);say('Returned to start - test F6 now')
    end
}
function main()
    say('Validation loaded: F7 advances one test; do not save this test session')
    while true do
        wait(0)
        if isPlayerPlaying(PLAYER_HANDLE) and doesCharExist(PLAYER_PED) and not isGamePaused() and isKeyJustPressed(0x76) then
            if index<#steps then
                local ok,err=pcall(steps[index+1])
                if ok then index=index+1;print('[KV TEST] Step '..index..' dispatched') else say('Test error: '..tostring(err)) end
            else say('Sequence complete; inspect logs and restore CJ') end
        end
    end
end

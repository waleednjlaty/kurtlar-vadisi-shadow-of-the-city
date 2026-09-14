-- Contract tests run on the game's actual Lua runtime, using simulated engine APIs.
-- These do not constitute in-game animation or visual tests.
local model, requested, released, key, timer, inCar, canLoad = 0, nil, {}, nil, 0, false, true
local messages, changes = {}, {}
PLAYER_HANDLE, PLAYER_PED = 0, 1
function script_name() end
function script_author() end
function script_version() end
function isPlayerPlaying() return true end
function doesCharExist() return true end
function isCharDead() return false end
function isGamePaused() return false end
function isPlayerControlOn() return true end
function isCharInAnyCar() return inCar end
function isCharSwimming() return false end
function isCharInAir() return false end
function getCharModel() return model end
function requestModel(m) requested=m end
function loadAllModelsNow() end
function hasModelLoaded(m) return canLoad and requested==m end
function getGameTimer() return timer end
function setPlayerModel(p,m) assert(hasModelLoaded(m));model=m;changes[#changes+1]=m end
function buildPlayerModel() assert(model==0) end
function markModelAsNoLongerNeeded(m) released[#released+1]=m;requested=nil end
function printStringNow(m) messages[#messages+1]=m end
function isKeyJustPressed(k) if key==k then key=nil;return true end return false end
function wait() coroutine.yield() end
dofile('KurtlarVadisi/staging/moonloader/polat_player.lua')
local thread=coroutine.create(main)
local function step(n) for i=1,n do timer=timer+100;assert(coroutine.resume(thread)) end end
step(1);key=0x74;step(3);assert(model==113 and requested==nil and released[#released]==113)
assert(messages[#messages]=='Polat Alemdar activated')
key=0x75;step(3);assert(model==0 and requested==nil and messages[#messages]=='CJ restored')
inCar=true;key=0x74;step(3);assert(model==0 and #changes==2);inCar=false
canLoad=false;key=0x74;step(105);assert(model==0 and requested==nil and #changes==2)
canLoad=true;key=0x74;step(3);assert(model==113)
key=0x74;step(3);assert(#changes==3)
onExitScript();assert(requested==nil)
print('PASS: F5, F6, model loaded before switch, release, vehicle guard, timeout, repeat key, cleanup')

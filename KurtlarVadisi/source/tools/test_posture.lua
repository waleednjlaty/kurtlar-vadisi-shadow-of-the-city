-- Run with the game's Lua 5.1 DLL. Simulated API checks, not in-game visual proof.
local memory, writes, group, model, key = {},0,'PLAYER',0,nil
local original={0x89,0x86,0xD4,0x04,0,0,0xE8,0xF7,0xFB,0xFF,0xFF}
for i,v in ipairs(original) do memory[0x609A4E+i-1]=v end
function readMemory(a,s,p) assert(s==1);return memory[a] end
function writeMemory(a,s,v,p) assert(s==1 and p);memory[a]=v;writes=writes+1 end
function setAnimGroupForChar(p,g) group=g end
function script_name() end
function script_author() end
function script_version() end
PLAYER_HANDLE,PLAYER_PED=0,1
local playing,dead,inCar,canLoad,timer=true,false,false,true,0
local pending,releases=nil,0
function isPlayerPlaying() return playing end
function doesCharExist() return playing end
function isCharDead() return dead end
function isGamePaused() return false end
function isPlayerControlOn() return true end
function isCharInAnyCar() return inCar end
function isCharSwimming() return false end
function isCharInAir() return false end
function getCharModel() return model end
function requestModel(m) pending=m end
function loadAllModelsNow() end
function hasModelLoaded(m) return canLoad and pending==m end
function getGameTimer() return timer end
function setPlayerModel(p,m) assert(hasModelLoaded(m));model=m end
function buildPlayerModel() assert(model==0) end
function markModelAsNoLongerNeeded(m) assert(pending==m);pending=nil;releases=releases+1 end
function printStringNow() end
function isKeyJustPressed(k) if k==key then key=nil;return true end;return false end
function wait() coroutine.yield() end
local function start()
    dofile('modloader/KurtlarVadisi/moonloader/polat_player.lua')
    local co=coroutine.create(main)
    return function(n) for i=1,n do timer=timer+100;assert(coroutine.resume(co)) end end
end
local step=start();step(1);key=0x74;step(3)
assert(model==113 and group=='MAN' and writes==6 and pending==nil)
step(20);assert(writes==6)
key=0x75;step(3);assert(model==0 and group=='PLAYER' and writes==12)
for i,v in ipairs(original) do assert(memory[0x609A4E+i-1]==v) end
inCar=true;key=0x74;step(3);assert(model==0 and writes==12);inCar=false
canLoad=false;key=0x74;step(105);assert(model==0 and pending==nil and writes==12)
canLoad=true;key=0x74;step(3);dead=true;step(3);assert(group=='PLAYER' and writes==24)
dead=false;step(3);assert(group=='MAN' and writes==30)
onExitScript();assert(writes==36 and group=='PLAYER')
-- A new script instance refuses a foreign patch without changing it.
memory[0x609A4E]=0xE9;model=113;local before=writes;step=start();step(3)
assert(writes==before and memory[0x609A4E]==0xE9);onExitScript();assert(writes==before)
-- If another mod changes our patch afterwards, cleanup must not overwrite it.
memory[0x609A4E]=original[1];step=start();step(3);assert(group=='MAN')
memory[0x609A4E]=0xE9;before=writes;onExitScript();assert(writes==before)
print('PASS: F5/F6, native stance, exact-byte restoration, no repeated writes, loading timeout, vehicle guard, death, unload, and hook-conflict protection.')

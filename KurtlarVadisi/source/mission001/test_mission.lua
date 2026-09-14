package.path=package.path..';moonloader/?.lua'
local t,model,nextId=0,0,10
local cars,chars,driver,seat={},{},{},{}
PLAYER_HANDLE,PLAYER_PED=0,1;chars[1]={x=0,y=0,z=10}
function getGameTimer() return t end
function wait() end
function requestModel() end
function hasModelLoaded() return true end
function markModelAsNoLongerNeeded() end
function loadAllModelsNow() end
function requestAnimation() end
function removeAnimation() end
function hasAnimationLoaded() return true end
function getCharModel() return model end
function setPlayerModel(p,m) model=m end
function getCharCoordinates(h) local p=seat[h] and cars[seat[h]] or chars[h];return p.x,p.y,p.z end
function setCharCoordinates(h,x,y,z) chars[h]={x=x,y=y,z=z} end
function requestCollision() end
function loadScene() end
function getGroundZFor3dCoord() return 16 end
function setCurrentCharWeapon() end
function createCar(m,x,y,z) nextId=nextId+1;cars[nextId]={x=x,y=y,z=z};return nextId end
function createChar(k,m,x,y,z) nextId=nextId+1;chars[nextId]={x=x,y=y,z=z};return nextId end
function createCharInsideCar(car,k,m) local h=createChar(k,m,0,0,0);seat[h]=car;driver[car]=h;return h end
function createCharAsPassenger(car,k,m,s) local h=createChar(k,m,0,0,0);seat[h]=car;return h end
function doesVehicleExist(h) return cars[h]~=nil end
function doesCharExist(h) return chars[h]~=nil end
function isCarDead() return false end
function isCharInAnyCar(h) return seat[h]~=nil end
function isCharInCar(h,c) return seat[h]==c end
function warpCharIntoCarAsPassenger(h,c,s) seat[h]=c end
function getDriverOfCar(c) return driver[c] end
function taskLeaveCar(h,c) local p=cars[c];chars[h]={x=p.x+2,y=p.y,z=p.z};seat[h]=nil;if driver[c]==h then driver[c]=nil end end
function taskEnterCarAsDriver(h,c) seat[h]=c;driver[c]=h end
function taskEnterCarAsPassenger(h,c,time,s) seat[h]=c end
function carGotoCoordinates(c,x,y,z) cars[c]={x=x,y=y,z=z} end
function getCarCoordinates(c) local p=cars[c];return p.x,p.y,p.z end
function setCarHeading() end
function setCharHeading() end
function setCarHealth() end
function changeCarColour() end
function setCarProofs() end
function setCharProofs() end
function setCarDrivingStyle() end
function setCarCruiseSpeed() end
function setCarForwardSpeed() end
function clearCharTasks() end
function taskGoStraightToCoord() end
function taskLookAtChar() end
function taskPlayAnim() end
function markCarAsNoLongerNeeded() end
function deleteCar(h) cars[h]=nil end
function deleteChar(h) chars[h]=nil;seat[h]=nil end
local stopped,restored,weatherStopped,marker=false,false,false,false
package.loaded['KurtlarVadisi.systems.audio']={path=function()end,start=function()end,stop=function()stopped=true end,fadeOut=function()end}
package.loaded['KurtlarVadisi.systems.cinematic']={begin=function()end,restore=function()restored=true end,shot=function()end,carShot=function()end,draw=function()end}
package.loaded['KurtlarVadisi.systems.dialogue']={load=function()end,show=function()end,clear=function()end,draw=function()end}
package.loaded['KurtlarVadisi.systems.weather']={start=function()end,update=function()end,stop=function()weatherStopped=true end}
package.loaded['KurtlarVadisi.systems.logger']={info=function()end,error=function()end}
package.loaded['KurtlarVadisi.systems.objective']={set=function()marker=true end,clear=function()marker=false end}
local m=require 'KurtlarVadisi.missions.mission_001_night_return'
m.start();local seen={};local reachedDrive=false
for i=1,250 do
 t=t+1000;m.update();seen[m.state]=true
 if m.state=='DRIVE_TO_BASE' then
  assert(model==113 and driver[m.car]==PLAYER_PED,'Player must be Polat driving')
  assert(seat[m.memati]==m.car and seat[m.abdulhey]==m.car and marker)
  reachedDrive=true;local p=require('KurtlarVadisi.config.locations').headquarters;cars[m.car]={x=p.x,y=p.y,z=p.z}
 end
 if m.done then break end
end
assert(reachedDrive and m.done and seen.MISSION_COMPLETE)
for _,s in ipairs({'CAR_CINEMATIC','CAR_DIALOGUE','RESTAURANT_ARRIVAL','ENVELOPE_CUTSCENE','PLAYER_CONTROL','DRIVE_TO_BASE','BASE_CUTSCENE'}) do assert(seen[s],s) end
m.cleanup(false);assert(stopped and restored and weatherStopped and not marker)
assert(chars[PLAYER_PED] and not chars[m.memati] and not chars[m.abdulhey] and not chars[m.messenger])
assert(cars[m.car],'Completed BMW should be released, not deleted')
print('PASS state progression, unique player, seats, objective, companion cleanup, retained BMW, camera/weather/audio cleanup. Simulated engine only.')

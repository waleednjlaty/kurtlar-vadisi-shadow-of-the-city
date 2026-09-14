local M={active=false,hour=12,minute=0}
function M.start() M.hour,M.minute=getTimeOfDay();M.active=true;forceWeatherNow(8);setTimeOfDay(2,0);clearWantedLevel(PLAYER_HANDLE) end
function M.update()
 if not M.active then return end
 setTimeOfDay(2,0);forceWeatherNow(8);clearWantedLevel(PLAYER_HANDLE)
 setCarDensityMultiplier(0.12);setPedDensityMultiplier(0.20)
end
function M.stop()
 if not M.active then return end
 M.active=false
 pcall(releaseWeather);pcall(setTimeOfDay,M.hour,M.minute)
 pcall(setCarDensityMultiplier,1);pcall(setPedDensityMultiplier,1)
end
return M

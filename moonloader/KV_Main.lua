script_name("Kurtlar Vadisi: Vadi'nin Golgesi")
script_author('KurtlarVadisi project')
script_version('1.1.0-stability')
package.path=package.path..';'..getGameDirectory()..'\\moonloader\\?.lua'
local audio=require 'KurtlarVadisi.systems.audio'
local save=require 'KurtlarVadisi.systems.save'
local manager=require 'KurtlarVadisi.systems.mission_manager'
function main() require('KurtlarVadisi.main').run() end

function onStartNewGame(missionPackNumber)
 manager.resetRuntime()
 save.newGame()
end

function onSaveGame(saveData)
 return save.onSaveGame(saveData)
end

function onLoadGame(saveData)
 manager.resetRuntime()
 save.onLoadGame(saveData)
end

function onExitScript(quitGame)
 if not quitGame then manager.shutdown() end
 pcall(audio.stop)
end

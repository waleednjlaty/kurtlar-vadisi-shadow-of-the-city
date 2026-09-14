local audio=require 'KurtlarVadisi.systems.audio'
local M={current=nil,untilTime=0,textures={}}
function M.load()
 if next(M.textures) then return end
 for _,id in ipairs({'title','memati_001','polat_001','envelope','wolves','objective','complete'}) do
  local p=getGameDirectory()..'\\moonloader\\KurtlarVadisi\\ui\\'..id..'.png'
  local h=renderLoadTextureFromFile(p);assert(h and h~=0,'UI texture failed: '..p);M.textures[id]=h
 end
end
function M.show(id,duration,voice)
 assert(M.textures[id],'Unknown dialogue card '..id)
 M.current=id;M.untilTime=getGameTimer()+(duration or 5000);audio.dialogueVoice(voice)
end
function M.clear() M.current=nil end
function M.draw()
 if not M.current then return end
 if getGameTimer()>M.untilTime then M.clear();return end
 local w,h=getScreenResolution();local id=M.current
 if id=='envelope' then
  local ph=h*.72;local pw=ph*.8;renderDrawTexture(M.textures[id],(w-pw)/2,(h-ph)/2,pw,ph,0,0xFFFFFFFF)
 elseif id=='title' or id=='complete' then renderDrawTexture(M.textures[id],w*.1,h*.32,w*.8,h*.32,0,0xFFFFFFFF)
 else renderDrawTexture(M.textures[id],w*.06,h*.72,w*.88,h*.19,0,0xFFFFFFFF) end
end
function M.dispose() for _,h in pairs(M.textures) do renderReleaseTexture(h) end;M.textures={};M.clear() end
return M

local log=require 'KurtlarVadisi.systems.logger'
local save=require 'KurtlarVadisi.systems.save'
local E=require 'KurtlarVadisi.systems.entity_manager'
local M={missions={},active=nil,state='IDLE',started=false}
function M.register(m) assert(m.id=='001','This build supports Mission 001 only');M.missions[m.id]=m end
function M.start(id)
 if M.active then return false end
 local m=assert(M.missions[id]);if save.completed[m.progressKey] then return false end
 E.reset();M.active=m;M.state='ACTIVE';M.started=true
 local ok,err=xpcall(m.start,debug.traceback)
 if not ok then M.fail(err);return false end
 return true
end
function M.cleanup(failed)
 local m=M.active;M.active=nil;M.state=failed and 'FAILED' or 'COMPLETE'
 if m then local ok,err=xpcall(function() m.cleanup(failed) end,debug.traceback);if not ok then log.exception('Cleanup',err) end end
end
function M.fail(err)
 log.exception('Mission 001',err);M.cleanup(true)
 printStringNow('Mission stopped safely. See moonloader.log. Press K to retry.',7000)
end
function M.update()
 if not M.active then return end
 if not doesCharExist(PLAYER_PED) or isCharDead(PLAYER_PED) then M.fail('Player unavailable');return end
 local ok,err=xpcall(M.active.update,debug.traceback)
 if not ok then M.fail(err);return end
 if M.active and M.active.done then
  save.complete(M.active.progressKey);M.cleanup(false)
 end
end
function M.draw() if M.active then M.active.draw() end end
return M

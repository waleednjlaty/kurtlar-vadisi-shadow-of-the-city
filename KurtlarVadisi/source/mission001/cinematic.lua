local M={active=false,black=0}
function M.begin() M.active=true;setPlayerControl(PLAYER_HANDLE,false);M.black=1 end
function M.shot(x,y,z,lx,ly,lz)
 setFixedCameraPosition(x,y,z,0,0,0);pointCameraAtPoint(lx,ly,lz,2)
end
function M.carShot(car,index)
 local offsets={{-16,-24,9},{0,11,2.0},{-7,0,2.3},{2.3,-0.7,1.1}}
 local o=offsets[index];local x,y,z=getOffsetFromCarInWorldCoords(car,o[1],o[2],o[3])
 local lx,ly,lz=getOffsetFromCarInWorldCoords(car,0,-0.4,0.6);M.shot(x,y,z,lx,ly,lz)
end
function M.restore() restoreCameraJumpcut();setPlayerControl(PLAYER_HANDLE,true);M.active=false;M.black=0 end
function M.draw()
 local w,h=getScreenResolution()
 if M.active then renderDrawBox(0,0,w,h*.095,0xFF000000);renderDrawBox(0,h*.905,w,h*.095,0xFF000000) end
 if M.black>0 then renderDrawBox(0,0,w,h,math.floor(math.min(1,M.black)*255)*0x1000000) end
end
return M

local ffi=require 'ffi'
ffi.cdef[[
int __stdcall BASS_Init(int,unsigned long,unsigned long,void*,void*);
unsigned long __stdcall BASS_StreamCreateFile(int,const char*,unsigned long long,unsigned long long,unsigned long);
unsigned long __stdcall BASS_PluginLoad(const char*,unsigned long);
unsigned long __stdcall BASS_ChannelGetData(unsigned long,void*,unsigned long);
int __stdcall BASS_ErrorGetCode(void);
int __stdcall BASS_StreamFree(unsigned long);
int __stdcall BASS_Free(void);
]]
local b=ffi.load('bass');assert(b.BASS_Init(0,44100,0,nil,nil)~=0)
local path='temp/miss1.m4a'
local h=b.BASS_StreamCreateFile(0,path,0,0,0x200000)
print('Direct M4A decode handle',h,'error',b.BASS_ErrorGetCode())
if h==0 then
 local p=b.BASS_PluginLoad('KurtlarVadisi/source/tools/bass_aac24/bass_aac.dll',0)
 print('AAC plugin',p,'error',b.BASS_ErrorGetCode());assert(p~=0)
 h=b.BASS_StreamCreateFile(0,path,0,0,0x200000)
end
assert(h~=0,'M4A decode failed: '..b.BASS_ErrorGetCode())
local buffer=ffi.new('unsigned char[16384]');local count=b.BASS_ChannelGetData(h,buffer,16384)
assert(count>0 and count<0xFFFFFFFF);print('PASS M4A decoded bytes',count)
b.BASS_StreamFree(h);b.BASS_Free()

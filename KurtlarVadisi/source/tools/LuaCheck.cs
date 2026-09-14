using System;
using System.Runtime.InteropServices;
class LuaCheck {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] static extern bool SetDllDirectory(string path);
    [DllImport("lua51.dll", CallingConvention=CallingConvention.Cdecl)] static extern IntPtr luaL_newstate();
    [DllImport("lua51.dll", CallingConvention=CallingConvention.Cdecl)] static extern void luaL_openlibs(IntPtr state);
    [DllImport("lua51.dll", CallingConvention=CallingConvention.Cdecl, CharSet=CharSet.Ansi)] static extern int luaL_loadfile(IntPtr state,string path);
    [DllImport("lua51.dll", CallingConvention=CallingConvention.Cdecl)] static extern int lua_pcall(IntPtr state,int args,int results,int error);
    [DllImport("lua51.dll", CallingConvention=CallingConvention.Cdecl)] static extern IntPtr lua_tolstring(IntPtr state,int index,IntPtr size);
    [DllImport("lua51.dll", CallingConvention=CallingConvention.Cdecl)] static extern void lua_close(IntPtr state);
    static int Main(string[] args) {
        SetDllDirectory(Environment.CurrentDirectory);
        IntPtr state=luaL_newstate();luaL_openlibs(state);
        int result=luaL_loadfile(state,args[0]);
        if(result==0 && args.Length>1 && args[1]=="--run") result=lua_pcall(state,0,-1,0);
        if(result!=0) Console.Error.WriteLine(Marshal.PtrToStringAnsi(lua_tolstring(state,-1,IntPtr.Zero)));
        else Console.WriteLine("Lua validation passed: "+args[0]);
        lua_close(state);return result;
    }
}

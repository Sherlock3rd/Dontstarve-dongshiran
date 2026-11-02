"""Isolated Lua 5.1 metadata and key-dispatch regression checks; not engine acceptance."""
from pathlib import Path
import json
from lupa.lua51 import LuaRuntime

dest = Path(__file__).resolve().parents[1]
info = dest / "modinfo.lua"
main = dest / "modmain.lua"

lua = LuaRuntime(register_eval=False, register_builtins=False, max_memory=32*1024*1024)
lua.execute('python=nil; io=nil; os=nil; package=nil; dofile=nil; loadfile=nil')
compile_lua = lua.eval('function(s,n) return assert(loadstring(s,n)) end')
for p in dest.rglob('*.lua'):
    compile_lua(p.read_text(encoding='utf-8-sig'), '@'+p.relative_to(dest).as_posix())
metadata = lua.eval('''function(src, locale)
 local env={folder_name='workshop-3831773235',locale=locale,ChooseTranslationTable=function(t) return t[locale] or t[1] end}
 local f=assert(loadstring(src));setfenv(f,env);f()
 assert(env.forcemanifest==false)
 local option=env.configuration_options[1]
 assert(option.default==120 and #option.options==90)
 for i=1,#option.options do assert(option.options[i].data~=122) end
 return env.version
end''')
results = []
for locale in ['en','zh','zht','schinese']:
    assert metadata(info.read_text(encoding='utf-8'),locale)=='1.3.5'
    results.append({'case':'native modinfo sandbox '+locale,'passed':True})

# Execute the actual configuration block and actual input module against narrow input mocks.
block = main.read_text(encoding='utf-8').split('local bankai_key =',1)[1].split('\n\n',1)[0]
block = 'local bankai_key ='+block
resolve = lua.eval('''function(src,value)
 local env={G={TUNING={}},GetModConfigData=function() return value end}
 local f=assert(loadstring(src));setfenv(f,env);f();return env.G.TUNING.HITSUGAYA_COMPAT_KEY
end''')
test_input = lua.eval('''function(src,key,pressed,down,blocked)
 local callback,requests=nil,{}
 local hud={IsChatInputScreenOpen=function() return blocked end,IsConsoleScreenOpen=function() return false end,IsCraftingOpen=function() return false end}
 local p={HUD=hud,components={playercontroller={IsEnabled=function() return true end}},IsValid=function() return true end,HasTag=function() return false end,ListenForEvent=function() end,DoTaskInTime=function(self,t,fn) fn() end}
 local env={ThePlayer=p,KEY_Z=122,TheFrontEnd={GetActiveScreen=function() return hud end},IsPaused=function() return false end,TheNet={IsServerPaused=function() return false end},TheInput={AddKeyHandler=function(self,fn) callback=fn;return {Remove=function() end} end},GetModRPC=function() return 'rpc' end,SendModRPCToServer=function(rpc,transform,freeze) requests[#requests+1]={transform,freeze} end}
 local f=assert(loadstring(src));setfenv(f,env);f().Attach(p,key);callback(pressed,down)
 return #requests,requests[1] and requests[1][1] or false,requests[1] and requests[1][2] or false
end''')
src=(dest/'scripts/hitsugaya_compat_input.lua').read_text(encoding='utf-8')
for label, saved, expected in [('missing',None,120),('legacy Z',122,120),('X',120,120),('custom Y',121,121)]:
    key=resolve(block,saved);assert key==expected
    for pressed,down,blocked,want in [(expected,False,False,(1,True,False)),(122,False,False,(1,False,True)),(expected,True,False,(0,False,False)),(102,False,False,(0,False,False)),(expected,False,True,(0,False,False))]:
        actual=test_input(src,key,pressed,down,blocked);assert actual==want,(label,pressed,actual,want)
        results.append({'case':label,'pressed':pressed,'down':down,'chat_open':blocked,'expected':want,'passed':True})
print(json.dumps({"compiled": len(list(dest.rglob("*.lua"))), "passed": len(results)}))

local results={}
local function test(name,fn)fn();results[#results+1]=name end
local function near(a,b)assert(math.abs(a-b)<1e-8,tostring(a).." ~= "..tostring(b))end
local function fixture()
    local now,tasks=0,{}
    local e=setmetatable({},{__index=_G})
    e.math=setmetatable({clamp=function(v,a,b)return math.max(a,math.min(b,v))end},{__index=math})
    e.Class=function(ctor)local c={};c.__index=c;return setmetatable(c,{__call=function(_,inst)local s=setmetatable({},c);ctor(s,inst);return s end})end
    e.GetTaskRemaining=function(t)return math.max(0,t.time-now)end
    local f=assert(loadstring(native_freezable));setfenv(f,e);local Freezable=f()
    local t={components={},valid=true,visible=true,events={},tags={}}
    t.IsValid=function()return t.valid end
    t.HasTag=function(_,tag)return t.tags[tag]end
    t.AddTag=function(_,tag)t.tags[tag]=true end
    t.RemoveTag=function(_,tag)t.tags[tag]=nil end
    t.entity={IsVisible=function()return t.visible end}
    t.AnimState={SetAddColour=function()end}
    t.components.health={IsDead=function()return false end}
    t.components.combat={SetTarget=function()end,BlankOutAttacks=function()end}
    t.ListenForEvent=function(_,name,fn)t.events[name]=fn end
    t.RemoveEventCallback=function(_,name)t.events[name]=nil end
    t.PushEvent=function(_,name,data)if t.events[name] then t.events[name](t,data)end end
    t.StopBrain=function()end;t.RestartBrain=function()end
    t.DoTaskInTime=function(_,dt,fn,...)
        local args={...};local task={time=now+dt,cancelled=false}
        task.Cancel=function(s)s.cancelled=true end
        task.fn=function()fn(t,unpack(args))end
        tasks[#tasks+1]=task;return task
    end
    t.DoPeriodicTask=function(_,dt,fn,initial,...)return t:DoTaskInTime(initial or dt,fn,...)end
    local c=Freezable(t);t.components.freezable=c
    local adapter=assert(loadstring(adapter_source))()
    local he=setmetatable({require=function(name)assert(name=="hitsugaya_freeze");return adapter end},{__index=_G})
    local hf=assert(loadstring(haunt_source));setfenv(hf,he);local h=hf()
    local ghost={prefab="hitsugaya",IsValid=function()return true end,HasTag=function(_,tag)return tag=="playerghost"end}
    local hc={inst=t,cooldowntimer=0,DoHaunt=function(self)self.cooldowntimer=7 end};h.Patch(hc)
    local function advance(endtime)
        while true do
            local best
            for _,task in ipairs(tasks)do if not task.cancelled and task.time<=endtime and (best==nil or task.time<best.time) then best=task end end
            if best==nil then break end
            now=best.time;best.cancelled=true;best.fn()
        end
        now=endtime
    end
    local function cast(bankai)
        local ce=setmetatable({Class=e.Class,GetTime=function()return now end,SpawnPrefab=function()return nil end,
            TheWorld={components={}},TheSim={FindEntities=function()return {t} end},
            require=function(name)
                if name=="hitsugaya_freeze" then return adapter end
                if name=="hitsugaya_localization" then return {Say=function()end} end
                if name=="hitsugaya_ice" then return {GetRadius=function()return bankai and 20 or 10 end} end
                return {}
            end},{__index=_G})
        local cf=assert(loadstring(compat_source));setfenv(cf,ce);local Compat=cf()
        local sanity={current=100,DoDelta=function(self,v)self.current=self.current+v end}
        local inst={components={sanity=sanity},Transform={GetWorldPosition=function()return 0,0,0 end},SoundEmitter={PlaySound=function()end}}
        local ability=setmetatable({inst=inst,transformed=bankai,freeze_ready_time=0,IsAlive=function()return true end,IsColdTerrain=function()return false end,ScheduleCooldownSound=function()end},{__index=Compat})
        assert(ability:Freeze());near(sanity.current,90);near(ability.freeze_ready_time,now+10)
    end
    return t,c,adapter,advance,function()hc:DoHaunt(ghost)end,hc,cast
end
test("real haunt path totals 2.5 frozen plus 2.5 thawing",function()
    local t,c,a,advance,haunt,hc=fixture();haunt()
    assert(c:IsFrozen() and not c:IsThawing());near(c:GetTimeToWearOff(),2.5);assert(hc.cooldowntimer==7)
    advance(2.49);assert(not c:IsThawing());advance(2.5);assert(c:IsThawing());near(c:GetTimeToWearOff(),2.5)
    advance(4.99);assert(c:IsFrozen());advance(5);assert(not c:IsFrozen());near(c.wearofftime,10)
end)
test("already frozen haunt never refreshes either phase",function()
    local t,c,a,advance,haunt,hc=fixture();haunt();advance(1);hc.cooldowntimer=0;haunt();near(c:GetTimeToWearOff(),1.5)
    advance(3);hc.cooldowntimer=0;haunt();near(c:GetTimeToWearOff(),2);advance(5);assert(not c:IsFrozen())
end)
test("native attack breaks haunt ice early",function()
    local t,c,a,advance,haunt=fixture();haunt();advance(1);t:PushEvent("attacked",{damage=1});assert(not c:IsFrozen())
    advance(5);assert(not c:IsFrozen())
end)
test("other cold source replaces haunt timing without late forced thaw",function()
    local t,c,a,advance,haunt=fixture();haunt();advance(1);c:AddColdness(1,8)
    near(c:GetTimeToWearOff(),8);advance(5);assert(c:IsFrozen() and not c:IsThawing())
    advance(9);assert(c:IsThawing());near(c:GetTimeToWearOff(),10);advance(19);assert(not c:IsFrozen())
end)
test("normal Z replaces haunt with its three second total",function()
    local t,c,a,advance,haunt=fixture();haunt();advance(1);a.Apply(t)
    near(c:GetTimeToWearOff(),1.5);advance(2.5);assert(c:IsThawing());near(c:GetTimeToWearOff(),1.5)
    advance(4);assert(not c:IsFrozen())
end)
test("native cold after completed haunt retains default twenty seconds",function()
    local t,c,a,advance,haunt=fixture();haunt();advance(5);c:AddColdness(4)
    near(c:GetTimeToWearOff(),10);advance(15);near(c:GetTimeToWearOff(),10);advance(25);assert(not c:IsFrozen())
end)
test("insufficient cold respects resistance and does not leak duration",function()
    local t,c,a,advance,haunt=fixture();c:SetResistance(5);haunt();assert(not c:IsFrozen())
    c:AddColdness(1);assert(c:IsFrozen());near(c:GetTimeToWearOff(),10)
end)
test("invisible target rejects freeze and keeps later native duration",function()
    local t,c,a,advance,haunt=fixture();t.visible=false;haunt();assert(not c:IsFrozen())
    t.visible=true;c:AddColdness(1);near(c:GetTimeToWearOff(),10)
end)
test("native diminishing returns can shorten the five second maximum",function()
    local t,c,a,advance,haunt=fixture();c.diminishingreturns=true;haunt();advance(2.5);assert(c:IsThawing())
    assert(c:GetTimeToWearOff()<=2.5);advance(5);assert(not c:IsFrozen())
end)
for _,bankai in ipairs({false,true}) do
    for _,boss in ipairs({false,true}) do
        test((bankai and "Bankai" or "normal").." Z on "..(boss and "epic" or "ordinary").." target has approved total",function()
            local t,c,a,advance,haunt,hc,cast=fixture();t.tags.epic=boss or nil
            c:SetDefaultWearOffTime(30) -- target defaults must not lengthen the total
            local total=(bankai and 10 or 3)*(boss and .5 or 1)
            cast(bankai);assert(c:IsFrozen());near(c:GetTimeToWearOff(),total/2)
            advance(total/2-.001);assert(not c:IsThawing())
            advance(total/2);assert(c:IsThawing());near(c:GetTimeToWearOff(),total/2)
            advance(total-.001);assert(c:IsFrozen());advance(total);assert(not c:IsFrozen())
            near(c.wearofftime,30)
        end)
    end
end
test("Bankai Z respects resistance and native nofreeze state",function()
    local t,c,a=fixture();c:SetResistance(5);a.Apply(t,true);assert(not c:IsFrozen())
    t.sg={HasStateTag=function(_,tag)return tag=="nofreeze" end};a.Apply(t,true);assert(not c:IsFrozen())
end)
test("epic diminishing returns can shorten configured half duration",function()
    local t,c,a,advance=fixture();t.tags.epic=true;c.diminishingreturns=true
    a.Apply(t,true);near(c:GetTimeToWearOff(),2.5);advance(2.5);assert(c:IsThawing())
    assert(c:GetTimeToWearOff()<2.5);advance(5);assert(not c:IsFrozen())
end)
test("external cold replaces Bankai Z timing without late forced unfreeze",function()
    local t,c,a,advance=fixture();a.Apply(t,true);advance(1);c:AddColdness(1,8)
    near(c:GetTimeToWearOff(),8);advance(9);near(c:GetTimeToWearOff(),10)
    advance(10);assert(c:IsFrozen());advance(19);assert(not c:IsFrozen())
end)
test("epic haunt stays five seconds after Bankai Z",function()
    local t,c,a,advance,haunt=fixture();t.tags.epic=true;a.Apply(t,true);advance(5);haunt()
    near(c:GetTimeToWearOff(),2.5);advance(7.5);near(c:GetTimeToWearOff(),2.5);advance(10);assert(not c:IsFrozen())
end)
test("native attack still breaks Bankai Z early",function()
    local t,c,a,advance=fixture();a.Apply(t,true);advance(1);t:PushEvent("attacked",{damage=1});assert(not c:IsFrozen())
end)
return results

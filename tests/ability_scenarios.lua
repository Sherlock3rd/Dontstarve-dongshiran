local results={}
local function test(name,fn) fn();results[#results+1]=name end
local function near(a,b) assert(math.abs(a-b)<1e-8,tostring(a).." != "..tostring(b)) end
local function load(name,env)
    local f=assert(loadstring(assert(sources[name]),"@scripts/"..name..".lua"))
    setfenv(f,setmetatable(env or {},{__index=_G}));return f()
end
local speed=load("hitsugaya_attackspeed",{TimeEvent=function(t,fn)return {time=t,fn=fn} end})
local function combat()
    return {min_attack_period=.4,SetAttackPeriod=function(self,v)self.min_attack_period=v end}
end
test("attack period round trip and repeated toggles do not stack",function()
    local p={components={combat=combat()}}
    for i=1,20 do speed.SetBankai(p,true);near(p.components.combat.min_attack_period,.4/1.3) end
    speed.SetBankai(p,false);near(p.components.combat.min_attack_period,.4)
end)
test("later native period setter is preserved when Bankai ends",function()
    local p={components={combat=combat()}};speed.SetBankai(p,true)
    p.components.combat:SetAttackPeriod(.8);near(p.components.combat.min_attack_period,.8/1.3)
    speed.SetBankai(p,false);near(p.components.combat.min_attack_period,.8)
end)
local function graph(prefab,bankai,client,period)
    local s={timeline={{time=.2,fn=function(p)p.hit=p.hit+1 end},{time=.4,fn=function(p)p.last=p.last+1 end}}}
    s.onenter=function(p) p.sg:SetTimeout(math.max(13/30,period));p.enter=p.enter+1 end
    s.onupdate=function(p,dt)p.dt=dt end
    s.onexit=function(p)p.exit=p.exit+1 end
    local g={states={attack=s}};speed.PatchGraph(g);speed.PatchGraph(g)
    local p={prefab=prefab,components=client and {} or {combat={min_attack_period=period}},replica={combat={MinAttackPeriod=function()return period end}},_hitsugaya_bankai={value=function()return bankai end},hit=0,last=0,enter=0,exit=0}
    p.AnimState={SetDeltaTimeMultiplier=function(_,v)p.rate=v end}
    p.sg={currentstate=s,statemem={},SetTimeout=function(self,t)self.timeout=t end}
    s.onenter(p)
    return p,s
end
for _,client in ipairs({false,true}) do
    local side=client and "prediction" or "authority"
    test(side.." native callbacks execute once with 1.3 timing",function()
        local p,s=graph("hitsugaya",true,client,.4/1.3)
        near(p.sg.timeout,(13/30)/1.3);near(p.rate,1.3)
        for _,event in ipairs(s.timeline) do event.fn(p) end
        assert(p.hit==1 and p.last==1 and p.enter==1 and #s.timeline==4)
        s.onupdate(p,.1);near(p.dt,.13);s.onexit(p);near(p.rate,1);assert(p.exit==1)
    end)
    test(side.." normal character keeps original timing",function()
        local p,s=graph("wilson",true,client,.4)
        near(p.sg.timeout,13/30);assert(p.rate==nil)
        for _,event in ipairs(s.timeline) do event.fn(p) end
        assert(p.hit==1 and p.last==1);s.onupdate(p,.1);near(p.dt,.1)
    end)
    test(side.." slow weapons are not accelerated twice",function()
        local p=graph("hitsugaya",true,client,2/1.3)
        near(p.sg.timeout,2/1.3)
    end)
end
test("form change during attack does not duplicate damage callback",function()
    local p,s=graph("hitsugaya",true,false,.4/1.3)
    s.timeline[1].fn(p);p._hitsugaya_bankai.value=function()return false end
    for i=2,#s.timeline do s.timeline[i].fn(p) end
    assert(p.hit==1 and p.last==1)
end)
test("state redirect on native enter is respected",function()
    local s={onenter=function(p)p.sg.currentstate={} end,timeline={}}
    speed.PatchGraph({states={attack=s}})
    local p={sg={currentstate=s},prefab="hitsugaya"};s.onenter(p)
end)
local haunt=load("hitsugaya_haunt",{require=function(name)
    assert(name=="hitsugaya_freeze")
    return {ApplyHaunt=function(target)target.components.freezable:AddColdness(4)end}
end})
local function entity(prefab,tags)
    return {prefab=prefab,tags=tags or {},valid=true,components={},IsValid=function(s)return s.valid end,HasTag=function(s,t)return s.tags[t] end}
end
local function haunted()
    local t=entity("spider");local cold=0
    t.components={combat={},health={IsDead=function()return false end},freezable={IsFrozen=function()return false end,AddColdness=function(_,v)cold=cold+v end}}
    local h={inst=t,cooldowntimer=0,calls=0,DoHaunt=function(s,d)s.calls=s.calls+1;if s.callback then s.callback() end;s.cooldowntimer=7;return "native" end}
    haunt.Patch(h);haunt.Patch(h)
    return h,entity("hitsugaya",{playerghost=true}),function()return cold end
end
test("ghost coldness preserves native result callback and cooldown",function()
    local h,d,cold=haunted();assert(h:DoHaunt(d)=="native");assert(h.calls==1 and h.cooldowntimer==7);near(cold(),4)
    h:DoHaunt(d);near(cold(),4)
end)
for _,label in ipairs({"other ghost","alive","player target","dead target","immune target","frozen target","removed by haunt","revived by haunt"}) do
    test("haunt excludes "..label,function()
        local h,d,cold=haunted()
        if label=="other ghost" then d.prefab="wilson"
        elseif label=="alive" then d.tags.playerghost=nil
        elseif label=="player target" then h.inst.tags.player=true
        elseif label=="dead target" then h.inst.components.health.IsDead=function()return true end
        elseif label=="immune target" then h.inst.components.freezable=nil
        elseif label=="frozen target" then h.inst.components.freezable.IsFrozen=function()return true end
        elseif label=="removed by haunt" then h.callback=function()h.inst.valid=false end
        else h.callback=function()d.tags.playerghost=nil end end
        h:DoHaunt(d);near(cold(),0);assert(h.calls==1)
    end)
end
local function wave(bankai,positions)
    local calls,said={},{}
    local env={PI=math.pi,RADIANS=180/math.pi,require=function(name)
        if name=="hitsugaya_localization" then return {Say=function(_,key)said[#said+1]=key end} end
        return {} end,Class=function(ctor)local c={};c.__index=c;return setmetatable(c,{__call=function(_,p)local o=setmetatable({},c);ctor(o,p);return o end})end,
        SpawnPrefab=function()return nil end}
    local targets={}
    for i,v in ipairs(positions) do
        local t=entity("spider",{hostile=true});t.GUID=i
        t.IsInLimbo=function()return false end;t.HasAnyTag=function()return false end
        t.Transform={GetWorldPosition=function()return v[1],0,v[2] end}
        t.components={health={currenthealth=100,IsDead=function()return false end},combat={GetAttacked=function(_,attacker,damage)calls[#calls+1]=i;t.components.health.currenthealth=100-damage end}}
        targets[#targets+1]=t
    end
    env.TheWorld={Pathfinder={IsClear=function()return true end},Map={GetPlatformAtPoint=function(_,x,z,extra)assert(z~=nil and extra==nil);return nil end,IsPassableAtPoint=function()return true end}}
    env.TheSim={FindEntities=function(_,x,y,z,r)env.radius=r;return targets end}
    local p={components={hitsugaya_compat={transformed=bankai},combat={CanTarget=function()return true end,CalcDamage=function()return 100 end}},ListenForEvent=function()end}
    local w=load("components/hitsugaya_swordwave",env)(p)
    w:Release({x=0,z=0,dx=1,dz=0,weapon={},target=targets[1]})
    assert(said[1]=="WAVE_CAST")
    return calls,env.radius
end
test("wave radius four before Bankai and eight after, forward cone retained",function()
    local positions={{3,0},{6,0},{8,0},{8.01,0},{-3,0},{2,4}}
    local normal,r=wave(false,positions);assert(#normal==1 and r==4)
    local bankai,r=wave(true,positions);assert(#bankai==3 and r==8)
end)
test("expanded wave retains six target cap",function()
    local hits=wave(true,{{1,0},{2,0},{3,0},{4,0},{5,0},{6,0},{7,0},{8,0}});assert(#hits==6)
end)
test("approved Chinese text is exact",function()
    local s=load("hitsugaya_strings")
    assert(s.zh.BANKAI_ON=="卍解——大红莲冰轮丸！")
    assert(s.zh.FREEZE_CAST=="冰天百花葬！" and s.zh.WAVE_CAST=="群鸟冰柱！")
end)
local function combo()
    local tasks,events={},{}
    local now,releases=0,0
    local weapon={prefab="hitsugayasword",IsValid=function()return true end,components={weapon={CanRangedAttack=function()return false end}}}
    local target=entity("spider",{hostile=true})
    target.IsInLimbo=function()return false end;target.HasAnyTag=function()return false end
    target.Transform={GetWorldPosition=function()return 1,0,0 end}
    target.components={health={IsDead=function()return false end},combat={}}
    local p={components={hitsugaya_compat={IsAlive=function()return true end},combat={CanTarget=function()return true end},inventory={GetEquippedItem=function()return weapon end}},Transform={GetWorldPosition=function()return 0,0,0 end}}
    p.ListenForEvent=function(_,event,fn)events[event]=fn end
    p.DoTaskInTime=function(_,delay,fn)local t={fn=fn,Cancel=function(s)s.cancelled=true end};tasks[#tasks+1]=t;return t end
    local w=load("components/hitsugaya_swordwave",{PI=math.pi,EQUIPSLOTS={HANDS="hands"},GetTime=function()return now end,require=function()return {} end,
        Class=function(ctor)local c={};c.__index=c;return setmetatable(c,{__call=function(_,inst)local o=setmetatable({},c);ctor(o,inst);return o end})end})(p)
    w.Release=function()releases=releases+1 end
    local function flush()local pending=tasks;tasks={};for _,t in ipairs(pending)do if not t.cancelled then t.fn() end end end
    local function hit(kind,delay,defer)
        now=now+(delay or .5)
        w:OnAttack({target=target,weapon=weapon,projectile=kind=="projectile" and {} or nil})
        if kind~="blocked" then w:OnHit({target=target,weapon=weapon,from_doattack=kind~="wave",damageresolved=kind=="zero" and 0 or 10,redirected=kind=="redirect" and {} or nil}) end
        if not defer then flush() end
        return releases
    end
    return hit,events,flush,function()return releases end
end
test("swordwave triggers only on hits two four six",function()
    local hit=combo();for i=1,6 do assert(hit()==math.floor(i/2)) end
end)
test("combo accepts three seconds but restarts beyond it",function()
    local hit=combo();assert(hit()==0);assert(hit(nil,3)==1)
    assert(hit()==1);assert(hit(nil,3.01)==1);assert(hit()==2)
end)
for _,kind in ipairs({"zero","redirect","blocked","projectile","wave"})do
    test(kind.." attack breaks combo without contributing a hit",function()
        local hit=combo();assert(hit()==0);assert(hit(kind)==0);assert(hit()==0);assert(hit()==1)
    end)
end
for _,event in ipairs({"onmissother","equip","unequip","death","ms_becameghost","playerdeactivated"})do
    test(event.." resets combo and cancels a deferred wave",function()
        local hit,events,flush,count=combo()
        hit();events[event]();assert(hit()==0)
        hit(nil,nil,true);events[event]();flush();assert(count()==0)
        assert(hit()==0);assert(hit()==1)
    end)
end
return results

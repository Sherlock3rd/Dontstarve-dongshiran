local results = {}
local function test(name, fn) fn(); results[#results + 1] = name end
local time, queue, worlds, spawned, loot, nextguid = 100, {}, {}, {}, 0, 10
local function eq(a,b) assert(a==b, tostring(a).." ~= "..tostring(b)) end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function save(g) local data={};g.OnSave(g,data);return data end
local function advance(t)
    time = time + t
    for _, e in pairs(worlds) do e.TheWorld.state = { cycles=math.floor(time/480),time=(time%480)/480 } end
end
local function flush()
    local guard=0
    while #queue>0 do
        guard=guard+1;assert(guard<100)
        local msg=table.remove(queue,1)
        if worlds[msg.to].connected then worlds[msg.to].manager[msg.method](worlds[msg.to].manager,msg.sender,unpack(msg.args)) end
    end
end
local function make(shard)
    local e=setmetatable({connected=true,entities={},deferred={},ocean=10,blocked=false,checks=0},{__index=_G})
    worlds[shard]=e
    e.Class=function(ctor)
        local c={};c.__index=c
        return setmetatable(c,{__call=function(_,inst) local o=setmetatable({},c);ctor(o,inst);return o end})
    end
    e.GetTime=function() return time end
    e.SHARDID={MASTER="1"};e.TUNING={TOTAL_DAY_TIME=480};e.ACTIONS={MINE={id="MINE"}}
    e.TheShard={GetShardId=function() return shard end}
    e.Shard_IsMaster=function() return shard=="1" end
    e.Shard_IsWorldAvailable=function(id) return worlds[id]~=nil and worlds[id].connected end
    e.GetShardModRPC=function(_,method) return method end
    e.SendModRPCToShard=function(method,to,...)
        queue[#queue+1]={method=method,to=to,sender=shard,args={...}}
    end
    e.Vector3=function(x,y,z) return {x=x,y=y,z=z} end
    e.Asset=function() end
    e.MakeObstaclePhysics=function(inst,r) inst.physics_radius=r end
    e.Prefab=function(_,fn) return fn end
    local cache={}
    e.require=function(name)
        if cache[name]==nil then
            local f=assert(loadstring(assert(sources[name],name),'@scripts/'..name..'.lua'));setfenv(f,e);cache[name]=f()
        end
        return cache[name]
    end
    local noop=function() end
    local function entity()
        nextguid=nextguid+1
        local inst={GUID=nextguid,components={},tags={},valid=true,events={},x=0,z=0}
        inst.entity={AddTransform=noop,AddAnimState=noop,AddMiniMapEntity=noop,AddNetwork=noop,SetPristine=noop}
        inst.AnimState={SetBank=noop,SetBuild=noop,PlayAnimation=function(_,name)inst.animation=name end,Hide=noop}
        inst.MiniMapEntity={SetIcon=noop}
        inst.Transform={GetWorldPosition=function() return inst.x,0,inst.z end,SetPosition=function(_,x,_,z) inst.x=x;inst.z=z end}
        function inst:IsValid() return self.valid end
        function inst:AddTag(tag) self.tags[tag]=true end
        function inst:HasTag(tag) return self.tags[tag]~=nil end
        function inst:ListenForEvent(name,fn) self.events[name]=fn end
        function inst:Remove() self.valid=false;if self.events.onremove then self.events.onremove() end end
        function inst:DoTaskInTime(_,fn) e.deferred[#e.deferred+1]=function() if self.valid then fn() end end end
        function inst:AddComponent(name)
            local c={}
            if name=='workable' then
                c.workleft=10;c.workable=true
                function c:SetWorkAction(a) self.action=a end
                function c:SetWorkLeft(n) self.workleft=math.max(1,n);self.workable=true end
                function c:SetWorkable(b) self.workable=b end
                function c:GetWorkLeft() return self.workable and self.workleft or 0 end
                function c:SetOnFinishCallback(fn) self.finish=fn end
            elseif name=='lootdropper' then c.SpawnLootPrefab=function() loot=loot+1 end end
            self.components[name]=c
        end
        return inst
    end
    e.CreateEntity=entity
    e.TheWorld={ismastersim=true,components={},GUID=nextguid,DoPeriodicTask=function() return {Cancel=noop} end,Map={}}
    local map=e.TheWorld.Map
    function map:IsLandTileNoDocksAtPoint(x) return e.ocean==nil or x<e.ocean end
    function map:IsPassableAtPoint() return not e.impassable end
    function map:GetPlatformAtPoint() return e.boat end
    function map:IsPointNearHole() return e.hole end
    function map:IsDeployPointClear(pt)
        e.checks=e.checks+1
        if e.blocked then return false end
        for _,v in ipairs(e.entities) do if v.valid and (v.x-pt.x)^2+(v.z-pt.z)^2<4 then return false end end
        return true
    end
    function map:IsOceanAtPoint(x) return e.ocean~=nil and x>=e.ocean end
    e.TheSim={FindEntities=function(_,x,y,z,r,tags)
        local found={}
        for _,v in ipairs(e.entities) do if v.valid and (tags==nil or v.tags[tags[1]]) and (v.x-x)^2+(v.z-z)^2<=r*r then found[#found+1]=v end end
        return found
    end}
    e.SpawnPrefab=function(name)
        if e.spawnfail then return end
        local inst=e.require('prefabs/hitsugaya_iceglacier')();inst.prefab=name
        e.entities[#e.entities+1]=inst;spawned[#spawned+1]=inst;return inst
    end
    e.player=function(owner,x,z)
        local p=entity();p.prefab='hitsugaya';p.userid=owner;p.x=x or 0;p.z=z or 0
        p.components.health={IsDead=function() return p.dead end}
        return p
    end
    e.pond=function(x,z,name)
        local p=entity();p.prefab=name or 'pond';p.x=x;p.z=z;p:AddTag('pond');e.entities[#e.entities+1]=p;return p
    end
    e.runDeferred=function() local tasks=e.deferred;e.deferred={};for _,fn in ipairs(tasks) do fn() end end
    e.manager=e.require('components/hitsugaya_iceworld')(e.TheWorld)
    e.TheWorld.components.hitsugaya_iceworld=e.manager
    advance(0)
    return e
end
local function reset()
    time=100;queue={};worlds={};spawned={};loot=0
    return make('1'),make('2')
end
local m,c=reset()
test('normal range includes 10, excludes 10.001',function()
    local ice=m.require('hitsugaya_ice');assert(ice.InRange(10,0,0,0));assert(not ice.InRange(10.001,0,0,0))
end)
test('pond in range produces one native-collision glacier',function()
    m.ocean=nil;m.pond(8,0)
    assert(m.manager:TryCreate(m.player('u1')));eq(#spawned,1)
    local g=spawned[1];assert(g.ice_ready);eq(g.physics_radius,1);eq(g.components.workable.workleft,3)
end)
test('ten-second recast does not reset sixty-second production cooldown',function()
    local ready=m.manager.cooldowns.u1;spawned[1]:Remove();advance(10)
    assert(not m.manager:TryCreate(m.player('u1')));eq(m.manager.cooldowns.u1,ready)
end)
test('production resumes at sixty seconds',function()
    advance(50);assert(m.manager:TryCreate(m.player('u1')));eq(#spawned,2)
end)
test('any owner glacier suppresses nearby production',function()
    assert(not m.manager:TryCreate(m.player('u2')));eq(#spawned,2)
end)
test('mining yields exactly three even with repeated finish callbacks',function()
    local g=spawned[2];g.components.workable.finish(g);g.components.workable.finish(g);eq(loot,3);assert(not g.valid)
end)
test('no water means no glacier or consumed production cooldown',function()
    m,c=reset();m.ocean=nil;assert(not m.manager:TryCreate(m.player('u1')));eq(count(m.manager.cooldowns),0)
end)
test('pond outside cast radius does not qualify',function()
    m.pond(10.001,0);assert(not m.manager:TryCreate(m.player('u1')))
end)
test('ocean water outside radius does not qualify',function()
    m,c=reset();m.ocean=10.001;assert(not m.manager:TryCreate(m.player('u1')))
end)
test('ocean shoreline produces inside cast radius',function()
    m,c=reset();assert(m.manager:TryCreate(m.player('u1')))
    assert(m.require('hitsugaya_ice').InRange(spawned[1].x,spawned[1].z,0,0))
end)
test('ocean touching cast boundary can qualify',function()
    m,c=reset();m.ocean=10;assert(m.manager:TryCreate(m.player('u1')))
end)
test('crowded coast has bounded deployment queries and no spawn',function()
    m,c=reset();m.blocked=true;assert(not m.manager:TryCreate(m.player('u1')));assert(m.checks<=80)
    local p=m.player('u1');p.components.hitsugaya_compat={transformed=true};m.checks=0
    assert(not m.manager:TryCreate(p));assert(m.checks<=316)
end)
test('boats, holes and impassable ground reject placement',function()
    for _,field in ipairs({'boat','hole','impassable'}) do
        m,c=reset();m[field]=true;assert(not m.manager:TryCreate(m.player('u1')))
    end
end)
test('dead and wrong-prefab callers cannot produce',function()
    m,c=reset();local p=m.player('u1');p.dead=true;assert(not m.manager:TryCreate(p))
    p.dead=false;p.prefab='wilson';assert(not m.manager:TryCreate(p))
end)
test('cave request waits for master and validation before mining',function()
    m,c=reset();c.manager:TryCreate(c.player('u1'));eq(#spawned,0)
    local req=table.remove(queue,1);m.manager:Request(req.sender,unpack(req.args))
    local reply=table.remove(queue,1);c.manager:Grant(reply.sender,unpack(reply.args))
    eq(#spawned,1);assert(not spawned[1].components.workable.workable)
    flush();assert(spawned[1].ice_ready);assert(spawned[1].components.workable.workable)
end)
test('migration cannot bypass cooldown or per-player two-glacier cap',function()
    assert(not m.manager:TryCreate(m.player('u1')));eq(#spawned,1)
    advance(60);assert(m.manager:TryCreate(m.player('u1')));eq(#spawned,2)
    advance(60);assert(c.manager:TryCreate(c.player('u1',0,40)));flush();eq(#spawned,3)
    assert(not spawned[1].valid);assert(spawned[2].valid and spawned[3].valid)
    eq(count(m.manager.records),2);eq(loot,0)
end)
test('third glacier waits for old shard deletion acknowledgement',function()
    m,c=reset();c.manager:TryCreate(c.player('u1'));flush()
    advance(60);m.manager:TryCreate(m.player('u1'));advance(60)
    m.manager:TryCreate(m.player('u1',0,40))
    eq(#spawned,2);assert(spawned[1].valid);eq(count(m.manager.evictions),1)
    local msg=table.remove(queue,1);eq(msg.method,'Evict')
    c.manager:Evict(msg.sender,unpack(msg.args));assert(not spawned[1].valid);eq(#spawned,2)
    m.manager:Evicted('wrong-shard',spawned[1].ice_token);eq(#spawned,2)
    flush();eq(#spawned,3);eq(count(m.manager.records),2);eq(loot,0)
end)
test('oldest unavailable shard prevents replacement',function()
    m,c=reset();c.manager:TryCreate(c.player('u1'));flush()
    advance(60);m.manager:TryCreate(m.player('u1'));advance(60);c.connected=false
    m.manager:TryCreate(m.player('u1',0,40));eq(#spawned,2);assert(spawned[1].valid)
    eq(count(m.manager.records),2);eq(count(m.manager.evictions),0)
end)
test('failed spawn after deletion cannot refund old glacier as extra loot',function()
    m,c=reset();c.manager:TryCreate(c.player('u1'));flush()
    advance(60);m.manager:TryCreate(m.player('u1'));advance(60);m.spawnfail=true
    m.manager:TryCreate(m.player('u1',0,40));flush()
    assert(not spawned[1].valid);assert(spawned[2].valid);eq(#spawned,2)
    eq(count(m.manager.records),1);eq(loot,0)
end)
test('same-owner concurrent replacement requests cannot evict twice',function()
    m,c=reset();c.manager:TryCreate(c.player('u1'));flush()
    advance(60);m.manager:TryCreate(m.player('u1'));advance(60)
    m.manager:TryCreate(m.player('u1',0,40));m.manager:Request('2','second-request','u1')
    eq(count(m.manager.evictions),1);flush();eq(#spawned,3)
    assert(spawned[2].valid);eq(count(m.manager.records),2)
end)
test('lost deletion acknowledgement never grants a third permit',function()
    m,c=reset();c.manager:TryCreate(c.player('u1'));flush()
    advance(60);m.manager:TryCreate(m.player('u1'));advance(60)
    m.manager:TryCreate(m.player('u1',0,40));queue={};advance(9);m.manager:Update()
    eq(count(m.manager.evictions),0);eq(#spawned,2);eq(count(m.manager.records),2)
end)
test('wrong shard cannot delete glacier; repeated authorized deletion gives no loot',function()
    m,c=reset();m.manager:TryCreate(m.player('u1'));local g=spawned[1]
    m.manager:Evict('2',g.ice_token);assert(g.valid)
    m.manager:Evict('1',g.ice_token);m.manager:Evict('1',g.ice_token)
    assert(not g.valid);eq(loot,0);eq(count(m.manager.records),0)
end)
test('one player simultaneous shard requests serialize to one permit',function()
    m,c=reset();c.manager:TryCreate(c.player('u1'));m.manager:TryCreate(m.player('u1'));flush()
    eq(#spawned,1);eq(count(m.manager.records),1)
end)
test('two players simultaneous same-location cave casts produce only one',function()
    m,c=reset();c.manager:TryCreate(c.player('u1'));c.manager:TryCreate(c.player('u2'));flush()
    eq(#spawned,1);eq(count(m.manager.records),1)
end)
test('master unavailable fails closed without spawning',function()
    m,c=reset();m.connected=false;assert(not c.manager:TryCreate(c.player('u1')));eq(#queue,0)
end)
test('late grant releases permit without spawning',function()
    m,c=reset();c.manager:TryCreate(c.player('u1'));advance(11);c.manager:Update();flush()
    eq(#spawned,0);eq(count(m.manager.records),0);eq(count(m.manager.cooldowns),0)
end)
test('missing prefab releases reservation and cooldown',function()
    m,c=reset();m.spawnfail=true;m.manager:TryCreate(m.player('u1'));eq(count(m.manager.records),0)
    eq(count(m.manager.cooldowns),0)
end)
test('unclaimed reservation expires and refunds cooldown',function()
    m,c=reset();m.manager:Request('2','request','u1');queue={};advance(21);m.manager:Update()
    eq(count(m.manager.records),0);eq(count(m.manager.cooldowns),0)
end)
test('two game days remove glacier without drops',function()
    m,c=reset();m.manager:TryCreate(m.player('u1'));advance(960);m.manager:Update()
    assert(not spawned[1].valid);eq(loot,0);eq(count(m.manager.records),0)
end)
test('expired glacier cannot yield ice between cleanup ticks',function()
    m,c=reset();m.manager:TryCreate(m.player('u1'));advance(960);local g=spawned[1]
    g.components.workable.finish(g);eq(loot,0)
end)
test('server save/load preserves owner limits and cooldown',function()
    m,c=reset();m.manager:TryCreate(m.player('u1'))
    local data=m.manager:OnSave();local manager=m.require('components/hitsugaya_iceworld')(m.TheWorld)
    manager:OnLoad(data);eq(count(manager.records),1);eq(manager.cooldowns.u1,160)
    local nextid=manager:NextID();assert(manager.records[nextid]==nil);assert(manager.serial>m.manager.serial)
end)
test('loaded cave glacier stays unmineable until master confirms',function()
    m,c=reset();c.manager:TryCreate(c.player('u1'));flush();local original=spawned[1]
    original.components.workable.workleft=2;local data=save(original)
    c.manager.glaciers={};original.valid=false
    local g=c.SpawnPrefab('hitsugaya_iceglacier');g.OnLoad(g,data)
    assert(not g.components.workable.workable);c.runDeferred();assert(not g.components.workable.workable)
    flush();assert(g.ice_ready);eq(g.components.workable.workleft,2)
end)
test('orphan or duplicated save entity cannot yield additional ice',function()
    local g=c.SpawnPrefab('hitsugaya_iceglacier');g.OnLoad(g,{owner='u1',token='absent',expires=time+100,work=3})
    c.runDeferred();flush();assert(not g.valid)
    local existing=spawned[2];local duplicate=c.SpawnPrefab('hitsugaya_iceglacier')
    duplicate.OnLoad(duplicate,save(existing));c.runDeferred();assert(not duplicate.valid)
    assert(existing.valid);eq(count(m.manager.records),1)
end)
test('wrong shard cannot grant, confirm or release master permits',function()
    m,c=reset();m.manager:TryCreate(m.player('u1'));local g=spawned[1]
    m.manager:Release('2',g.ice_token);eq(count(m.manager.records),1)
    m.manager:Validated('2',g.ice_token,0);assert(g.valid)
    c.manager:Grant('2','request','bad',time+960);eq(#spawned,1)
end)
test('malformed save values are rejected without errors',function()
    m,c=reset();m.manager:OnLoad({records={bad={owner='u',shard='1',expires=0/0,deadline=1,ready=2}},cooldowns={bad=math.huge}})
    eq(count(m.manager.records),0);eq(count(m.manager.cooldowns),0)
    m.manager:Request('2',{},{});m.manager:Validate('2',{},{});m.manager:Release('2',{})
end)
test('client prefab has no server components or timers',function()
    m,c=reset();m.TheWorld.ismastersim=false;local g=m.SpawnPrefab('hitsugaya_iceglacier')
    eq(count(g.components),0);eq(#m.deferred,0)
end)
test('production errors cannot abort Freeze or change its cost/cooldown',function()
    m,c=reset()
    local p=m.player('u1')
    p.components.sanity={current=100,DoDelta=function(self,n) self.current=self.current+n end}
    p.SoundEmitter={PlaySound=function() end}
    m.SpawnPrefab=function() return {Transform={SetPosition=function() end,SetScale=function() end}} end
    m.print=function() end
    m.manager.TryCreate=function() error('injected placement failure') end
    local compat=m.require('components/hitsugaya_compat')
    local instance=setmetatable({inst=p,freeze_ready_time=0,transformed=false,
        ScheduleCooldownSound=function() end},{__index=compat})
    assert(instance:Freeze());eq(p.components.sanity.current,90);eq(instance.freeze_ready_time,time+10)
    assert(m.manager.error_reported);assert(not instance:Freeze());eq(p.components.sanity.current,90)
end)
test('Bankai expands water detection and glacier suppression to radius twenty',function()
    m,c=reset();m.ocean=nil;m.pond(18,0)
    local p=m.player('u1');assert(not m.manager:TryCreate(p))
    p.components.hitsugaya_compat={transformed=true}
    eq(m.require('hitsugaya_ice').GetRadius(p),20)
    assert(m.manager:TryCreate(p));eq(#spawned,1)
    local ice=m.require('hitsugaya_ice')
    assert(ice.InRange(20,0,0,0,20));assert(not ice.InRange(20.001,0,0,0,20))
end)
test('blocked near shore does not hide farther clear shore inside Bankai radius',function()
    m,c=reset();m.ocean=3
    local map=m.TheWorld.Map
    function map:IsDeployPointClear(pt)
        m.checks=m.checks+1
        return pt.z>=16 -- near shore crowded; farther shore remains available
    end
    local player=m.player('u1');player.components.hitsugaya_compat={transformed=true}
    assert(m.manager:TryCreate(player));eq(#spawned,1)
    assert(spawned[1].z>=16 and m.require('hitsugaya_ice').InRange(spawned[1].x,spawned[1].z,0,0,20))
end)
test('normal glacier uses native small stage and three mining work',function()
    m,c=reset();assert(m.manager:TryCreate(m.player('u1')))
    local g=spawned[1];eq(g.animation,'low');assert(not g.ice_bankai);eq(g.components.workable.workleft,3);eq(g.physics_radius,1)
end)
test('Bankai glacier uses native full stage and preserves collision',function()
    m,c=reset();local p=m.player('u1');p.components.hitsugaya_compat={transformed=true}
    assert(m.manager:TryCreate(p));local g=spawned[1]
    eq(g.animation,'full');assert(g.ice_bankai);eq(g.physics_radius,1);eq(g.components.workable.workleft,3)
end)
test('cross shard glacier snapshots form at cast time',function()
    m,c=reset();local p=c.player('u1');p.components.hitsugaya_compat={transformed=true}
    assert(c.manager:TryCreate(p));p.components.hitsugaya_compat.transformed=false;flush()
    assert(spawned[1].ice_bankai);eq(spawned[1].animation,'full')
end)
test('large glacier save load restores stage and work, legacy save remains small',function()
    m,c=reset();local p=m.player('u1');p.components.hitsugaya_compat={transformed=true}
    m.manager:TryCreate(p);local g=spawned[1];g.components.workable:SetWorkLeft(2)
    local data=save(g);g:Remove()
    local restored=m.SpawnPrefab('hitsugaya_iceglacier');restored.OnLoad(restored,data)
    eq(restored.animation,'full');assert(restored.ice_bankai);eq(restored.components.workable.workleft,2)
    data.bankai=nil;restored.OnLoad(restored,data);eq(restored.animation,'low');assert(not restored.ice_bankai)
    data.bankai='true';restored.OnLoad(restored,data);assert(not restored.ice_bankai)
end)
test('Bankai glacier mining yields exactly seven once',function()
    m,c=reset();local p=m.player('u1');p.components.hitsugaya_compat={transformed=true}
    assert(m.manager:TryCreate(p));local g=spawned[1]
    g.components.workable.finish(g);g.components.workable.finish(g);eq(loot,7);assert(not g.valid)
end)
test('expired Bankai glacier cannot produce seven ice before or after cleanup',function()
    m,c=reset();local p=m.player('u1');p.components.hitsugaya_compat={transformed=true}
    m.manager:TryCreate(p);local g=spawned[1];advance(960)
    g.components.workable.finish(g);eq(loot,0);m.manager:Update();assert(not g.valid);eq(loot,0)
end)
test('cross shard replacement of large glacier yields no ice',function()
    m,c=reset();local p=c.player('u1');p.components.hitsugaya_compat={transformed=true}
    assert(c.manager:TryCreate(p));flush();advance(60)
    p.z=50;assert(c.manager:TryCreate(p));flush();advance(60)
    p.z=100;assert(c.manager:TryCreate(p));flush()
    eq(#spawned,3);assert(not spawned[1].valid);assert(spawned[2].valid and spawned[3].valid)
    eq(count(m.manager.records),2);eq(loot,0)
    spawned[3].components.workable.finish(spawned[3]);eq(loot,7)
end)
test('loaded large cave glacier yields seven only after master validation',function()
    m,c=reset();local p=c.player('u1');p.components.hitsugaya_compat={transformed=true}
    c.manager:TryCreate(p);flush();local original=spawned[1]
    original.components.workable.workleft=2;local data=save(original)
    c.manager.glaciers={};original.valid=false
    local g=c.SpawnPrefab('hitsugaya_iceglacier');g.OnLoad(g,data)
    eq(g.animation,'full');g.components.workable.finish(g);eq(loot,0)
    c.runDeferred();flush();assert(g.ice_ready);eq(g.components.workable.workleft,2)
    g.components.workable.finish(g);g.components.workable.finish(g);eq(loot,7)
end)
return results

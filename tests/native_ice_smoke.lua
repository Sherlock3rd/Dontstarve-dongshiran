-- Only injected into an isolated, offline test mod. Never ship this module.
local Ice = require("hitsugaya_ice")
local M = {}
local function Check(label, condition)
    assert(condition, "ICE_NATIVE_FAIL " .. label)
    print("ICE_NATIVE_PASS " .. label)
end
function M.Run()
    local manager = TheWorld.components.hitsugaya_iceworld
    Check("world manager loaded", manager ~= nil)
    local x, z
    for _, inst in pairs(Ents) do
        if inst.prefab == "pond" or inst.prefab == "pond_cave" or inst.prefab == "pond_mos" then
            local px, _, pz = inst.Transform:GetWorldPosition()
            if Ice.FindShore(px, pz) ~= nil then x,z=px,pz;break end
        end
    end
    Check("native shoreline found", x ~= nil)
    local player = CreateEntity()
    player.entity:AddTransform()
    player.entity:AddSoundEmitter()
    player.persists=false
    player.Transform:SetPosition(x,0,z)
    player.prefab="hitsugaya"
    player.userid="CODEX_ICE_NATIVE_" .. tostring(TheShard:GetShardId())
    player:AddComponent("health")
    player:AddComponent("sanity")
    -- This transient worker is not a real logged-in player/stategraph.
    player:StopUpdatingComponent(player.components.sanity)
    player.components.sanity:SetMax(200)
    local compat=setmetatable({inst=player,freeze_ready_time=0,transformed=false},
        {__index=require("components/hitsugaya_compat")})
    Check("actual Freeze cast succeeds", compat:Freeze())
    Check("Freeze still costs ten sanity", player.components.sanity.current==190)
    Check("Freeze retains ten second cooldown", math.abs(compat.freeze_ready_time-GetTime()-10)<0.1)
    TheWorld:DoTaskInTime(3,function()
        local g
        for _, inst in pairs(manager.glaciers) do if inst.ice_owner==player.userid then g=inst;break end end
        Check("native prefab and authority validation", g ~= nil and g.ice_ready)
        Check("native collision radius", g:GetPhysicsRadius(0) == 1)
        Check("native mining enabled", g.components.workable:CanBeWorked())
        local gx,gy,gz=g.Transform:GetWorldPosition()
        local function CountIce()
            local count=0
            for _, v in ipairs(TheSim:FindEntities(gx,gy,gz,6)) do
                if v.prefab=="ice" then count=count+(v.components.stackable and v.components.stackable:StackSize() or 1) end
            end
            return count
        end
        local before=CountIce()
        g.components.workable:WorkedBy_Internal(player,1)
        Check("native partial mining", g.components.workable.workleft==2)
        local saved=g:GetSaveRecord()
        Check("native save retains work and owner", saved.data.work==2 and saved.data.owner==player.userid)
        -- Simulate entity unload without releasing the persisted reservation.
        manager.removing=true;g:Remove();manager.removing=false
        g=SpawnSaveRecord(saved)
        Check("restored entity starts unmineable", not g.components.workable:CanBeWorked())
        TheWorld:DoTaskInTime(3,function()
            Check("restored entity revalidates with master", g.ice_ready and g.components.workable:CanBeWorked())
            Check("native partial work survives entity restore", g.components.workable.workleft==2)
            g.components.workable:WorkedBy_Internal(player,2)
            Check("native mining removes glacier", not g:IsValid())
            Check("native fixed three ice yield", CountIce()-before==3)
            Check("mining preserves production cooldown", not manager:TryCreate(player))
            player.userid=player.userid .. "_EVICT"
            Check("eviction fixture queues new owner",manager:TryCreate(player))
            TheWorld:DoTaskInTime(3,function()
                local old
                for _, v in pairs(manager.glaciers) do if v.ice_owner==player.userid then old=v;break end end
                Check("eviction fixture confirmed",old~=nil and old.ice_ready)
                local icebefore=CountIce()
                manager:Evict(tostring(SHARDID.MASTER),old.ice_token)
                Check("native eviction removes without loot",not old:IsValid() and CountIce()==icebefore)
                player:Remove()
                print("ICE_NATIVE_DONE " .. tostring(TheShard:GetShardId()))
            end)
        end)
    end)
end
return M

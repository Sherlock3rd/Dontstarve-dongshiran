local Ice = require("hitsugaya_ice")
local assets = { Asset("ANIM", "anim/ice_boulder.zip"), Asset("MINIMAP_IMAGE", "iceboulder") }

local function SetBankai(inst, enabled)
    inst.ice_bankai = enabled == true
    -- Native AnimState replication carries the stage to clients and late joiners.
    inst.AnimState:PlayAnimation(inst.ice_bankai and "full" or "low")
end

local function Finish(inst)
    if not inst.ice_ready or inst.ice_spent or inst.ice_expires <= Ice.Now() then return end
    inst.ice_spent = true
    -- Fixed total yield; repeated work/finish callbacks cannot duplicate it.
    local amount = inst.ice_bankai and Ice.BANKAI_LOOT or Ice.LOOT
    for i = 1, amount do inst.components.lootdropper:SpawnLootPrefab("ice") end
    inst:Remove()
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()
    inst.AnimState:SetBank("ice_boulder")
    inst.AnimState:SetBuild("ice_boulder")
    inst.AnimState:PlayAnimation("low")
    inst.AnimState:Hide("snow")
    inst.MiniMapEntity:SetIcon("iceboulder.png")
    inst:AddTag(Ice.TAG)
    inst:AddTag("frozen")
    MakeObstaclePhysics(inst, 1)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end

    inst.SetBankai = SetBankai

    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.MINE)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetWorkable(false)
    inst.components.workable:SetOnFinishCallback(Finish)
    inst.OnSave = function(_, data)
        -- Prefab saves fill the supplied table; only component saves return data.
        data.owner, data.token, data.expires = inst.ice_owner, inst.ice_token, inst.ice_expires
        data.spent, data.work = inst.ice_spent == true, inst.components.workable.workleft
        data.bankai = inst.ice_bankai == true
    end
    inst.OnLoad = function(_, data)
        if type(data) ~= "table" then return end
        inst.ice_owner, inst.ice_token, inst.ice_expires = data.owner, data.token, data.expires
        inst.ice_spent = data.spent == true
        inst:SetBankai(data.bankai)
        if Ice.Finite(data.work) then inst.components.workable:SetWorkLeft(math.min(3, math.max(0, data.work))) end
        inst.components.workable:SetWorkable(false)
    end
    inst:DoTaskInTime(0, function()
        local manager = TheWorld.components.hitsugaya_iceworld
        if manager == nil or inst.ice_spent then inst:Remove() else manager:Track(inst) end
    end)
    return inst
end

return Prefab(Ice.PREFAB, fn, assets, { "ice" })

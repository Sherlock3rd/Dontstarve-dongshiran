local MakePlayerCharacter = require("prefabs/player_common")
local assets = {
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
    Asset("ANIM", "anim/hitsugaya.zip"),
    Asset("ANIM", "anim/hitsugayabankai.zip"),
    Asset("ANIM", "anim/ghost_hitsugaya_build.zip"),
}
local prefabs = { "hitsugayasword", "hitsugayarobe", "hitsugaya_ring_fx", "hitsugaya_swordwave_fx", "splash_snow_fx", "collapse_big", "hitsugaya_iceglacier" }

local function common_postinit(inst)
    inst.MiniMapEntity:SetIcon("hitsugaya.tex")
    inst:AddTag("hitsugayaspecific")
    inst._hitsugaya_bankai = net_bool(inst.GUID, "hitsugaya_compat.bankai", "hitsugaya_bankai_dirty")
    if not TheNet:IsDedicated() then
        require("hitsugaya_compat_input").Attach(inst, TUNING.HITSUGAYA_COMPAT_KEY or 122)
    end
end

local function OnNewSpawn(inst)
    local inventory = inst.components.inventory
    if inventory:GetEquippedItem(EQUIPSLOTS.HITSUGAYA_ROBE) ~= nil then return end
    -- Backpacks cannot enter normal inventory slots. Native starting_inventory
    -- uses GiveItem, which would drop this item before the player can equip it.
    local robe = SpawnPrefab("hitsugayarobe", nil, nil, inst.userid)
    if robe ~= nil and not inventory:Equip(robe) then
        -- Preserve both items if another mod has already equipped a backpack.
        robe.Transform:SetPosition(inst.Transform:GetWorldPosition())
        robe.components.inventoryitem:OnDropped(true)
    end
end

local function master_postinit(inst)
    inst.soundsname = "wilson"
    inst.starting_inventory = { "hitsugayasword" }
    -- player_common invokes this extension only for new spawns and clears it
    -- during OnLoad, so existing saves never receive replacement equipment.
    inst.OnNewSpawn = OnNewSpawn
    inst.components.health:SetMaxHealth(150)
    inst.components.hunger:SetMax(150)
    inst.components.sanity:SetMax(200)
    inst.components.temperature.mintemp = 20
    inst.components.hunger:SetRate(TUNING.WILSON_HUNGER_RATE)
    inst:AddComponent("hitsugaya_affinity")
    inst:AddComponent("hitsugaya_compat")
    inst:AddComponent("hitsugaya_rewards")
    inst:AddComponent("hitsugaya_swordwave")
end

return MakePlayerCharacter("hitsugaya", prefabs, assets, common_postinit, master_postinit)

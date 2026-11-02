local Robe = require("hitsugaya_robe")
local assets = {
    Asset("ANIM", "anim/hitsugayarobe.zip"),
    Asset("ANIM", "anim/ui_backpack_2x4.zip"),
    Asset("ATLAS", "images/inventoryimages/hitsugayarobe.xml"),
    Asset("IMAGE", "images/inventoryimages/hitsugayarobe.tex"),
}

local function ApplyAppearance(inst, owner)
    owner.AnimState:OverrideSymbol("swap_body", "hitsugayarobe", "swap_body")
end

local function CaptureBody(inst, owner)
    local build, symbol = owner.AnimState:GetSymbolOverride("swap_body")
    -- Some BODY items intentionally have no swap symbol. Do not remember our
    -- own overlay as the underlying armor when one of those is equipped.
    if build ~= "hitsugayarobe" and build ~= hash("hitsugayarobe") then
        inst._bodybuild, inst._bodysymbol = build, symbol
    end
end

local function OnBodyChanged(inst, owner, data)
    if data ~= nil and data.eslot == EQUIPSLOTS.BODY then
        -- Native equipment callbacks have run when equip/unequip fires.
        CaptureBody(inst, owner)
        ApplyAppearance(inst, owner)
    end
end

local function OnEquip(inst, owner)
    CaptureBody(inst, owner)
    ApplyAppearance(inst, owner)
    inst._wearer = owner
    inst._bodychanged = function(_, data) OnBodyChanged(inst, owner, data) end
    inst._formchanged = function() ApplyAppearance(inst, owner) end
    inst:ListenForEvent("equip", inst._bodychanged, owner)
    inst:ListenForEvent("unequip", inst._bodychanged, owner)
    inst:ListenForEvent("hitsugaya_bankai_changed", inst._formchanged, owner)
    inst.components.container:Open(owner)
end

local function OnUnequip(inst, owner)
    if inst._bodychanged ~= nil then
        inst:RemoveEventCallback("equip", inst._bodychanged, owner)
        inst:RemoveEventCallback("unequip", inst._bodychanged, owner)
        inst:RemoveEventCallback("hitsugaya_bankai_changed", inst._formchanged, owner)
        inst._bodychanged, inst._formchanged = nil, nil
    end
    if inst._bodybuild ~= nil then
        owner.AnimState:OverrideSymbol("swap_body", inst._bodybuild, inst._bodysymbol)
    else
        owner.AnimState:ClearOverrideSymbol("swap_body")
    end
    inst._bodybuild, inst._bodysymbol, inst._wearer = nil, nil, nil
    inst.components.container:Close(owner)
    owner:PushEvent("refreshcrafting")
end

local function Dapperness(inst, owner)
    local ability = owner.components.hitsugaya_compat
    return owner.prefab == "hitsugaya" and ability ~= nil and ability.transformed and 0 or 1 / 45
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("hitsugayarobe")
    inst.AnimState:SetBuild("hitsugayarobe")
    inst.AnimState:PlayAnimation("anim")
    inst:AddTag("backpack")
    inst.foleysound = "dontstarve/movement/foley/backpack"
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.cangoincontainer = false
    inst.components.inventoryitem.imagename = "hitsugayarobe"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/hitsugayarobe.xml"

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = Robe.SLOT
    inst.components.equippable:SetDappernessFn(Dapperness)
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    inst.components.equippable:SetOnEquipToModel(function(item, owner) item.components.container:Close(owner) end)

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("hitsugayarobe")
    inst:AddComponent("preserver")
    inst.components.preserver:SetPerishRateMultiplier(0.1)
    MakeHauntableLaunch(inst)
    return inst
end

return Prefab("common/inventory/hitsugayarobe", fn, assets)

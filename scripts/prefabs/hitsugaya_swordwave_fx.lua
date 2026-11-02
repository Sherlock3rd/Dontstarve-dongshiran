local assets = { Asset("ANIM", "anim/hitsugaya_swordwave_fx.zip") }

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.persists = false
    inst.AnimState:SetBank("hitsugaya_swordwave_fx")
    inst.AnimState:SetBuild("hitsugaya_swordwave_fx")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetLightOverride(1)
    inst.AnimState:PlayAnimation("wave")
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst:ListenForEvent("animover", inst.Remove)
    inst:DoTaskInTime(1, inst.Remove)
    return inst
end

return Prefab("hitsugaya_swordwave_fx", fn, assets)

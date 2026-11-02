local assets=
{
    Asset("ANIM", "anim/hitsugayasword.zip"),
    Asset("ANIM", "anim/swap_hitsugayasword.zip"),
  
    Asset("ATLAS", "images/inventoryimages/hitsugayasword.xml"),
    Asset("IMAGE", "images/inventoryimages/hitsugayasword.tex"),
}

local prefabs = 
{

}

local function storeincontainer(inst, container)
    if container ~= nil and container.components.container ~= nil then
        inst:ListenForEvent("onputininventory", inst._oncontainerownerchanged, container)
        inst:ListenForEvent("ondropped", inst._oncontainerownerchanged, container)
        inst._container = container
    end
end

local function unstore(inst)
    if inst._container ~= nil then
        inst:RemoveEventCallback("onputininventory", inst._oncontainerownerchanged, inst._container)
        inst:RemoveEventCallback("ondropped", inst._oncontainerownerchanged, inst._container)
        inst._container = nil
    end
end

local function topocket(inst, owner)
    if inst._container ~= owner then
        unstore(inst)
        storeincontainer(inst, owner)
    end
end

local function toground(inst)
    unstore(inst)
end


local function OnEquip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object", "swap_hitsugayasword", "swap_hitsugayasword")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
    inst.components.hitsugaya_soul:SetOwner(owner)
end
  
local function OnUnequip(inst, owner)
		owner.AnimState:Hide("ARM_carry")
		owner.AnimState:Show("ARM_normal")
    inst.components.hitsugaya_soul:SetOwner(nil)
end
 
local function fn()
  
    local inst = CreateEntity()
 
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
     
    MakeInventoryPhysics(inst)   
      
    inst.AnimState:SetBank("hitsugayasword")
    inst.AnimState:SetBuild("hitsugayasword")
    inst.AnimState:PlayAnimation("idle")
 
    inst:AddTag("sharp")
    inst:AddTag("weapon")
    inst._hitsugaya_soul_stage = net_tinybyte(inst.GUID, "hitsugaya_soul.stage", "hitsugaya_soul_dirty")
    if not TheNet:IsDedicated() then
        inst:ListenForEvent("hitsugaya_soul_dirty", function()
            if ThePlayer ~= nil then ThePlayer:PushEvent("refreshcrafting") end
        end)
    end
    inst.entity:SetPristine()
 
    if not TheWorld.ismastersim then
        return inst
    end
 
	
	inst._container = nil
	
    inst._oncontainerownerchanged = function(container)
        topocket(inst, container)
    end

    inst._oncontainerremoved = function()
        unstore(inst)
    end
	
	inst:AddComponent("chosenhitsugaya")
    inst:ListenForEvent("onputininventory", topocket)
    inst:ListenForEvent("ondropped", toground)
     
    inst:AddComponent("weapon")
    inst:AddComponent("planardamage")
    inst:AddComponent("hitsugaya_soul")
	  
    inst:AddComponent("inspectable")
    inst.components.inspectable.descriptionfn = function()
        return inst.components.hitsugaya_soul:GetDescription()
    end
      
    inst:AddComponent("inventoryitem")
	inst.components.inventoryitem.keepondeath = true
    inst.components.inventoryitem.imagename = "hitsugayasword"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/hitsugayasword.xml"
      
    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip( OnEquip )
    inst.components.equippable:SetOnUnequip( OnUnequip )
	inst.components.inventoryitem.keepondeath = true
	
    inst:AddComponent("insulator")
    inst.components.insulator:SetInsulation(TUNING.INSULATION_MED)
    inst.components.insulator:SetSummer()
	
    return inst
end

return  Prefab("common/inventory/hitsugayasword", fn, assets, prefabs) 

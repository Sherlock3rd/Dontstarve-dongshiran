local Data = require("hitsugaya_soul_data")
local Localization = require("hitsugaya_localization")

local Soul = Class(function(self, inst)
    self.inst = inst
    self.stage = 0
    self.owner = nil
    self.onformchanged = function() self:RefreshDamage() end
    self:RefreshDamage()
end)

function Soul:GetStage() return self.stage end

function Soul:SetOwner(owner)
    if self.owner ~= owner then
        if self.owner ~= nil then
            self.inst:RemoveEventCallback("hitsugaya_bankai_changed", self.onformchanged, self.owner)
        end
        self.owner = owner
        if owner ~= nil then self.inst:ListenForEvent("hitsugaya_bankai_changed", self.onformchanged, owner) end
    end
    self:RefreshDamage()
end

function Soul:RefreshDamage()
    local inst = self.inst
    inst.components.weapon:SetDamage(Data.PHYSICAL[self.stage])
    local owner = self.owner
    local bankai = owner ~= nil and owner:IsValid() and owner.prefab == "hitsugaya"
        -- Native Inventory:Equip calls the equip callback before assigning its
        -- hands slot; equippable is already authoritative at that point.
        and inst.components.equippable ~= nil and inst.components.equippable:IsEquipped()
        and inst.components.inventoryitem:GetGrandOwner() == owner
        and owner.components.hitsugaya_compat ~= nil and owner.components.hitsugaya_compat.transformed
    inst.components.planardamage:SetBaseDamage(self.stage == 4 and (bankai and 54 or 36) or 0)
    inst._hitsugaya_soul_stage:set(self.stage)
    self.refresh_pending = nil
end

function Soul:CanUpgrade(doer, expectedstage)
    if self.upgrading then return false end
    if doer == nil or not doer:IsValid() or doer.prefab ~= "hitsugaya"
        or doer:HasTag("playerghost") or doer:HasTag("corpse")
        or doer.components.health == nil or doer.components.health:IsDead()
        or doer.components.inventory == nil
        or doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= self.inst
        or self.inst.components.inventoryitem:GetGrandOwner() ~= doer
        or (doer.components.rider ~= nil and doer.components.rider:IsRiding()) then return false end
    if self.refresh_pending then
        -- A paid stage is authoritative. Retry only its derived properties,
        -- never payment or the stage increment. Guard reentrant mod callbacks.
        self.upgrading = true
        local ok = pcall(self.RefreshDamage, self)
        self.upgrading = nil
        if not ok then return false end
    end
    if self.stage >= 4 or self.stage ~= expectedstage then return false end
    return true
end

-- Called only by the recipe-specific server builder transaction, after native
-- material validation/removal. It never consumes, creates or replaces a sword.
function Soul:FinishUpgrade(doer)
    if not self.upgrading or self.stage >= 4 then return false end
    self.stage = self.stage + 1
    self.refresh_pending = true
    local ok, err = pcall(self.RefreshDamage, self)
    self.upgrading = nil
    if not ok then error(err, 0) end
    doer:PushEvent("hitsugaya_soul_changed", { item = self.inst, stage = self.stage })
    Localization.Say(doer, "SOUL_UP_" .. self.stage)
    return true
end

function Soul:GetDescription()
    return Localization.Text("SOUL_DESC_" .. self.stage, "en")
end

function Soul:OnSave() return { stage = self.stage } end
function Soul:OnLoad(data)
    local stage = data ~= nil and data.stage or 0
    self.stage = type(stage) == "number" and stage == stage and stage >= 0 and stage <= 4
        and math.floor(stage) or 0
    self:RefreshDamage()
end
function Soul:OnRemoveFromEntity()
    if self.owner ~= nil then self.inst:RemoveEventCallback("hitsugaya_bankai_changed", self.onformchanged, self.owner) end
    self.owner = nil
end
return Soul

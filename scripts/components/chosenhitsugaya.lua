local function IsValidOwner(inst, owner)
    return owner:HasTag("hitsugayaspecific")
end

local function OnCheckOwner(inst, self)
    self.checkownertask = nil
    local owner = inst.components.inventoryitem:GetGrandOwner()
    if owner == nil or owner.components.inventory == nil then
        return
    elseif not IsValidOwner(inst, owner) then
        self:Drop()
        end
    end

local function OnChangeOwner(inst, owner)
    local self = inst.components.chosenhitsugaya
    if self.currentowner == owner then
        return
    elseif self.currentowner ~= nil and self.oncontainerpickedup ~= nil then
        inst:RemoveEventCallback("onputininventory", self.oncontainerpickedup, self.currentowner)
        self.oncontainerpickedup = nil
    end

    if self.checkownertask ~= nil then
        self.checkownertask:Cancel()
        self.checkownertask = nil
    end

    self.currentowner = owner

    if owner == nil then
        return
    elseif owner.components.inventoryitem ~= nil then
        self.oncontainerpickedup = function()
            if self.checkownertask ~= nil then
                self.checkownertask:Cancel()
            end
            self.checkownertask = inst:DoTaskInTime(0, OnCheckOwner, self)
        end
        inst:ListenForEvent("onputininventory", self.oncontainerpickedup, owner)
    end
    self.checkownertask = inst:DoTaskInTime(0, OnCheckOwner, self)
end

local ChosenHitsugaya = Class(function(self, inst)
    self.inst = inst

    self.currentowner = nil
    self.oncontainerpickedup = nil
	self.checkownertask = nil
	
    inst:ListenForEvent("onputininventory", OnChangeOwner)
    inst:ListenForEvent("ondropped", OnChangeOwner)
end)

function ChosenHitsugaya:Drop()
    local owner = self.inst.components.inventoryitem:GetGrandOwner()
    if owner ~= nil and owner.components.inventory ~= nil then
        owner.components.inventory:DropItem(self.inst, true, true)
    end
end

function ChosenHitsugaya:OnRemoveFromEntity()
    if self.checkownertask ~= nil then self.checkownertask:Cancel() end
    if self.currentowner ~= nil and self.oncontainerpickedup ~= nil then
        self.inst:RemoveEventCallback("onputininventory", self.oncontainerpickedup, self.currentowner)
    end
    self.inst:RemoveEventCallback("onputininventory", OnChangeOwner)
    self.inst:RemoveEventCallback("ondropped", OnChangeOwner)
end

return ChosenHitsugaya

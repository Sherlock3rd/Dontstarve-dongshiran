-- Eight-slot haori integration. Reuse native slot networking and container actions.
local M = { SLOT = "hitsugaya_robe" }
local Localization = require("hitsugaya_localization")

local function IsRobe(item)
    return item ~= nil and item.prefab == "hitsugayarobe"
end

local function EquipSlot(item)
    return item ~= nil and (item.components.equippable ~= nil
        and item.components.equippable.equipslot
        or item.replica.equippable ~= nil and item.replica.equippable:EquipSlot()) or nil
end

local function IsContainer(item)
    return item ~= nil and (item.components.container ~= nil or item.replica.container ~= nil)
end

function M.Conflicts(inventory, item)
    local slot = EquipSlot(item)
    if slot == M.SLOT then
        return not IsRobe(item) or IsContainer(inventory:GetEquippedItem(EQUIPSLOTS.BODY))
    end
    return slot == EQUIPSLOTS.BODY and IsContainer(item)
        and IsRobe(inventory:GetEquippedItem(M.SLOT))
end

local function Refuse(owner)
    if owner.components.talker ~= nil then
        Localization.Say(owner, "ROBE_CONFLICT")
    end
end

function M.PatchInventory(self)
    if self._hitsugaya_robe_patched then return end
    self._hitsugaya_robe_patched = true
    local oldoverflow, oldequip = self.GetOverflowContainer, self.Equip
    self.GetOverflowContainer = function(inventory, ...)
        local native = oldoverflow(inventory, ...)
        if native ~= nil or inventory.ignoreoverflow then return native end
        local robe = inventory:GetEquippedItem(M.SLOT)
        return IsRobe(robe) and robe.components.container ~= nil
            and robe.components.container.canbeopened and robe.components.container or nil
    end
    self.Equip = function(inventory, item, ...)
        if item ~= nil and M.Conflicts(inventory, item) then
            if inventory.isloading and item.components.inventoryitem ~= nil
                and item.components.inventoryitem.owner == nil then
                -- Native OnLoad ignores the old saved BODY key and uses the new
                -- prefab slot. Conflicting saved items stay safely by the owner.
                item.Transform:SetPosition(inventory.inst.Transform:GetWorldPosition())
                item.components.inventoryitem:OnDropped(true)
            elseif not inventory.isloading then
                Refuse(inventory.inst)
            end
            return false
        end
        local ok = oldequip(inventory, item, ...)
        if ok and IsRobe(item) then
            inventory.inst:PushEvent("setoverflow", { overflow = item })
            inventory.inst:PushEvent("refreshcrafting")
        end
        return ok
    end
end

-- Native inventory_classified prediction closes over a local BODY-only helper.
-- Replace that shared function cell, never any equip-slot or item data. This
-- extends crafting, quick transfer and controller prediction along with UI.
local classified_overflows = setmetatable({}, { __mode = "k" })
function M.PatchClassified(inst)
    if inst._hitsugaya_robe_patched or inst.GetOverflowContainer == nil then return end
    local old = inst.GetOverflowContainer
    local classified_overflow = classified_overflows[old]
    if classified_overflow == nil then
        local replacement = function(classified)
            local native = old(classified)
            if native ~= nil or classified.ignoreoverflow then return native end
            local robe = classified:GetEquippedItem(M.SLOT)
            return IsRobe(robe) and robe.replica.container or nil
        end
        local count = 0
        for _, fn in pairs(inst) do
            if type(fn) == "function" then
                local i = 1
                while true do
                    local name, value = debug.getupvalue(fn, i)
                    if name == nil then break end
                    if name == "GetOverflowContainer" and value == old then
                        debug.setupvalue(fn, i, replacement)
                        count = count + 1
                    end
                    i = i + 1
                end
            end
        end
        assert(count > 0, "Hitsugaya haori: native inventory prediction layout changed")
        classified_overflow = replacement
        classified_overflows[old] = replacement
        classified_overflows[replacement] = replacement
    end
    inst.GetOverflowContainer = classified_overflow
    inst._hitsugaya_robe_patched = true
    for _, name in ipairs({ "EquipActiveItem", "SwapEquipWithActiveItem", "EquipActionItem" }) do
        local original = inst[name]
        if original ~= nil then
            inst[name] = function(classified, item, ...)
                local candidate = name == "EquipActionItem" and item or classified._activeitem
                if candidate ~= nil and M.Conflicts(classified, candidate) then return end
                return original(classified, item, ...)
            end
        end
    end
end

function M.Install(api)
    EQUIPSLOTS.HITSUGAYA_ROBE = M.SLOT
    local containers = require("containers")
    local widget = { slotpos = {}, animbank = "ui_backpack_2x4",
        animbuild = "ui_backpack_2x4", pos = Vector3(-5, -80, 0) }
    for y = 0, 3 do
        table.insert(widget.slotpos, Vector3(-162, -75 * y + 114, 0))
        table.insert(widget.slotpos, Vector3(-87, -75 * y + 114, 0))
    end
    containers.params.hitsugayarobe = {
        widget = widget, issidewidget = true, type = "pack", openlimit = 1,
        itemtestfn = function(container, item)
            return item ~= container.inst and not IsRobe(item) and not IsContainer(item)
        end,
    }
    containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, 8)
    api.AddComponentPostInit("inventory", M.PatchInventory)
    api.AddPrefabPostInit("inventory_classified", function(inst)
        if not TheWorld.ismastersim then M.PatchClassified(inst) end
    end)
    api.AddClassPostConstruct("components/equippable_replica", function(self)
        local old = self.IsRestricted
        self.IsRestricted = function(component, owner, ...)
            local inventory = owner ~= nil and owner.replica.inventory or nil
            return inventory ~= nil and M.Conflicts(inventory, component.inst)
                or old(component, owner, ...)
        end
    end)
    api.AddClassPostConstruct("widgets/inventorybar", function(self)
        if TheNet:GetServerGameMode() == "quagmire" then return end
        for _, info in ipairs(self.equipslotinfo) do
            if info.slot == M.SLOT then return end
        end
        -- An empty slot must not look like an equipped item. Use the native
        -- clothing outline; the real haori icon appears only on an ItemTile.
        self:AddEquipSlot(M.SLOT, "images/hud.xml", "equip_slot_body.tex")
    end)
end

return M

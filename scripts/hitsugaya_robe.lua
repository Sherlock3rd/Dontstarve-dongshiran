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

local function IsBackpack(item)
    if not IsContainer(item) or IsRobe(item) then return false end
    local slot = EquipSlot(item)
    local container = item.components.container or item.replica.container
    -- Preserve BODY-container exclusion and recognize bags moved by slot mods.
    -- A non-container armor piece or an unrelated accessory remains compatible.
    return slot ~= nil and (slot == EQUIPSLOTS.BODY
        or slot == EQUIPSLOTS.BACK or slot == EQUIPSLOTS.BELLY
        or container.type == "pack" or item:HasTag("backpack"))
end

function M.Conflicts(inventory, item)
    local slot = EquipSlot(item)
    if slot == M.SLOT then
        if not IsRobe(item) then return true end
        for _, equippedslot in pairs(EQUIPSLOTS) do
            if equippedslot ~= M.SLOT and IsBackpack(inventory:GetEquippedItem(equippedslot)) then
                return true
            end
        end
        return false
    end
    return IsBackpack(item)
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
local function ExtendOverflow(old)
    local replacement = classified_overflows[old]
    if replacement == nil then
        replacement = function(classified, ...)
            local native = old(classified, ...)
            if native ~= nil or classified.ignoreoverflow then return native end
            local robe = classified:GetEquippedItem(M.SLOT)
            local container = IsRobe(robe) and robe.replica.container or nil
            return container ~= nil and (container.CanBeOpened == nil or container:CanBeOpened()) and container or nil
        end
        classified_overflows[old] = replacement
        classified_overflows[replacement] = replacement
    end
    return replacement
end

function M.PatchClassified(inst)
    if inst._hitsugaya_robe_patched then return true end
    if type(inst.GetOverflowContainer) ~= "function" then return false end
    -- Discover before changing shared cells. Public methods may be wrapped by
    -- other mods; named native helpers inside their closures remain usable.
    -- Never traverse tables/globals or descend into our own replacements.
    local cells, visited, functions, supported, exhausted = {}, {}, 0, false, false
    local function Visit(fn, depth)
        if visited[fn] then return end
        visited[fn] = true
        if classified_overflows[fn] == fn then supported = true; return end
        functions = functions + 1
        if depth > 8 or functions > 512 then exhausted = true; return end
        for i = 1, 256 do
            local name, value = debug.getupvalue(fn, i)
            if name == nil then return end
            if type(value) == "function" then
                if name == "GetOverflowContainer" then
                    cells[#cells + 1] = { fn, i, value }
                    supported = true
                else
                    Visit(value, depth + 1)
                end
            end
        end
        exhausted = true
    end
    for _, fn in pairs(inst) do if type(fn) == "function" then Visit(fn, 0) end end
    if not supported or exhausted then
        -- Unknown prediction layout: do not crash every survivor or partially
        -- patch it. Existing bags stay owned; native interaction stays intact.
        if not inst._hitsugaya_robe_prediction_unavailable then
            print("[Hitsugaya] Haori prediction unavailable; keep native inventory. Move crafting materials to main inventory; haori equip prediction disabled.")
        end
        inst._hitsugaya_robe_prediction_unavailable = true
        return false
    end
    for _, cell in ipairs(cells) do
        debug.setupvalue(cell[1], cell[2], ExtendOverflow(cell[3]))
    end
    inst.GetOverflowContainer = ExtendOverflow(inst.GetOverflowContainer)
    inst._hitsugaya_robe_prediction_unavailable = nil
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
    return true
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
    -- Native spawning runs Any hooks after component and named prefab hooks.
    -- Extend the final inventory/slot-mod methods, before returning the entity
    -- to SpawnSaveRecord/OnLoad. No deferred frame with unpatched saved gear.
    api.AddPrefabPostInitAny(function(inst)
        if inst.components.inventory ~= nil then M.PatchInventory(inst.components.inventory) end
        if inst.prefab == "inventory_classified" and not TheWorld.ismastersim then
            M.PatchClassified(inst)
        end
    end)
    api.AddClassPostConstruct("components/equippable_replica", function(self)
        local old = self.IsRestricted
        self.IsRestricted = function(component, owner, ...)
            local inventory = owner ~= nil and owner.replica.inventory or nil
            if IsRobe(component.inst) and inventory ~= nil and inventory.classified ~= nil
                and inventory.classified._hitsugaya_robe_prediction_unavailable then return true end
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

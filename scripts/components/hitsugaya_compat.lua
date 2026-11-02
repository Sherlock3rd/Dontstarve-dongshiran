local MODIFIER = "hitsugaya_compat"
local FREEZE_COOLDOWN = 10
local BANKAI_OPEN_SANITY = 60
local BANKAI_OPEN_COST = 10
local BANKAI_FLOOR = 20
local MAINTENANCE = require("hitsugaya_soul_data").MAINTENANCE
local CharacterFreeze = require("hitsugaya_freeze")
local Localization = require("hitsugaya_localization")
local AttackSpeed = require("hitsugaya_attackspeed")
local Ice = require("hitsugaya_ice")
local NO_FREEZE_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO" }

local function SpawnEffect(inst, name)
    local fx = SpawnPrefab(name)
    if fx ~= nil then fx.Transform:SetPosition(inst.Transform:GetWorldPosition()) end
    return fx
end

local HitsugayaCompat = Class(function(self, inst)
    self.inst = inst
    self.transformed = false
    self.has_transformed = false
    self.freeze_ready_time = 0
    self.last_request_time = -1
    self.base_overheat = inst.components.temperature.overheattemp
    AttackSpeed.Attach(inst)
    self.ondeath = function() self:SetTransformed(false, true, true) end
    self.onrevive = function() self:SetTransformed(false, true) end
    self.onsanitydelta = function()
        if self.transformed and inst.components.sanity.current <= BANKAI_FLOOR then
            self:SetTransformed(false, true)
        end
    end
    self.onloadtask = inst:DoTaskInTime(0, function()
        self.onloadtask = nil
        self:SetTransformed(self.transformed and not inst:HasTag("playerghost")
            and not inst.components.health:IsDead(), true)
    end)
    inst:ListenForEvent("death", self.ondeath)
    inst:ListenForEvent("ms_becameghost", self.ondeath)
    inst:ListenForEvent("ms_respawnedfromghost", self.onrevive)
    inst:ListenForEvent("respawnfromcorpse", self.onrevive)
    inst:ListenForEvent("sanitydelta", self.onsanitydelta)
end)

function HitsugayaCompat:IsAlive()
    local inst = self.inst
    return inst:IsValid() and inst.prefab == "hitsugaya"
        and not inst:HasTag("playerghost") and not inst:HasTag("corpse")
        and not inst.components.health:IsDead()
end

function HitsugayaCompat:SetTransformed(enabled, silent, skip_visual)
    local inst = self.inst
    enabled = enabled == true and self:IsAlive() and inst.components.sanity.current > BANKAI_FLOOR
    if self.transformed ~= enabled and inst.components.hitsugaya_swordwave ~= nil then
        inst.components.hitsugaya_swordwave:Reset()
    end
    self.transformed = enabled
    self.has_transformed = self.has_transformed or enabled
    inst.transformed = enabled
    inst._hitsugaya_bankai:set(enabled)
    AttackSpeed.SetBankai(inst, enabled)
    inst.components.combat.externaldamagemultipliers:SetModifier(inst, enabled and 1.5 or 1, MODIFIER)
    -- Keep the legacy post-transformation 1% absorption without clobbering other sources.
    inst.components.health.externalabsorbmodifiers:SetModifier(inst,
        enabled and 0.5 or (self.has_transformed and 0.01 or 0), MODIFIER)
    inst.components.locomotor:SetExternalSpeedMultiplier(inst, MODIFIER, enabled and 1.25 or 1)
    -- Both forms use native hunger. Never remove another mod's modifier.
    inst.components.hunger.burnratemodifiers:RemoveModifier(inst, MODIFIER)
    inst.components.temperature.overheattemp = enabled and 50
        or (self.has_transformed and 60 or self.base_overheat)
    inst.overrideskinmode = enabled and "bankai" or nil
    inst.overrideskinmodebuild = enabled and "hitsugayabankai" or nil
    if not skip_visual and self:IsAlive() and inst.components.skinner ~= nil then
        inst.components.skinner:SetSkinMode(enabled and "bankai" or "normal_skin",
            enabled and "hitsugayabankai" or "hitsugaya")
    end
    if enabled then inst:StartUpdatingComponent(self) else inst:StopUpdatingComponent(self) end
    inst:PushEvent("hitsugaya_bankai_changed", { transformed = enabled })
    if not silent then
        SpawnEffect(inst, "splash_snow_fx")
        if enabled then
            SpawnEffect(inst, "collapse_big")
            inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/groundpound")
        end
        Localization.Say(inst, enabled and "BANKAI_ON" or "BANKAI_OFF", 2.5, true)
    end
end

function HitsugayaCompat:IsColdTerrain()
    local affinity = self.inst.components.hitsugaya_affinity
    return affinity ~= nil and affinity:IsColdTerrain()
end

function HitsugayaCompat:GetMaintenanceRate()
    local inventory = self.inst.components.inventory
    local sword = inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    local soul = sword ~= nil and sword.prefab == "hitsugayasword" and sword.components.hitsugaya_soul or nil
    local stage = soul ~= nil and soul:GetStage() or 0
    return (MAINTENANCE[stage] or MAINTENANCE[0]) * (self:IsColdTerrain() and .9 or 1)
end

function HitsugayaCompat:OnUpdate(dt)
    if not self.transformed then return end
    local sanity = self.inst.components.sanity
    if not self:IsAlive() or sanity.current <= BANKAI_FLOOR then
        self:SetTransformed(false, true)
        return
    end
    sanity:DoDelta(-math.min(sanity.current - BANKAI_FLOOR, self:GetMaintenanceRate() * dt), true)
    if self.transformed and sanity.current <= BANKAI_FLOOR then self:SetTransformed(false, true) end
end

function HitsugayaCompat:ToggleTransformed()
    if self.transformed then self:SetTransformed(false); return true end
    if not self:IsAlive() or self.inst.components.sanity.current < BANKAI_OPEN_SANITY then
        Localization.Say(self.inst, "BANKAI_LOW", 2, true)
        return false
    end
    self.inst.components.sanity:DoDelta(-BANKAI_OPEN_COST)
    self:SetTransformed(true)
    return self.transformed
end

function HitsugayaCompat:Freeze()
    if not self:IsAlive() or GetTime() < self.freeze_ready_time then return false end
    local inst = self.inst
    local cost = self:IsColdTerrain() and 8 or 10
    if inst.components.sanity.current < cost
        or (self.transformed and inst.components.sanity.current - cost <= BANKAI_FLOOR) then
        Localization.Say(inst, "FREEZE_LOW", 1, true)
        return false
    end
    self.freeze_ready_time = GetTime() + FREEZE_COOLDOWN
    inst.components.sanity:DoDelta(-cost)
    -- The ring identifies a successful Freeze cast, including legacy combined requests.
    local radius = Ice.GetRadius(inst)
    local ring = SpawnEffect(inst, "hitsugaya_ring_fx")
    if ring ~= nil then ring.Transform:SetScale(radius / 16, radius / 16, radius / 16) end
    local x, y, z = inst.Transform:GetWorldPosition()
    for _, target in ipairs(TheSim:FindEntities(x, y, z, radius, nil, NO_FREEZE_TAGS)) do
        if target:IsValid() and target.components.freezable ~= nil
            and not target:HasTag("player") and not target:HasTag("playerghost") then
            CharacterFreeze.Apply(target, self.transformed)
        end
        if target:IsValid() then
            local burnable = target.components.burnable
            if burnable ~= nil and (burnable:IsBurning() or burnable:IsSmoldering()) then
                burnable:Extinguish(true, -1)
            end
        end
    end
    Localization.Say(inst, "FREEZE_CAST", 2, true)
    inst.SoundEmitter:PlaySound("dontstarve/creatures/hound/icehound_explo", "explosion")
    self:ScheduleCooldownSound(FREEZE_COOLDOWN)
    local ice = TheWorld.components.hitsugaya_iceworld
    if ice ~= nil then
        -- Production is optional; a placement/API failure must not abort combat Freeze.
        local ok, err = pcall(ice.TryCreate, ice, inst)
        if not ok and not ice.error_reported then
            ice.error_reported = true
            print("[Hitsugaya ice] Production skipped: " .. tostring(err))
        end
    end
    return true
end

function HitsugayaCompat:ScheduleCooldownSound(delay)
    if self.cooldown_task ~= nil then
        self.cooldown_task:Cancel()
        self.cooldown_task = nil
    end
    if delay > 0 then
        self.cooldown_task = self.inst:DoTaskInTime(delay, function()
            self.cooldown_task = nil
            if self:IsAlive() then self.inst.SoundEmitter:PlaySound("dontstarve/common/butterfly_trap") end
        end)
    end
end

function HitsugayaCompat:Activate(transform, freeze)
    if not self:IsAlive() or self.inst.sg == nil
        or self.inst.sg:HasStateTag("busy") or self.inst.sg:HasStateTag("dead") then return false end
    -- Deduplicate requests within one simulation frame, not a new gameplay cooldown.
    local now = GetTime()
    if now == self.last_request_time then return false end
    self.last_request_time = now
    local changed = transform and self:ToggleTransformed() or false
    local cast = freeze and self:Freeze() or false
    return changed or cast
end

function HitsugayaCompat:OnSave()
    return {
        transformed = self.transformed,
        has_transformed = self.has_transformed,
        freeze_remaining = math.max(0, self.freeze_ready_time - GetTime()),
    }
end

function HitsugayaCompat:OnLoad(data)
    if data == nil then return end
    self.transformed = data.transformed == true
    self.has_transformed = data.has_transformed == true or self.transformed
    local remaining = type(data.freeze_remaining) == "number"
        and math.min(FREEZE_COOLDOWN, math.max(0, data.freeze_remaining)) or 0
    self.freeze_ready_time = GetTime() + remaining
    self:ScheduleCooldownSound(remaining)
    -- The constructor's deferred task runs after player ghost and skin restoration.
end

function HitsugayaCompat:OnRemoveFromEntity()
    local inst = self.inst
    AttackSpeed.SetBankai(inst, false)
    inst:StopUpdatingComponent(self)
    if self.onloadtask ~= nil then self.onloadtask:Cancel() end
    if self.cooldown_task ~= nil then self.cooldown_task:Cancel() end
    inst:RemoveEventCallback("death", self.ondeath)
    inst:RemoveEventCallback("ms_becameghost", self.ondeath)
    inst:RemoveEventCallback("ms_respawnedfromghost", self.onrevive)
    inst:RemoveEventCallback("respawnfromcorpse", self.onrevive)
    inst:RemoveEventCallback("sanitydelta", self.onsanitydelta)
    inst.components.combat.externaldamagemultipliers:RemoveModifier(inst, MODIFIER)
    inst.components.health.externalabsorbmodifiers:RemoveModifier(inst, MODIFIER)
    inst.components.hunger.burnratemodifiers:RemoveModifier(inst, MODIFIER)
    inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, MODIFIER)
end

return HitsugayaCompat

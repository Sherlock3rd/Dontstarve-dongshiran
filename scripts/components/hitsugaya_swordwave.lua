local SpDamageUtil = require("components/spdamageutil")
local EXCLUDE = { "INLIMBO", "FX", "NOCLICK", "DECOR", "player", "playerghost", "wall", "structure", "companion", "notarget" }
local COS_HALF = math.cos(PI / 4)

local function Eligible(inst, target)
    if target == nil or not target:IsValid() or target:IsInLimbo()
        or target:HasAnyTag(EXCLUDE) or target:HasTag("domesticated")
        or target:HasTag("punchingbag") or target.components.workable ~= nil
        or target.components.health == nil or target.components.health:IsDead()
        or target.components.combat == nil then return false end
    if target.components.follower ~= nil and target.components.follower.leader ~= nil then return false end
    if target.components.domesticatable ~= nil and target.components.domesticatable:IsDomesticated() then return false end
    local victim = target.components.combat.target
    local hostile = target:HasTag("hostile") or (victim ~= nil and
        (victim:HasTag("player") or (victim.components.follower ~= nil
            and victim.components.follower.leader ~= nil and victim.components.follower.leader:HasTag("player"))))
    return hostile and inst.components.combat:CanTarget(target)
end

local function ClearPath(x, z, target)
    local tx, _, tz = target.Transform:GetWorldPosition()
    if not TheWorld.Pathfinder:IsClear(x, 0, z, tx, 0, tz, { ignorewalls = false, ignorecreep = true, allowocean = false }) then return false end
    local platform = TheWorld.Map:GetPlatformAtPoint(x, 0, z)
    for i = 0, 16 do
        local px, pz = x + (tx - x) * i / 16, z + (tz - z) * i / 16
        if TheWorld.Map:GetPlatformAtPoint(px, 0, pz) ~= platform then return false end
        if platform == nil and not TheWorld.Map:IsPassableAtPoint(px, 0, pz) then return false end
    end
    return true
end

local SwordWave = Class(function(self, inst)
    self.inst = inst
    self.count = 0
    self.last_hit = -10
    self.onattack = function(_, data) self:OnAttack(data) end
    self.onhit = function(_, data) self:OnHit(data) end
    self.onreset = function() self:Reset() end
    inst:ListenForEvent("onattackother", self.onattack)
    inst:ListenForEvent("onhitother", self.onhit)
    for _, event in ipairs({ "onmissother", "equip", "unequip", "death", "ms_becameghost", "playerdeactivated" }) do
        inst:ListenForEvent(event, self.onreset)
    end
end)

function SwordWave:Reset()
    self.count, self.last_hit, self.pending = 0, -10, nil
    if self.checktask ~= nil then self.checktask:Cancel(); self.checktask = nil end
    if self.wavetask ~= nil then self.wavetask:Cancel(); self.wavetask = nil end
end

function SwordWave:OnAttack(data)
    local inst = self.inst
    if self.pending ~= nil then self:Reset() end
    local weapon = data ~= nil and data.weapon or nil
    if not inst.components.hitsugaya_compat:IsAlive() or weapon == nil
        or weapon.prefab ~= "hitsugayasword" or data.projectile ~= nil
        or weapon.components.weapon:CanRangedAttack()
        or inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= weapon
        or (inst.components.rider ~= nil and inst.components.rider:IsRiding())
        or not Eligible(inst, data.target) then self:Reset(); return end
    local x, _, z = inst.Transform:GetWorldPosition()
    local tx, _, tz = data.target.Transform:GetWorldPosition()
    local dx, dz = tx - x, tz - z
    local length = math.sqrt(dx * dx + dz * dz)
    if length < 0.001 then
        local rot = inst.Transform:GetRotation() * DEGREES
        dx, dz = math.cos(rot), -math.sin(rot)
    else dx, dz = dx / length, dz / length end
    self.pending = { target = data.target, weapon = weapon, x = x, z = z, dx = dx, dz = dz }
    self.checktask = inst:DoTaskInTime(0, function()
        self.checktask = nil
        if self.pending ~= nil then self:Reset() end -- blocked/invulnerable attacks have no onhitother
    end)
end

function SwordWave:OnHit(data)
    local pending = self.pending
    if pending == nil or data == nil or not data.from_doattack
        or data.target ~= pending.target or data.weapon ~= pending.weapon then return end
    self.pending = nil
    if self.checktask ~= nil then self.checktask:Cancel(); self.checktask = nil end
    if data.redirected ~= nil or (data.damageresolved or 0) <= 0 then self:Reset(); return end
    local now = GetTime()
    self.count = now - self.last_hit <= 3 and self.count + 1 or 1
    self.last_hit = now
    if self.count < 3 then return end
    self.count = 0
    -- Finish the original hit (including death/reflect callbacks) before the wave.
    self.wavetask = self.inst:DoTaskInTime(0, function()
        self.wavetask = nil
        if self.inst.components.hitsugaya_compat:IsAlive()
            and pending.weapon:IsValid()
            and self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == pending.weapon then
            self:Release(pending)
        end
    end)
end

function SwordWave:Release(p)
    local inst = self.inst
    local bankai = inst.components.hitsugaya_compat.transformed
    local radius = bankai and 5 or 4
    local slow = bankai and 0.55 or 0.7
    local fx = SpawnPrefab("hitsugaya_swordwave_fx")
    if fx ~= nil then
        fx.Transform:SetPosition(p.x, 0, p.z)
        fx.Transform:SetRotation(math.atan2(-p.dz, p.dx) * RADIANS)
        local scale = radius / 4
        fx.Transform:SetScale(scale, scale, scale)
    end
    local targets = {}
    for _, target in ipairs(TheSim:FindEntities(p.x, 0, p.z, radius, { "_combat", "_health" }, EXCLUDE)) do
        if Eligible(inst, target) then
            local tx, _, tz = target.Transform:GetWorldPosition()
            local dx, dz = tx - p.x, tz - p.z
            local dsq = dx * dx + dz * dz
            if dsq <= radius * radius and (dsq < 0.000001 or (dx * p.dx + dz * p.dz) / math.sqrt(dsq) >= COS_HALF)
                and ClearPath(p.x, p.z, target) then targets[#targets + 1] = { inst = target, dsq = dsq } end
        end
    end
    table.sort(targets, function(a, b)
        if a.inst == p.target then return b.inst ~= p.target end
        if b.inst == p.target then return false end
        return a.dsq == b.dsq and a.inst.GUID < b.inst.GUID or a.dsq < b.dsq
    end)
    for i = 1, math.min(6, #targets) do
        local target = targets[i].inst
        if Eligible(inst, target) then
            local before = target.components.health.currenthealth
            local damage, special = inst.components.combat:CalcDamage(target, p.weapon)
            -- Native GetAttacked emits onhitother after actual damage/death. Mark
            -- only this synchronous call as a direct wave hit for the reward pool.
            local previous = inst._hitsugaya_wave_target
            inst._hitsugaya_wave_target = target
            local ok, err = pcall(target.components.combat.GetAttacked, target.components.combat,
                inst, damage * 0.3, p.weapon, nil,
                special ~= nil and SpDamageUtil.ApplyMult(special, 0.3) or nil)
            inst._hitsugaya_wave_target = previous
            if not ok then error(err) end
            if target:IsValid() and target.components.health ~= nil and not target.components.health:IsDead()
                and target.components.health.currenthealth < before and target.components.locomotor ~= nil then
                if target.components.hitsugaya_slow == nil then target:AddComponent("hitsugaya_slow") end
                target.components.hitsugaya_slow:Refresh(slow)
            end
        end
    end
end

function SwordWave:OnRemoveFromEntity()
    self:Reset()
    self.inst:RemoveEventCallback("onattackother", self.onattack)
    self.inst:RemoveEventCallback("onhitother", self.onhit)
    for _, event in ipairs({ "onmissother", "equip", "unequip", "death", "ms_becameghost", "playerdeactivated" }) do
        self.inst:RemoveEventCallback(event, self.onreset)
    end
end

return SwordWave

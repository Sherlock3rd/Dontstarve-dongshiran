-- One authoritative ledger on the master shard; caves request reservations.
-- A glacier cannot be mined until its reservation is confirmed by that ledger.
local Ice = require("hitsugaya_ice")
local RESERVATION_TIME = 20
local function String(s) return type(s) == "string" and #s > 0 and #s <= 256 end
local function Master() return tostring(SHARDID.MASTER) end
local function Shard() return tostring(TheShard:GetShardId()) end
local function Alive(player)
    return player ~= nil and player:IsValid() and player.prefab == "hitsugaya"
        and String(player.userid) and not player:HasTag("playerghost")
        and not player:HasTag("corpse") and player.components.health ~= nil
        and not player.components.health:IsDead()
end

local IceWorld = Class(function(self, inst)
    self.inst = inst
    self.records, self.cooldowns = {}, {}
    self.pending, self.glaciers, self.local_cooldowns = {}, {}, {}
    self.evictions = {}
    self.serial = 0
    self.epoch = tostring(inst.GUID) .. ":" .. tostring(math.random(1, 2147483646))
    self.task = inst:DoPeriodicTask(5, function() self:Update() end)
end)

function IceWorld:Send(shard, method, ...)
    if shard == Shard() then
        self[method](self, Shard(), ...)
    elseif Shard_IsWorldAvailable(shard) then
        SendModRPCToShard(GetShardModRPC("hitsugaya_ice", method), shard, ...)
    end
end

function IceWorld:NextID()
    local id
    repeat
        self.serial = self.serial + 1
        id = self.epoch .. ":" .. tostring(self.serial)
    until self.records[id] == nil
    return id
end

function IceWorld:Prune()
    local now = Ice.Now()
    for token, record in pairs(self.records) do
        if record.expires <= now or not record.confirmed and record.deadline <= now then
            self:Release(record.shard, token)
        end
    end
    for owner, ready in pairs(self.cooldowns) do if ready <= now then self.cooldowns[owner] = nil end end
    for owner, ready in pairs(self.local_cooldowns) do if ready <= now then self.local_cooldowns[owner] = nil end end
end

function IceWorld:Request(sender, request, owner)
    if not Shard_IsMaster() or not String(request) or not String(owner) then return end
    self:Prune()
    local count, oldest, now = 0, nil, Ice.Now()
    for _, pending in pairs(self.evictions) do
        if pending.owner == owner then self:Send(sender, "Grant", request, "", 0); return end
    end
    for token, record in pairs(self.records) do
        if record.owner == owner then
            count = count + 1
            if oldest == nil or record.expires < self.records[oldest].expires
                or record.expires == self.records[oldest].expires and token < oldest then oldest = token end
        end
    end
    if (self.cooldowns[owner] or 0) > now then
        self:Send(sender, "Grant", request, "", 0)
        return
    end
    if count >= Ice.LIMIT then
        local old = self.records[oldest]
        if not old.confirmed or not Shard_IsWorldAvailable(old.shard) then
            self:Send(sender, "Grant", request, "", 0)
            return
        end
        -- Keep the old reservation until its shard acknowledges deletion. Never
        -- grant a third glacier optimistically across a disconnected shard.
        self.evictions[oldest] = { owner = owner, shard = sender, request = request,
            old_shard = old.shard, deadline = GetTime() + 8 }
        self:Send(old.shard, "Evict", oldest)
        return
    end
    local token = self:NextID()
    local ready = now + Ice.COOLDOWN
    self.records[token] = { owner = owner, shard = sender, expires = now + Ice.DAYS * TUNING.TOTAL_DAY_TIME,
        deadline = now + RESERVATION_TIME, confirmed = false, ready = ready }
    self.cooldowns[owner] = ready
    self:Send(sender, "Grant", request, token, self.records[token].expires)
end

function IceWorld:Evict(sender, token)
    if sender ~= Master() or not String(token) then return end
    local glacier = self.glaciers[token]
    if glacier ~= nil and glacier:IsValid() then
        -- Remove does not invoke workable's finish callback, so there is no loot.
        glacier:Remove()
    end
    self:Send(Master(), "Evicted", token)
end

function IceWorld:Evicted(sender, token)
    if not Shard_IsMaster() or not String(token) then return end
    local pending = self.evictions[token]
    if pending == nil or pending.old_shard ~= sender then return end
    self.evictions[token] = nil
    self:Release(sender, token)
    if GetTime() <= pending.deadline then
        self:Request(pending.shard, pending.request, pending.owner)
    else
        self:Send(pending.shard, "Grant", pending.request, "", 0)
    end
end

function IceWorld:TryCreate(player)
    if not Alive(player) or not Shard_IsWorldAvailable(Master()) then return false end
    local owner, now = player.userid, Ice.Now()
    if (self.local_cooldowns[owner] or 0) > now then return false end
    if Shard_IsMaster() and (self.cooldowns[owner] or 0) > now then return false end
    for _, p in pairs(self.pending) do if p.owner == owner then return false end end
    local x, _, z = player.Transform:GetWorldPosition()
    local radius = Ice.GetRadius(player)
    if Ice.HasGlacier(x, z, radius) then return false end
    local sx, sz = Ice.FindShore(x, z, radius)
    if sx == nil then return false end
    local request = self:NextID()
    self.pending[request] = { player = player, owner = owner, x = sx, z = sz, cx = x, cz = z,
        radius = radius, bankai = player.components.hitsugaya_compat ~= nil
            and player.components.hitsugaya_compat.transformed == true, deadline = GetTime() + 10 }
    self:Send(Master(), "Request", request, owner)
    return true
end

function IceWorld:Grant(sender, request, token, expires)
    if sender ~= Master() or not String(request) or type(token) ~= "string" then return end
    local pending = self.pending[request]
    self.pending[request] = nil
    if token == "" then return end
    if pending == nil or not Ice.Finite(expires) or expires <= Ice.Now()
        or GetTime() > pending.deadline or not Alive(pending.player)
        or pending.player.userid ~= pending.owner
        or Ice.HasGlacier(pending.cx, pending.cz, pending.radius) or not Ice.Clear(pending.x, pending.z) then
        self:Send(Master(), "Release", token)
        return
    end
    local glacier = SpawnPrefab(Ice.PREFAB)
    if glacier == nil then self:Send(Master(), "Release", token); return end
    glacier.Transform:SetPosition(pending.x, 0, pending.z)
    glacier:SetBankai(pending.bankai)
    glacier.ice_owner, glacier.ice_token, glacier.ice_expires = pending.owner, token, expires
    self.local_cooldowns[pending.owner] = Ice.Now() + Ice.COOLDOWN
    self:Track(glacier)
end

function IceWorld:Validate(sender, token, owner)
    if not Shard_IsMaster() or not String(token) or not String(owner) then return end
    self:Prune()
    local record = self.records[token]
    local valid = record ~= nil and record.shard == sender and record.owner == owner
    if valid then record.confirmed = true end
    self:Send(sender, "Validated", token, valid and record.expires or 0)
end

function IceWorld:Validated(sender, token, expires)
    if sender ~= Master() or not String(token) or not Ice.Finite(expires) then return end
    local glacier = self.glaciers[token]
    if glacier == nil or not glacier:IsValid() then return end
    if expires <= Ice.Now() then glacier:Remove(); return end
    glacier.ice_expires = expires
    glacier.ice_ready = true
    glacier.components.workable:SetWorkable(true)
end

function IceWorld:Release(sender, token)
    if not Shard_IsMaster() or not String(token) then return end
    local record = self.records[token]
    if record == nil or record.shard ~= sender then return end
    -- Only cancelled/unclaimed reservations refund production cooldown. Mining does not.
    if not record.confirmed and self.cooldowns[record.owner] == record.ready then
        self.cooldowns[record.owner] = nil
    end
    self.records[token] = nil
end

function IceWorld:Track(glacier)
    local token = glacier.ice_token
    if not String(token) or not String(glacier.ice_owner) or not Ice.Finite(glacier.ice_expires)
        or glacier.ice_expires <= Ice.Now() then glacier:Remove(); return end
    local existing = self.glaciers[token]
    if existing ~= nil then
        if existing ~= glacier then glacier:Remove() end
        return
    end
    self.glaciers[token] = glacier
    glacier:ListenForEvent("onremove", function()
        if self.glaciers[token] == glacier then
            self.glaciers[token] = nil
            if not self.removing then self:Send(Master(), "Release", token) end
        end
    end)
    self:Send(Master(), "Validate", token, glacier.ice_owner)
end

function IceWorld:Update()
    if Shard_IsMaster() then self:Prune() end
    for token, pending in pairs(self.evictions) do
        if GetTime() > pending.deadline then
            self.evictions[token] = nil
            self:Send(pending.shard, "Grant", pending.request, "", 0)
        end
    end
    for request, pending in pairs(self.pending) do
        if GetTime() > pending.deadline then self.pending[request] = nil end
    end
    for _, glacier in pairs(self.glaciers) do
        if glacier.ice_expires <= Ice.Now() then
            glacier:Remove()
        elseif not glacier.ice_ready then
            self:Send(Master(), "Validate", glacier.ice_token, glacier.ice_owner)
        end
    end
    for owner, ready in pairs(self.local_cooldowns) do
        if ready <= Ice.Now() then self.local_cooldowns[owner] = nil end
    end
end

function IceWorld:OnSave()
    if Shard_IsMaster() then
        return { records = self.records, cooldowns = self.cooldowns, epoch = self.epoch, serial = self.serial }
    end
end

function IceWorld:OnLoad(data)
    if not Shard_IsMaster() or type(data) ~= "table" then return end
    if String(data.epoch) and Ice.Finite(data.serial) and data.serial >= 0 and data.serial < 1e12 then
        self.epoch, self.serial = data.epoch, math.floor(data.serial)
    end
    for token, r in pairs(type(data.records) == "table" and data.records or {}) do
        if String(token) and type(r) == "table" and String(r.owner) and String(r.shard)
            and Ice.Finite(r.expires) and Ice.Finite(r.deadline) and Ice.Finite(r.ready) then
            self.records[token] = { owner = r.owner, shard = r.shard, expires = r.expires,
                deadline = r.deadline, ready = r.ready, confirmed = r.confirmed == true }
        end
    end
    for owner, ready in pairs(type(data.cooldowns) == "table" and data.cooldowns or {}) do
        if String(owner) and Ice.Finite(ready) then self.cooldowns[owner] = ready end
    end
end

function IceWorld:OnRemoveFromEntity()
    self.removing = true
    self.task:Cancel()
end

return IceWorld

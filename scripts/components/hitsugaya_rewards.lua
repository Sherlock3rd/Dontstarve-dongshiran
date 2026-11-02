-- Server-authoritative participation rewards. Transient victim claims are not
-- saved; each player's rolling allowance is saved even when dead or unequipped.
local POOLS = {
    hound = 6, spider = 6, spider_warrior = 6,
    knight = 12, bishop = 12, rook = 12,
    deerclops = 24, bearger = 24, dragonfly = 24, beequeen = 24,
    minotaur = 24, alterguardian_phase3 = 24,
}
local WINDOW, LIMIT, PARTICIPATION, RANGE_SQ = 60, 24, 10, 400

local function AllowedTarget(target)
    if target == nil or not target:IsValid() or target._hitsugaya_no_rewards
        or POOLS[target.prefab] == nil or target.components.health == nil
        or target:HasTag("player") or target:HasTag("companion")
        or target:HasTag("punchingbag") or target:HasTag("domesticated") then return false end
    local follower = target.components.follower
    local domestic = target.components.domesticatable
    return (follower == nil or follower:GetLeader() == nil)
        and (domestic == nil or not domestic:IsDomesticated())
end

local function MarkOwnedTarget(target)
    if target == nil or not target:IsValid() or POOLS[target.prefab] == nil then return end
    local follower = target.components.follower
    local domestic = target.components.domesticatable
    if target:HasTag("companion") or target:HasTag("domesticated")
        or (follower ~= nil and follower:GetLeader() ~= nil)
        or (domestic ~= nil and domestic:IsDomesticated()) then
        -- Native follower.onattacked clears the leader BEFORE onhitother. Keep
        -- the pre-hit ownership verdict for this entity's current lifetime.
        target._hitsugaya_no_rewards = true
    end
end

local function Qualified(player, x, z)
    if not player:IsValid() then return false end
    local ability = player.components.hitsugaya_compat
    if ability == nil or not ability.transformed or not ability:IsAlive() then return false end
    local px, _, pz = player.Transform:GetWorldPosition()
    return (px - x) ^ 2 + (pz - z) ^ 2 <= RANGE_SQ
end

local function Settle(record)
    if record.settled then return end
    record.settled = true
    local count = 0
    for _ in pairs(record.qualified) do count = count + 1 end
    if count == 0 then return end
    local share = record.pool / count
    for player in pairs(record.qualified) do
        if player:IsValid() and player.components.hitsugaya_rewards ~= nil then
            player.components.hitsugaya_rewards:Credit(share)
        end
    end
end

local function OnDeath(target)
    local record = target._hitsugaya_reward_claim
    if record == nil or record.death_time ~= nil or not AllowedTarget(target) then return end
    record.death_time = GetTime()
    local x, _, z = target.Transform:GetWorldPosition()
    record.x, record.z = x, z
    record.qualified = {}
    for player, time in pairs(record.hits) do
        if record.death_time - time <= PARTICIPATION and Qualified(player, record.x, record.z) then
            record.qualified[player] = true
        end
    end
    -- Native combat emits onhitother AFTER death. Let that same synchronous
    -- attack add the lethal hitter before splitting this one death's pool.
    TheWorld:DoTaskInTime(0, function() Settle(record) end)
end

local Rewards = Class(function(self, inst)
    self.inst = inst
    self.credits = {}
    self.onattack = function(_, data) self:OnAttack(data) end
    self.onhit = function(_, data) self:OnHit(data) end
    inst:ListenForEvent("onattackother", self.onattack)
    inst:ListenForEvent("onareaattackother", self.onattack)
    inst:ListenForEvent("onhitother", self.onhit)
end)

function Rewards:OnAttack(data)
    self.pending = nil
    if data == nil or data.target == nil then return end
    MarkOwnedTarget(data.target)
    self.pending = { target = data.target, weapon = data.weapon,
        time = GetTime(), allowed = AllowedTarget(data.target) }
end

function Rewards:Prune()
    local now, used = GetTime(), 0
    for i = #self.credits, 1, -1 do
        local entry = self.credits[i]
        if entry.expires <= now then table.remove(self.credits, i)
        else used = used + entry.amount end
    end
    return used
end

function Rewards:Credit(amount)
    local sanity = self.inst.components.sanity
    if sanity == nil then return 0 end
    local requested = math.min(amount, math.max(0, LIMIT - self:Prune()),
        math.max(0, sanity:GetMaxWithPenalty() - sanity.current))
    if requested <= 0 then return 0 end
    local before = sanity.current
    sanity:DoDelta(requested)
    local actual = math.max(0, sanity.current - before)
    if actual > 0 then
        self.credits[#self.credits + 1] = { amount = actual, expires = GetTime() + WINDOW }
    end
    return actual
end

function Rewards:OnHit(data)
    local pending = self.pending
    local direct = data ~= nil and data.from_doattack and pending ~= nil
        and pending.target == data.target and pending.weapon == data.weapon
        and pending.time == GetTime() and pending.allowed
    if data ~= nil and pending ~= nil and pending.target == data.target then self.pending = nil end
    if data == nil or data.redirected ~= nil or (data.damageresolved or 0) <= 0
        or not (direct or self.inst._hitsugaya_wave_target == data.target)
        or not AllowedTarget(data.target) then return end
    local target = data.target
    local record = target._hitsugaya_reward_claim
    if record == nil then
        record = { pool = POOLS[target.prefab], hits = setmetatable({}, { __mode = "k" }) }
        target._hitsugaya_reward_claim = record
        target:ListenForEvent("death", OnDeath)
    end
    if record.settled then return end
    local now = GetTime()
    record.hits[self.inst] = now
    if target.components.health:IsDead() then
        if record.death_time == nil then OnDeath(target) end
        if record.death_time == now and Qualified(self.inst, record.x, record.z) then
            record.qualified[self.inst] = true
        end
    end
end

function Rewards:OnSave()
    self:Prune()
    local credits = {}
    for _, entry in ipairs(self.credits) do
        credits[#credits + 1] = { amount = entry.amount, remaining = entry.expires - GetTime() }
    end
    return { credits = credits }
end

function Rewards:OnLoad(data)
    self.credits = {}
    if type(data) ~= "table" or type(data.credits) ~= "table" then return end
    local used = 0
    for _, entry in ipairs(data.credits) do
        if type(entry) == "table" and type(entry.amount) == "number" and entry.amount > 0
            and type(entry.remaining) == "number" and entry.remaining > 0 and used < LIMIT then
            local amount = math.min(LIMIT - used, entry.amount)
            self.credits[#self.credits + 1] = { amount = amount,
                expires = GetTime() + math.min(WINDOW, entry.remaining) }
            used = used + amount
        end
    end
end

function Rewards:OnRemoveFromEntity()
    self.pending = nil
    self.inst:RemoveEventCallback("onattackother", self.onattack)
    self.inst:RemoveEventCallback("onareaattackother", self.onattack)
    self.inst:RemoveEventCallback("onhitother", self.onhit)
end

return Rewards

-- Character-local food and terrain affinity. Uses the native eater's final-stat
-- hook so spoilage, seasoning, food memory and other absorption rules run first.
local COLD_FOODS = { icecream = true, watermelonicle = true, ceviche = true }
local COLD_FOOD_DURATION = 120
local ABSORB_KEY = "hitsugaya_compat"

local function IsColdFood(food)
    return food ~= nil and COLD_FOODS[food.food_basename or food.prefab] == true
end

local function Pack(...)
    return { n = select("#", ...), ... }
end

local HitsugayaAffinity = Class(function(self, inst)
    self.inst = inst
    self.cold_food_until = 0
    self.removed = false
    local eater = inst.components.eater
    if eater ~= nil then
        self.previous_food_stats = eater.custom_stats_mod_fn
        self.food_stats = function(owner, health, hunger, sanity, food, feeder)
            if self.previous_food_stats ~= nil then
                health, hunger, sanity = self.previous_food_stats(owner, health, hunger, sanity, food, feeder)
            end
            if not self.removed and IsColdFood(food) then
                hunger = hunger > 0 and hunger * 1.5 or hunger
                sanity = sanity > 0 and sanity * 1.25 or sanity
            end
            return health, hunger, sanity
        end
        eater.custom_stats_mod_fn = self.food_stats
    end

    -- Health's external absorption list is additive. For this synchronous fire
    -- call only, replace OUR normal/Bankai contribution with the intended final
    -- fire contribution. Never multiply another .5 onto Bankai's existing .5,
    -- never remove another source, and never override a death callback's change.
    local health = inst.components.health
    if health ~= nil then
        self.previous_fire_damage = health.DoFireDamage
        self.fire_damage = function(component, ...)
            local modifiers = component.externalabsorbmodifiers
            if self.removed or not self:IsProtected()
                or modifiers == nil or modifiers.CalculateModifierFromSource == nil then
                return self.previous_fire_damage(component, ...)
            end
            local previous = modifiers:CalculateModifierFromSource(inst, ABSORB_KEY)
            local desired = inst.transformed and 0.5 or 0.25
            -- Do not reduce a stronger protection supplied through this key.
            local applied = math.max(previous, desired)
            if applied == previous then return self.previous_fire_damage(component, ...) end
            modifiers:SetModifier(inst, applied, ABSORB_KEY)
            local result = Pack(pcall(self.previous_fire_damage, component, ...))
            if modifiers:CalculateModifierFromSource(inst, ABSORB_KEY) == applied then
                modifiers:SetModifier(inst, previous, ABSORB_KEY)
            end
            if not result[1] then error(result[2], 0) end
            return unpack(result, 2, result.n)
        end
        health.DoFireDamage = self.fire_damage
    end

    self.oneat = function(_, data)
        local food = data ~= nil and data.food or nil
        local perish = food ~= nil and food.components.perishable or nil
        if self:IsAlive() and IsColdFood(food) and perish ~= nil and perish:GetPercent() >= 0.5 then
            self.cold_food_until = GetTime() + COLD_FOOD_DURATION
        end
    end
    self.ondeath = function() self.cold_food_until = 0 end
    inst:ListenForEvent("oneat", self.oneat)
    inst:ListenForEvent("death", self.ondeath)
    inst:ListenForEvent("ms_becameghost", self.ondeath)
    self.loadtask = inst:DoTaskInTime(0, function()
        self.loadtask = nil
        if not self:IsAlive() then self.cold_food_until = 0 end
    end)
end)

function HitsugayaAffinity:IsAlive()
    return not self.removed and self.inst:IsValid() and not self.inst:HasTag("playerghost")
        and not self.inst:HasTag("corpse") and self.inst.components.health ~= nil
        and not self.inst.components.health:IsDead()
end

function HitsugayaAffinity:GetColdFoodRemaining()
    return math.max(0, self.cold_food_until - GetTime())
end

function HitsugayaAffinity:HasColdFood()
    return self:IsAlive() and self:GetColdFoodRemaining() > 0
end

function HitsugayaAffinity:IsColdTerrain()
    if self.removed or not self.inst:IsValid() or TheWorld == nil or TheWorld.Map == nil then return false end
    if self.inst:GetCurrentPlatform() ~= nil then return false end
    local map = TheWorld.Map
    local x, y, z = self.inst.Transform:GetWorldPosition()
    -- This is the current native OCEAN_ICE tile query, not proximity to ice FX.
    if map.IsOceanIceAtPoint ~= nil and map:IsOceanIceAtPoint(x, y, z) then return true end
    if TheWorld:HasTag("cave") or TheWorld.state == nil
        or type(TheWorld.state.snowlevel) ~= "number" or TheWorld.state.snowlevel <= 0.15
        or map.IsLandTileAtPoint == nil or not map:IsLandTileAtPoint(x, y, z)
        or map.GetTileAtPoint == nil or GetTileInfo == nil then return false end
    local tile = map:GetTileAtPoint(x, y, z)
    local info = tile ~= nil and GetTileInfo(tile) or nil
    -- Same overlay rule as worldtiledefs' native snow footstep selection.
    return info ~= nil and not info.nogroundoverlays
end

function HitsugayaAffinity:IsProtected()
    return self:IsAlive() and (self:HasColdFood() or self:IsColdTerrain())
end

function HitsugayaAffinity:OnSave()
    return { cold_food_remaining = self:IsAlive() and self:GetColdFoodRemaining() or 0 }
end

function HitsugayaAffinity:OnLoad(data)
    local remaining = data ~= nil and data.cold_food_remaining or nil
    if type(remaining) ~= "number" or remaining ~= remaining then remaining = 0 end
    self.cold_food_until = GetTime() + math.max(0, math.min(COLD_FOOD_DURATION, remaining))
end

function HitsugayaAffinity:OnRemoveFromEntity()
    self.removed = true
    if self.loadtask ~= nil then self.loadtask:Cancel(); self.loadtask = nil end
    local inst = self.inst
    inst:RemoveEventCallback("oneat", self.oneat)
    inst:RemoveEventCallback("death", self.ondeath)
    inst:RemoveEventCallback("ms_becameghost", self.ondeath)
    local eater, health = inst.components.eater, inst.components.health
    if eater ~= nil and eater.custom_stats_mod_fn == self.food_stats then eater.custom_stats_mod_fn = self.previous_food_stats end
    if health ~= nil and health.DoFireDamage == self.fire_damage then health.DoFireDamage = self.previous_fire_damage end
end

return HitsugayaAffinity

local CharacterFreeze = require("hitsugaya_freeze")
local M = {}
local function Eligible(self, doer)
    local inst = self.inst
    return doer ~= nil and doer:IsValid() and doer.prefab == "hitsugaya"
        and doer:HasTag("playerghost") and inst:IsValid()
        and not inst:HasTag("player") and not inst:HasTag("playerghost")
        and not inst:HasTag("INLIMBO") and not inst:HasTag("structure") and not inst:HasTag("wall")
        and inst.components.combat ~= nil and inst.components.health ~= nil
        and not inst.components.health:IsDead() and inst.components.freezable ~= nil
        and not inst.components.freezable:IsFrozen()
end

function M.Patch(self)
    if self._hitsugaya_haunt then return end
    self._hitsugaya_haunt = true
    local original = self.DoHaunt
    self.DoHaunt = function(component, doer, ...)
        local freeze = (component.cooldowntimer or 0) <= 0 and Eligible(component, doer)
        local result = original(component, doer, ...)
        -- Preserve original haunt transformations/removals and target cooldowns.
        if freeze and Eligible(component, doer) then
            -- Same coldness as Z; total five seconds, with native early breaks.
            CharacterFreeze.ApplyHaunt(component.inst)
        end
        return result
    end
end

function M.Install(api) api.AddComponentPostInit("hauntable", M.Patch) end
return M

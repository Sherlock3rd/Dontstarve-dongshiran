local KEY = "hitsugaya_sword_wave"
local HitsugayaSlow = Class(function(self, inst)
    self.inst = inst
    self.ondeath = function() inst:RemoveComponent("hitsugaya_slow") end
    inst:ListenForEvent("death", self.ondeath)
end)

function HitsugayaSlow:UpdateMultiplier()
    self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, KEY,
        self.bankai_task ~= nil and 0.55 or 0.7)
end

function HitsugayaSlow:Refresh(multiplier)
    -- Each strength has its own two-second lifetime. A normal hit must neither
    -- weaken an active Bankai slow nor prolong its stronger duration.
    local slot = multiplier == 0.55 and "bankai_task" or "normal_task"
    if self[slot] ~= nil then self[slot]:Cancel() end
    self[slot] = self.inst:DoTaskInTime(2, function()
        self[slot] = nil
        if self.bankai_task == nil and self.normal_task == nil then
            self.inst:RemoveComponent("hitsugaya_slow")
        else
            self:UpdateMultiplier()
        end
    end)
    self:UpdateMultiplier()
end

function HitsugayaSlow:OnRemoveFromEntity()
    if self.normal_task ~= nil then self.normal_task:Cancel() end
    if self.bankai_task ~= nil then self.bankai_task:Cancel() end
    self.inst:RemoveEventCallback("death", self.ondeath)
    if self.inst.components.locomotor ~= nil then
        self.inst.components.locomotor:RemoveExternalSpeedMultiplier(self.inst, KEY)
    end
end

return HitsugayaSlow

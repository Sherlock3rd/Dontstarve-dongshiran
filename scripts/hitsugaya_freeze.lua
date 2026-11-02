-- Instance-local adapter: never change default wearofftime or other cold sources.
local function Install(freezable)
    if freezable._hitsugaya_adapter then return end
    freezable._hitsugaya_adapter = true
    local freeze, thaw, start = freezable.Freeze, freezable.Thaw, freezable.StartWearingOff
    freezable.StartWearingOff = function(self, duration, ...)
        if self._hitsugaya_phase and self._hitsugaya_half then
            duration = self._hitsugaya_duration or (duration or self.wearofftime) * 0.5
        end
        return start(self, duration, ...)
    end
    freezable.Freeze = function(self, duration, ...)
        local oldhalf, oldphase, oldtask = self._hitsugaya_half, self._hitsugaya_phase, self.wearofftask
        local oldduration = self._hitsugaya_duration
        self._hitsugaya_half = self._hitsugaya_cast == true
        self._hitsugaya_duration = self._hitsugaya_half and self._hitsugaya_cast_duration or nil
        self._hitsugaya_phase = true
        local result = freeze(self, duration, ...)
        self._hitsugaya_phase = oldphase
        -- Invisible/dead targets may reject Freeze without starting a new timer.
        if self.wearofftask == oldtask then
            self._hitsugaya_half, self._hitsugaya_duration = oldhalf, oldduration
        end
        return result
    end
    freezable.Thaw = function(self, duration, ...)
        local oldphase = self._hitsugaya_phase
        self._hitsugaya_phase = true
        local result = thaw(self, duration, ...)
        self._hitsugaya_phase = oldphase
        return result
    end
end

local function ApplyWithDuration(target, duration)
    local freezable = target.components.freezable
    if freezable == nil then return end
    Install(freezable)
    local previous, previousduration = freezable._hitsugaya_cast, freezable._hitsugaya_cast_duration
    freezable._hitsugaya_cast = true
    freezable._hitsugaya_cast_duration = duration
    freezable:AddColdness(4, duration or 7)
    freezable._hitsugaya_cast, freezable._hitsugaya_cast_duration = previous, previousduration
end

return {
    Apply = function(target, bankai)
        local total = bankai and 10 or 3
        if target:HasTag("epic") then total = total * 0.5 end
        -- Split the total across native frozen and thawing phases.
        ApplyWithDuration(target, total * 0.5)
    end,
    -- Two native phases: 2.5 s frozen + 2.5 s thawing, before native resistance.
    ApplyHaunt = function(target) ApplyWithDuration(target, 2.5) end,
}

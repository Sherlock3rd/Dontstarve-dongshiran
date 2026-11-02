-- Instance-local adapter: never change default wearofftime or other cold sources.
local function Install(freezable)
    if freezable._hitsugaya_adapter then return end
    freezable._hitsugaya_adapter = true
    local freeze, thaw, start = freezable.Freeze, freezable.Thaw, freezable.StartWearingOff
    freezable.StartWearingOff = function(self, duration, ...)
        if self._hitsugaya_phase and self._hitsugaya_half then
            duration = (duration or self.wearofftime) * 0.5
        end
        return start(self, duration, ...)
    end
    freezable.Freeze = function(self, duration, ...)
        local oldhalf, oldphase, oldtask = self._hitsugaya_half, self._hitsugaya_phase, self.wearofftask
        self._hitsugaya_half = self._hitsugaya_cast == true
        self._hitsugaya_phase = true
        local result = freeze(self, duration, ...)
        self._hitsugaya_phase = oldphase
        -- Invisible/dead targets may reject Freeze without starting a new timer.
        if self.wearofftask == oldtask then self._hitsugaya_half = oldhalf end
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

local function Apply(target)
    local freezable = target.components.freezable
    if freezable == nil then return end
    Install(freezable)
    local previous = freezable._hitsugaya_cast
    freezable._hitsugaya_cast = true
    freezable:AddColdness(4, 7)
    freezable._hitsugaya_cast = previous
end

return { Apply = Apply }

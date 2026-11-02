-- Keep native attack callbacks and state names on both authority and prediction.
local M = { MULTIPLIER = 1.3 }

function M.Attach(inst)
    local combat = inst.components.combat
    if combat._hitsugaya_period ~= nil then return end
    local state = { base = combat.min_attack_period, enabled = false, setter = combat.SetAttackPeriod }
    combat._hitsugaya_period = state
    combat.SetAttackPeriod = function(self, period)
        state.base = period
        return state.setter(self, period / (state.enabled and M.MULTIPLIER or 1))
    end
end

function M.SetBankai(inst, enabled)
    M.Attach(inst)
    local combat = inst.components.combat
    local state = combat._hitsugaya_period
    state.enabled = enabled == true
    state.setter(combat, state.base / (state.enabled and M.MULTIPLIER or 1))
end

function M.PatchGraph(sg)
    local state = sg.states.attack
    if state == nil or state._hitsugaya_speed then return end
    state._hitsugaya_speed = true
    local enter, update, leave = state.onenter, state.onupdate, state.onexit
    state.onenter = function(inst, ...)
        enter(inst, ...)
        if inst.sg.currentstate ~= state or inst.prefab ~= "hitsugaya"
            or inst._hitsugaya_bankai == nil or not inst._hitsugaya_bankai:value() then return end
        inst.sg.statemem.hitsugaya_fastattack = true
        inst.AnimState:SetDeltaTimeMultiplier(M.MULTIPLIER)
        if inst.sg.timeout ~= nil then
            local combat = inst.components.combat
            local period = combat ~= nil and combat.min_attack_period or inst.replica.combat:MinAttackPeriod()
            inst.sg:SetTimeout(math.max(inst.sg.timeout / M.MULTIPLIER, period))
        end
    end
    state.onupdate = function(inst, dt, ...)
        if update ~= nil then
            return update(inst, dt * (inst.sg.statemem.hitsugaya_fastattack and M.MULTIPLIER or 1), ...)
        end
    end
    state.onexit = function(inst, ...)
        if inst.sg.statemem.hitsugaya_fastattack then inst.AnimState:SetDeltaTimeMultiplier(1) end
        if leave ~= nil then return leave(inst, ...) end
    end
    local timeline = {}
    for _, event in ipairs(state.timeline or {}) do
        local fn = event.fn
        local fast = TimeEvent(event.time / M.MULTIPLIER, function(inst)
            if inst.sg.statemem.hitsugaya_fastattack then return fn(inst) end
        end)
        fast.hitsugaya_order = #timeline + 1
        timeline[#timeline + 1] = fast
        local normal = TimeEvent(event.time, function(inst)
            if not inst.sg.statemem.hitsugaya_fastattack then return fn(inst) end
        end)
        normal.hitsugaya_order = #timeline + 1
        timeline[#timeline + 1] = normal
    end
    table.sort(timeline, function(a, b)
        return a.time < b.time or a.time == b.time and a.hitsugaya_order < b.hitsugaya_order
    end)
    state.timeline = timeline
end

function M.Install(api)
    api.AddStategraphPostInit("wilson", M.PatchGraph)
    api.AddStategraphPostInit("wilson_client", M.PatchGraph)
end

return M

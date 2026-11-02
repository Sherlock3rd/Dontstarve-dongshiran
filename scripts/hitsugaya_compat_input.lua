-- Client input only. Never modify shared screen/widget classes.
local function CanUseInput(inst)
    if inst ~= ThePlayer or not inst:IsValid() or inst:HasTag("playerghost")
        or inst:HasTag("corpse") or inst.HUD == nil or TheFrontEnd == nil
        or IsPaused() or TheNet:IsServerPaused() then return false end
    if TheFrontEnd:GetActiveScreen() ~= inst.HUD then return false end
    if inst.HUD:IsChatInputScreenOpen() or inst.HUD:IsConsoleScreenOpen()
        or inst.HUD:IsCraftingOpen() then return false end
    return inst.components.playercontroller ~= nil and inst.components.playercontroller:IsEnabled()
end

local function Attach(inst, key)
    local handler
    local function Detach()
        if handler ~= nil then
            handler:Remove()
            handler = nil
        end
    end
    local function Activate()
        Detach()
        if inst ~= ThePlayer then return end
        handler = TheInput:AddKeyHandler(function(pressed, down)
            if not down and (pressed == key or pressed == KEY_Z) and CanUseInput(inst) then
                SendModRPCToServer(GetModRPC("hitsugaya_compat", "activate"), pressed == key, pressed == KEY_Z)
            end
        end)
    end
    inst:ListenForEvent("playeractivated", Activate)
    inst:ListenForEvent("playerdeactivated", Detach)
    inst:ListenForEvent("onremove", Detach)
    inst:DoTaskInTime(0, function()
        if inst == ThePlayer and handler == nil then Activate() end
    end)
end

return { Attach = Attach }

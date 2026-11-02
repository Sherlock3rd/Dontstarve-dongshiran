-- Isolated offline server fixture only. Never include in a runtime package.
local Ice = require("hitsugaya_ice")
local M = {}
local function Check(label, value)
    assert(value, "ABILITY_NATIVE_FAIL " .. label)
    print("ABILITY_NATIVE_PASS " .. label)
end
local function Near(a,b) return math.abs(a-b)<0.0001 end
function M.Run()
    local x,z
    for _, e in pairs(Ents) do
        if e.prefab=="pond" or e.prefab=="pond_cave" or e.prefab=="pond_mos" then
            local px,_,pz=e.Transform:GetWorldPosition();x,z=Ice.FindShore(px,pz)
            if x~=nil then break end
        end
    end
    Check("test ground found",x~=nil)
    local p=SpawnPrefab("hitsugaya")
    p.persists=false;p.userid="CODEX_ABILITY_"..tostring(TheShard:GetShardId())
    p.Transform:SetPosition(x,0,z)
    p.components.health:SetInvincible(true)
    p.components.sanity:SetPercent(1)
    local ability=p.components.hitsugaya_compat
    local sword=SpawnPrefab("hitsugayasword")
    p.components.inventory:Equip(sword)
    -- Constructor/load callbacks finish before checking the real player stategraph.
    TheWorld:DoTaskInTime(1,function()
        ability:SetTransformed(false,true,true)
        local original=p.components.combat.min_attack_period
        p.components.combat:ResetCooldown();p.sg:GoToState("attack")
        local normal=p.sg.timeout
        Check("normal attack uses native state",not p.sg.statemem.hitsugaya_fastattack)
        p.sg:GoToState("idle")
        ability:SetTransformed(true,true,true)
        Check("Bankai attack period divided by 1.3",Near(p.components.combat.min_attack_period,original/1.3))
        p.components.combat:ResetCooldown();p.sg:GoToState("attack")
        Check("Bankai native attack timeline enabled",p.sg.statemem.hitsugaya_fastattack)
        Check("native sword attack duration divided by 1.3",Near(p.sg.timeout,normal/1.3))
        p.sg:GoToState("idle")
        ability:SetTransformed(false,true,true)
        Check("Bankai off restores attack period",Near(p.components.combat.min_attack_period,original))

        local robe=SpawnPrefab("hitsugayarobe")
        Check("native eight container slots",robe.components.container:GetNumSlots()==8)
        Check("native preserver multiplier is ten percent",Near(robe.components.preserver:GetPerishRateMultiplier(nil),0.1))
        -- Native saves serialize occupied slots, not the configured slot count.
        -- Filling only slots 1..6 reproduces the old six-slot save payload.
        for i=1,6 do robe.components.container:GiveItem(SpawnPrefab("carrot"),i) end
        local saved=robe:GetSaveRecord()
        for i=1,6 do local food=robe.components.container:RemoveItemBySlot(i);if food then food:Remove() end end
        robe:Remove();robe=SpawnSaveRecord(saved)
        Check("six slot save restores as eight slots",robe.components.container:GetNumSlots()==8)
        for i=1,6 do Check("saved item preserved in slot "..i,robe.components.container:GetItemInSlot(i)~=nil) end
        Check("new seventh and eighth slots empty",robe.components.container:GetItemInSlot(7)==nil and robe.components.container:GetItemInSlot(8)==nil)
        robe.components.container:GiveItem(SpawnPrefab("carrot"),8)
        Check("eighth native slot accepts food",robe.components.container:GetItemInSlot(8)~=nil)

        local function Plant(dx,smolder)
            local v=SpawnPrefab("grass");v.Transform:SetPosition(x+dx,0,z)
            if smolder then v.components.burnable:StartWildfire() else v.components.burnable:Ignite() end
            if v.components.propagator then v.components.propagator:StopSpreading() end
            return v
        end
        local near=Plant(9,false);local smoking=Plant(-9,true)
        local far=Plant(15,false);local outside=Plant(21,false)
        Check("native fire fixtures lit",near.components.burnable:IsBurning() and far.components.burnable:IsBurning())
        Check("native smolder fixture active",smoking.components.burnable:IsSmoldering())
        ability.freeze_ready_time=0;p.components.sanity:SetPercent(1)
        Check("normal Freeze succeeds",ability:Freeze())
        Check("normal radius ten extinguishes and stops smolder",not near.components.burnable:IsBurning() and not smoking.components.burnable:IsSmoldering())
        Check("normal Freeze leaves fifteen-unit fire alone",far.components.burnable:IsBurning())
        ability:SetTransformed(true,true,true);ability.freeze_ready_time=0
        Check("Bankai Freeze succeeds",ability:Freeze())
        Check("Bankai radius twenty extinguishes fifteen-unit fire",not far.components.burnable:IsBurning())
        Check("Bankai leaves outside twenty-unit fire alone",outside.components.burnable:IsBurning())
        for _, v in ipairs({near,smoking,far,outside}) do v.components.burnable:Extinguish(true,-1);v:Remove() end

        ability:SetTransformed(false,true,true)
        local target=SpawnPrefab("spider");target.Transform:SetPosition(x+3,0,z);target:StopBrain()
        local haunt=target.components.hauntable
        local old=haunt.onhaunt;local called=0
        haunt:SetOnHauntFn(function(...) called=called+1;return old(...) end)
        p:AddTag("playerghost")
        haunt:DoHaunt(p)
        Check("native haunt still calls original callback",called==1)
        Check("Hitsugaya ghost freezes native spider",target.components.freezable:IsFrozen())
        Check("native haunt cooldown retained",haunt.cooldowntimer>0)
        target:Remove();robe:Remove();p:RemoveTag("playerghost")

        -- Drive native buffered attacks, measuring actual onattackother events.
        local dummy=SpawnPrefab("spider");dummy.Transform:SetPosition(x+1,0,z)
        dummy:StopBrain();dummy.components.health:SetMaxHealth(100000)
        dummy.components.combat:SetAttackPeriod(1000);dummy.components.combat:StartAttack()
        local hits,phase,normalinterval={},false,nil
        local driver,watchdog
        local function OnAttack(_,data)
            if data.target==dummy then hits[#hits+1]=GetTime() end
        end
        p:ListenForEvent("onattackother",OnAttack)
        driver=p:DoPeriodicTask(FRAMES,function()
            if #hits>=6 then
                local interval=(hits[#hits]-hits[1])/(#hits-1)
                if not phase then
                    normalinterval=interval;phase=true;hits={}
                    p.sg:GoToState("idle");ability:SetTransformed(true,true,true)
                else
                    print("ABILITY_NATIVE_MEASURE attack intervals normal="..tostring(normalinterval).." Bankai="..tostring(interval).." speed_ratio="..tostring(normalinterval/interval))
                    Check("native consecutive sword attacks are faster",normalinterval/interval>=1.2 and normalinterval/interval<=1.45)
                    driver:Cancel();watchdog:Cancel()
                    p:RemoveEventCallback("onattackother",OnAttack)
                    dummy:Remove();p:Remove()
                    print("ABILITY_NATIVE_DONE "..tostring(TheShard:GetShardId()))
                    return
                end
            end
            if not p.sg:HasStateTag("attack") and not p.components.combat:InCooldown() then
                p:PushBufferedAction(BufferedAction(p,dummy,ACTIONS.ATTACK,sword))
            end
        end)
        watchdog=p:DoTaskInTime(25,function()Check("native consecutive attacks complete",false)end)
    end)
end
return M

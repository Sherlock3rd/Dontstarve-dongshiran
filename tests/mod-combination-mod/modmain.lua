local G = GLOBAL
if GetModConfigData("isolated_review") ~= true then return end
local expectedCount = GetModConfigData("expected_workshop_mods") or 29
local assert, ipairs, pairs, tostring, math = G.assert, G.ipairs, G.pairs, G.tostring, G.math
local function Run()
    local owned, cases, failures = {}, {}, 0
    local function Spawn(name)
        local inst = assert(G.SpawnPrefab(name), "spawn failed: " .. name)
        owned[#owned+1] = inst
        local portal = G.TheSim:FindFirstEntityWithTag("multiplayer_portal")
        if portal then inst.Transform:SetPosition(portal.Transform:GetWorldPosition()) end
        inst.entity:SetCanSleep(false)
        return inst
    end
    local function Player()
        local p = Spawn("hitsugaya")
        p.components.health:SetInvincible(true)
        return p, p.components.inventory
    end
    local function Add(name, fn) cases[#cases+1] = {name, fn} end
    local slot = G.EQUIPSLOTS.HITSUGAYA_ROBE
    Add("requested workshop modules loaded", function()
        local count = 0
        for _,name in ipairs(G.ModManager:GetEnabledModNames()) do
            if G.string.match(name,"^workshop%-%d+$") then count=count+1 end
        end
        print("[COMBO REVIEW] workshop count="..count)
        assert(count==expectedCount,"expected "..expectedCount.." workshop modules, got "..count)
    end)
    Add("armor co-wear and eight-slot overflow", function()
        local p,inv = Player()
        local robe,armor=Spawn("hitsugayarobe"),Spawn("armorwood")
        assert(inv:Equip(armor)); assert(inv:Equip(robe))
        assert(inv:GetEquippedItem(armor.components.equippable.equipslot)==armor)
        assert(inv:GetEquippedItem(slot)==robe)
        assert(robe.components.container.numslots==8)
        assert(inv:GetOverflowContainer()==robe.components.container,"server overflow lost")
        assert(p.replica.inventory:GetOverflowContainer()==robe.replica.container,"server replica overflow lost")
    end)
    for _,name in ipairs({"backpack","piggyback","krampus_sack"}) do
        for _,packFirst in ipairs({false,true}) do
            Add(name .. (packFirst and " then haori rejects" or " after haori rejects"), function()
                local p,inv=Player()
                local robe,pack=Spawn("hitsugayarobe"),Spawn(name)
                local a,b=Spawn("bluegem"),Spawn("redgem")
                assert(robe.components.container:GiveItem(a,8))
                assert(pack.components.container:GiveItem(b,1))
                print("[COMBO REVIEW] "..name.." actual slot="..tostring(pack.components.equippable.equipslot))
                assert(inv:Equip(packFirst and pack or robe))
                local accepted=inv:Equip(packFirst and robe or pack)
                assert(robe.components.container:GetItemInSlot(8)==a and a.components.inventoryitem.owner==robe,"haori content changed")
                assert(pack.components.container:GetItemInSlot(1)==b and b.components.inventoryitem.owner==pack,"backpack content changed")
                assert(not accepted,"both equipped; backpack/haori exclusion bypassed")
                assert(inv:GetEquippedItem((packFirst and pack or robe).components.equippable.equipslot)==(packFirst and pack or robe))
            end)
        end
    end
    Add("full inventory takes ingredients from haori slot eight", function()
        local p,inv=Player()
        local robe=Spawn("hitsugayarobe")
        assert(inv:Equip(robe))
        for i=1,inv:GetNumSlots() do
            if not inv:GetItemInSlot(i) then assert(inv:GiveItem(Spawn("rocks"),i)) end
        end
        local gold=Spawn("goldnugget")
        gold.components.stackable:SetStackSize(17)
        assert(robe.components.container:GiveItem(gold,8))
        assert(inv:Has("goldnugget",17),"slot eight not counted")
        inv:ConsumeByName("goldnugget",4)
        assert(gold:IsValid() and gold.components.stackable:StackSize()==13,"incorrect consumption")
    end)
    Add("large stacks and all eight slots survive native save record", function()
        local robe=Spawn("hitsugayarobe")
        for i,name in ipairs({"bluegem","redgem","purplegem","goldnugget","rocks","flint","twigs","log"}) do
            local item=Spawn(name)
            local max=item.components.stackable.maxsize
            local count=math.min(max,500)
            item.components.stackable:SetStackSize(count)
            assert(robe.components.container:GiveItem(item,i))
        end
        local expected={}
        for i=1,8 do
            local item=robe.components.container:GetItemInSlot(i)
            expected[i]={item.prefab,item.components.stackable:StackSize()}
        end
        local record=robe:GetSaveRecord()
        robe:Remove()
        local restored=assert(G.SpawnSaveRecord(record)); owned[#owned+1]=restored
        for i=1,8 do
            local item=assert(restored.components.container:GetItemInSlot(i))
            assert(item.prefab==expected[i][1] and item.components.stackable:StackSize()==expected[i][2],"save mismatch slot "..i)
            assert(item.components.inventoryitem.owner==restored)
        end
    end)
    local index=0
    local function Step()
        index=index+1
        local case=cases[index]
        if not case then
            print("[COMBO REVIEW] COMPLETE cases="..#cases.." failures="..failures)
            G.TheWorld:DoTaskInTime(1,function() G.c_shutdown(false) end)
            return
        end
        local ok,err=G.xpcall(case[2],function(e)return tostring(e) end)
        if not ok then failures=failures+1 end
        print("[COMBO REVIEW] "..(ok and "PASS " or "FAIL ")..case[1]..(ok and "" or ": "..tostring(err)))
        for _,inst in ipairs(owned) do if inst:IsValid() then inst:Remove() end end
        owned={}
        G.TheWorld:DoTaskInTime(.2,Step)
    end
    Step()
end
AddSimPostInit(function()
    if G.TheWorld.ismastersim then G.TheWorld:DoTaskInTime(5,Run) end
end)

local Data = require("hitsugaya_soul_data")
local Localization = require("hitsugaya_localization")
local M = {}

local function EquippedSword(player)
    local inventory = player ~= nil and player.replica.inventory or nil
    local sword = inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    return sword ~= nil and sword.prefab == "hitsugayasword" and sword or nil
end

function M.CraftingLimit(recipe, player)
    local def = Data.BUILD_RECIPES[recipe.name]
    local sword = player ~= nil and player.prefab == "hitsugaya" and not player:HasTag("playerghost")
        and EquippedSword(player) or nil
    return def ~= nil and sword ~= nil and sword._hitsugaya_soul_stage:value() == def.stage and 1 or 0
end

local function CanBuild(recipe, player)
    local sword = EquippedSword(player)
    local soul = sword ~= nil and sword.components.hitsugaya_soul or nil
    local def = Data.BUILD_RECIPES[recipe.name]
    return soul ~= nil and def ~= nil and soul:CanUpgrade(player, def.stage), "HITSUGAYA_SOUL"
end

-- Public for the isolated engine tests. The identity snapshot belongs to one
-- native BUILD buffered action, never to a reusable recipe-level build buffer.
function M.PrepareAction(builder, recipe, pt, rotation, skin, onsuccess)
    if Data.BUILD_RECIPES[recipe.name] == nil or not CanBuild(recipe, builder.inst)
        or not builder:HasIngredients(recipe) then return nil end
    local action = BufferedAction(builder.inst, nil, ACTIONS.BUILD, nil,
        pt or builder.inst:GetPosition(), recipe.name, recipe.build_distance, nil, rotation)
    action.skin = skin
    action._hitsugaya_soul_target = EquippedSword(builder.inst)
    action._hitsugaya_soul_stage = Data.BUILD_RECIPES[recipe.name].stage
    if onsuccess ~= nil then action:AddSuccessAction(onsuccess) end
    return action
end

function M.DoBuild(builder, recname, pt, rotation, skin)
    local def = Data.BUILD_RECIPES[recname]
    local recipe = def ~= nil and GetValidRecipe(recname) or nil
    local action = builder.inst:GetBufferedAction()
    local sword = EquippedSword(builder.inst)
    if recipe == nil or action == nil or action.action ~= ACTIONS.BUILD or action.recipe ~= recname
        or action._hitsugaya_soul_target ~= sword or action._hitsugaya_soul_stage ~= def.stage
        or not CanBuild(recipe, builder.inst) or not builder:HasIngredients(recipe)
        or builder:IsBuildBuffered(recname) or (skin ~= nil and PREFAB_SKINS_SHOULD_NOT_SELECT[skin]) then
        return false, "HITSUGAYA_SOUL"
    end
    local ingredients, discounted = builder:GetIngredients(recname)
    if builder:CheckIngredientsForMimic(ingredients)
        or (discounted and builder:CheckDiscountEquipsForMimic()) then return false, "ITEMMIMIC" end
    -- Recheck identity immediately before payment; no entity is ever SpawnPrefab'd.
    if EquippedSword(builder.inst) ~= sword or not CanBuild(recipe, builder.inst) then return false, "HITSUGAYA_SOUL" end
    local soul = sword.components.hitsugaya_soul
    soul.upgrading = true
    local paid, err = pcall(builder.RemoveIngredients, builder, ingredients, recname, discounted)
    if not paid then
        -- Preserve the native error and never leave the blade permanently locked
        -- if another mod catches an exception from its own ingredient callback.
        soul.upgrading = nil
        error(err)
    end
    soul:FinishUpgrade(builder.inst)
    builder.inst:PushEvent("refreshcrafting")
    return true
end

function M.AttachBuilder(inst)
    local builder = inst.components.builder
    if builder == nil or builder._hitsugaya_soul_wrapped then return end
    builder._hitsugaya_soul_wrapped = true
    local oldmake, oldbuild, oldbuffer = builder.MakeRecipe, builder.DoBuild, builder.BufferBuild
    builder.MakeRecipe = function(self, recipe, pt, rotation, skin, onsuccess)
        if recipe == nil or Data.BUILD_RECIPES[recipe.name] == nil then
            return oldmake(self, recipe, pt, rotation, skin, onsuccess)
        end
        if self.inst.sg == nil or self.inst.sg:HasAnyStateTag("busy", "dead", "drowning", "falling", "floating", "nointerrupt", "nopredict", "pausepredict") then return false end
        local action = M.PrepareAction(self, recipe, pt, rotation, skin, onsuccess)
        if action == nil then return false end
        self.inst:PushEvent("makerecipe", { recipe = recipe })
        self.inst.components.locomotor:Stop()
        self.inst.components.locomotor:PushAction(action, true)
        return true
    end
    builder.DoBuild = function(self, recname, ...)
        if Data.BUILD_RECIPES[recname] ~= nil then return M.DoBuild(self, recname, ...) end
        return oldbuild(self, recname, ...)
    end
    builder.BufferBuild = function(self, recname, ...)
        if Data.BUILD_RECIPES[recname] ~= nil then return false end
        return oldbuffer(self, recname, ...)
    end
end

function M.Install(AddCharacterRecipe, AddPrefabPostInit)
    for _, name in ipairs(Data.BUILD_ORDER) do
        local def, ingredients = Data.BUILD_RECIPES[name], {}
        for _, entry in ipairs(def.recipe) do ingredients[#ingredients + 1] = Ingredient(entry[1], entry[2]) end
        STRINGS.NAMES[string.upper(name)] = Localization.Text("RECIPE_" .. string.upper(name))
        STRINGS.RECIPE_DESC[string.upper(name)] = Localization.Text("DESC_" .. string.upper(name))
        AddCharacterRecipe(name, ingredients, TECH.NONE, {
            product = "hitsugayasword", builder_tag = "hitsugayaspecific", nounlock = true,
            atlas = "images/inventoryimages/hitsugayasword.xml", image = "hitsugayasword.tex",
            nameoverride = name, description = name, no_deconstruction = true,
            canbuild = CanBuild, getlimitedrecipecount = M.CraftingLimit,
        })
    end
    STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.BUILD.HITSUGAYA_SOUL = Localization.Text("SOUL_FAIL", "en")
    AddPrefabPostInit("hitsugaya", function(inst)
        inst:ListenForEvent("equip", function() inst:PushEvent("refreshcrafting") end)
        inst:ListenForEvent("unequip", function() inst:PushEvent("refreshcrafting") end)
        if TheWorld.ismastersim then M.AttachBuilder(inst) end
    end)
end
return M

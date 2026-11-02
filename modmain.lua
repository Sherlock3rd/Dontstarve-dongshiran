-- Original character/art: Silhh and Arcade, Workshop 736626219.
-- User-authorized restoration, combat, sanity economy and bounded soul upgrades.
local G = GLOBAL
local Asset = G.Asset
local STRINGS = G.STRINGS
local Localization = G.require("hitsugaya_localization")
Localization.Install(env)
G.require("hitsugaya_robe").Install(env)
G.require("hitsugaya_soul_crafting").Install(AddCharacterRecipe, AddPrefabPostInit)
G.require("hitsugaya_ice").Install(env)
G.require("hitsugaya_attackspeed").Install(env)
G.require("hitsugaya_haunt").Install(env)

if G.KnownModIndex:IsModEnabledAny("workshop-736626219") then
    error("Hitsugaya Compatibility: disable the original Workshop 736626219 mod first; both versions define the same character and items.")
end

PrefabFiles = { "hitsugaya", "hitsugaya_none", "hitsugayarobe", "hitsugayasword", "hitsugaya_ring_fx", "hitsugaya_swordwave_fx", "hitsugaya_iceglacier" }
Assets = {}
local atlases = {
    "images/saveslot_portraits/hitsugaya", "images/selectscreen_portraits/hitsugaya",
    "images/selectscreen_portraits/hitsugaya_silho", "bigportraits/hitsugaya", "bigportraits/hitsugaya_none",
    "images/map_icons/hitsugaya", "images/avatars/avatar_hitsugaya", "images/avatars/avatar_ghost_hitsugaya",
    "images/avatars/self_inspect_hitsugaya", "images/names_hitsugaya",
    "images/inventoryimages/hitsugayasword", "images/inventoryimages/hitsugayarobe",
}
for _, atlas in G.ipairs(atlases) do
    Assets[#Assets + 1] = Asset("ATLAS", atlas .. ".xml")
    Assets[#Assets + 1] = Asset("IMAGE", atlas .. ".tex")
end
local bankai_key = GetModConfigData("key") or 120
-- Reserve Z for Freeze, including worlds saved with the old Z default.
G.TUNING.HITSUGAYA_COMPAT_KEY = bankai_key == 122 and 120 or bankai_key

AddModRPCHandler("hitsugaya_compat", "activate", function(player, transform, freeze)
    -- Keep the RPC argument order compatible with older clients.
    -- DST's native Mod RPC transport decodes false arguments as nil.
    if (transform ~= nil and G.type(transform) ~= "boolean")
        or (freeze ~= nil and G.type(freeze) ~= "boolean") then return end
    if not transform and not freeze then return end
    if player ~= nil and player:IsValid() and player.prefab == "hitsugaya"
        and player.components.hitsugaya_compat ~= nil then
        player.components.hitsugaya_compat:Activate(transform == true, freeze == true)
    end
end)

STRINGS.CHARACTER_TITLES.hitsugaya = Localization.Text("CHARACTER_TITLE")
STRINGS.CHARACTER_NAMES.hitsugaya = Localization.Text("CHARACTER_NAME")
STRINGS.CHARACTER_DESCRIPTIONS.hitsugaya = Localization.Text("CHARACTER_DESCRIPTION")
STRINGS.CHARACTER_QUOTES.hitsugaya = Localization.Text("CHARACTER_QUOTE")
STRINGS.CHARACTERS.HITSUGAYA = G.require("speech_hitsugaya")
STRINGS.NAMES.HITSUGAYA = Localization.Text("CHARACTER_NAME")
STRINGS.NAMES.HITSUGAYASWORD = Localization.Text("SWORD_NAME")
STRINGS.NAMES.HITSUGAYAROBE = Localization.Text("ROBE_NAME")
STRINGS.NAMES.HITSUGAYA_ICEGLACIER = STRINGS.NAMES.ROCK_ICE
STRINGS.CHARACTERS.GENERIC.DESCRIBE.HITSUGAYA_ICEGLACIER = STRINGS.CHARACTERS.GENERIC.DESCRIBE.ROCK_ICE
STRINGS.CHARACTERS.GENERIC.DESCRIBE.HITSUGAYASWORD = Localization.Text("SWORD_INSPECT", "en")
STRINGS.CHARACTERS.GENERIC.DESCRIBE.HITSUGAYAROBE = Localization.Text("ROBE_INSPECT", "en")
AddMinimapAtlas("images/map_icons/hitsugaya.xml")
RegisterInventoryItemAtlas("images/inventoryimages/hitsugayasword.xml", "hitsugayasword.tex")
RegisterInventoryItemAtlas("images/inventoryimages/hitsugayarobe.xml", "hitsugayarobe.tex")
AddModCharacter("hitsugaya", "MALE")

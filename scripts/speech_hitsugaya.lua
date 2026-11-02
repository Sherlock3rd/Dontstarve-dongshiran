-- Stable English wire speech; each client resolves its own display language.
-- Read fresh native speech: require's cached table may already be translated.
local Localization = require("hitsugaya_localization")
local native = assert(kleiloadlua("scripts/speech_wilson.lua"))()
local function Copy(source, path, translate)
    local target = {}
    for key, value in pairs(source) do
        local nextpath = path .. "." .. tostring(key)
        if type(value) == "table" then
            target[key] = Copy(value, nextpath, translate)
        else
            target[key] = translate and LanguageTranslator ~= nil
                and LanguageTranslator:GetTranslatedString(nextpath) or value
            if target[key] == nil or target[key] == "" then target[key] = value end
        end
    end
    return target
end
local function Merge(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            Merge(target[key], value)
        else
            target[key] = value
        end
    end
end
local english = Copy(native, "STRINGS.CHARACTERS.GENERIC", false)
local chinese = Copy(native, "STRINGS.CHARACTERS.GENERIC", Localization.IsChineseCode(Localization.GetLocale()))
Merge(english, require("speech_hitsugaya_en"))
Merge(chinese, require("speech_hitsugaya_zh"))
english.ACTIONFAIL.BUILD.HITSUGAYA_SOUL = Localization.Text("SOUL_FAIL", "en")
chinese.ACTIONFAIL.BUILD.HITSUGAYA_SOUL = Localization.Text("SOUL_FAIL", "zh")
Localization.RegisterSpeech(english, chinese)
Localization.RegisterSpeech(require("speech_hitsugaya_en"), require("speech_hitsugaya_zh"), true)
return english

-- Display-only bilingual speech. Native Talker keeps the original wire message;
-- this module never wraps networking/chat or changes the supplied script table.
local G = rawget(_G, "GLOBAL") or _G
local Strings = require("hitsugaya_strings")
local L = {}
local installed = false

function L.GetLocale()
    local ok, loc = pcall(require, "languages/loc")
    if ok and loc ~= nil and type(loc.GetLocaleCode) == "function" then
        local success, code = pcall(loc.GetLocaleCode)
        if success and type(code) == "string" then return code end
    end
    return "en"
end

function L.IsChineseCode(code)
    if type(code) ~= "string" then return false end
    code = string.lower(code)
    return code == "zh" or code == "zht" or code == "zhr"
        or string.sub(code, 1, 3) == "zh-" or string.sub(code, 1, 3) == "zh_"
end

function L.Text(key, locale)
    local lang = L.IsChineseCode(locale or L.GetLocale()) and "zh" or "en"
    return Strings[lang][key] or Strings.en[key] or key
end

local function NewRegistry()
    return { en = {}, zh = {}, templates = { en = {}, zh = {} }, ordered = {} }
end
local own, speech = NewRegistry(), NewRegistry()

local function EscapePattern(value)
    return (string.gsub(value, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- Only native %s/%d placeholders (and literal %%) are accepted. Formatting is
-- reconstructed from captured bytes, so player names and numbers remain intact.
local function ParseTemplate(value)
    local parts, pattern, signature = {}, { "^" }, {}
    local pos, literalcount = 1, 0
    while pos <= #value do
        local marker = string.find(value, "%", pos, true)
        local literal = string.sub(value, pos, marker and marker - 1 or #value)
        parts[#parts + 1] = literal
        pattern[#pattern + 1] = EscapePattern(literal)
        literalcount = literalcount + #literal
        if marker == nil then break end
        local spec = string.sub(value, marker + 1, marker + 1)
        if spec == "%" then
            parts[#parts + 1] = "%"
            pattern[#pattern + 1] = "%%"
            literalcount = literalcount + 1
        elseif spec == "s" or spec == "d" then
            signature[#signature + 1] = spec
            parts[#parts + 1] = #signature
            pattern[#pattern + 1] = spec == "s" and "(.-)" or "([+-]?%d+)"
        else
            return nil
        end
        pos = marker + 2
    end
    if #signature == 0 or literalcount == 0 then return nil end
    pattern[#pattern + 1] = "$"
    return { parts = parts, pattern = table.concat(pattern),
        signature = table.concat(signature), literalcount = literalcount }
end

local function AddDirection(registry, lang, source, destination, overwrite)
    local map = registry[lang]
    if map[source] ~= nil and not overwrite then return end
    map[source] = destination
    registry.templates[lang][source] = nil
    local from, to = ParseTemplate(source), ParseTemplate(destination)
    if from ~= nil and to ~= nil and from.signature == to.signature then
        registry.templates[lang][source] = { from = from, to = to, source = source }
    end
    registry.ordered[lang] = nil
end

local function Register(registry, en, zh, overwrite)
    if type(en) ~= "string" or type(zh) ~= "string" or en == "" or zh == "" then return end
    AddDirection(registry, "zh", en, zh, overwrite)
    AddDirection(registry, "en", zh, en, overwrite)
end

function L.RegisterPair(en, zh)
    Register(own, en, zh)
end

function L.RegisterSpeech(en, zh, overwrite)
    if type(en) ~= "table" or type(zh) ~= "table" then return end
    -- Native paths can share English sentences with slightly different Chinese
    -- variants. Sorted traversal gives a stable first translation; character
    -- overrides are registered last with overwrite=true and take precedence.
    local keys = {}
    for key in pairs(en) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        if type(a) == "number" and type(b) == "number" then return a < b end
        return tostring(a) < tostring(b)
    end)
    for _, key in ipairs(keys) do
        local value = en[key]
        if type(value) == "table" then
            L.RegisterSpeech(value, zh[key], overwrite)
        else
            Register(speech, value, zh[key], overwrite)
        end
    end
end

local function Translate(registry, message, lang)
    local exact = registry[lang][message]
    if exact ~= nil then return exact or message end
    local templates = registry.ordered[lang]
    if templates == nil then
        templates = {}
        for _, value in pairs(registry.templates[lang]) do templates[#templates + 1] = value end
        table.sort(templates, function(a, b)
            if a.from.literalcount ~= b.from.literalcount then
                return a.from.literalcount > b.from.literalcount
            end
            return a.source < b.source
        end)
        registry.ordered[lang] = templates
    end
    for _, template in ipairs(templates) do
        local args = { string.match(message, template.from.pattern) }
        if #args == #template.from.signature then
            local parts = {}
            for _, part in ipairs(template.to.parts) do
                parts[#parts + 1] = type(part) == "number" and args[part] or part
            end
            return table.concat(parts)
        end
    end
end

for key, en in pairs(Strings.en) do
    if string.match(key, "^BANKAI_") or string.match(key, "^FREEZE_")
        or string.match(key, "^SOUL_UP_") or string.match(key, "^SOUL_DESC_")
        or string.match(key, "^WAVE_")
        or key == "ROBE_CONFLICT" or key == "SOUL_FAIL"
        or key == "SWORD_INSPECT" or key == "ROBE_INSPECT" then
        L.RegisterPair(en, Strings.zh[key])
    end
end

local function IsGameContext(context)
    return context ~= nil and context.author == nil
        and (context.kind == nil or context.kind == G.TEXT_FILTER_CTX_UNKNOWN
            or context.kind == G.TEXT_FILTER_CTX_GAME)
        and context.kind ~= G.TEXT_FILTER_CTX_CHAT
end

local function Localize(talker, message, context)
    if type(message) ~= "string" or not IsGameContext(context) then return message end
    local lang = L.IsChineseCode(L.GetLocale()) and "zh" or "en"
    return Translate(own, message, lang)
        or (talker.inst.prefab == "hitsugaya" and Translate(speech, message, lang))
        or message
end

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function InstallTalker(talker)
    if talker._hitsugaya_localization ~= nil then return end
    local state = {}
    talker._hitsugaya_localization = state
    local function WrapDisplay(previous)
        -- Capture each predecessor immutably. A later mod may retain our old
        -- callback; preserving that closure avoids recursion and losing its
        -- predecessors when we adopt the new callback on the next Say call.
        return function(message)
            local display = previous ~= nil and previous(message) or message
            return Localize(talker, display, state.context)
        end
    end
    local Display = WrapDisplay(talker.mod_str_fn)
    talker.mod_str_fn = Display
    local original = talker.Say
    talker.Say = function(self, script, time, noanim, force, nobroadcast, colour,
            text_filter_context, original_author_netid, ...)
        if self.mod_str_fn ~= Display then
            Display = WrapDisplay(self.mod_str_fn)
            self.mod_str_fn = Display
        end
        local previouscontext, previoustask = state.context, self.task
        state.context = { kind = text_filter_context, author = original_author_netid }
        local result = Pack(pcall(original, self, script, time, noanim, force,
            nobroadcast, colour, text_filter_context, original_author_netid, ...))
        -- Ignored/dead/asleep calls do not cancel native speech. Keep the context
        -- of that still-running script, including its later lines.
        if not result[1] or self.task == previoustask then state.context = previouscontext end
        if not result[1] then error(result[2], 0) end
        return unpack(result, 2, result.n)
    end
end

function L.Install(api)
    if installed then return end
    assert(api ~= nil and type(api.AddComponentPostInit) == "function",
        "Hitsugaya localization requires AddComponentPostInit")
    api.AddComponentPostInit("talker", InstallTalker)
    installed = true
end

function L.Say(inst, key, time, noanim)
    local talker = inst ~= nil and inst.components ~= nil and inst.components.talker or nil
    if talker ~= nil then
        return talker:Say(L.Text(key, "en"), time, noanim, nil, nil, nil, G.TEXT_FILTER_CTX_GAME)
    end
end

return L

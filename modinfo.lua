-- This information tells other players more about the mod
local language = (locale or "en"):lower()
local chinese = language == "zh" or language == "zht" or language == "zhr"
    or language:match("^zh[-_]") ~= nil
name = chinese and "日番谷冬狮郎 · 冰轮丸" or "Toshiro Hitsugaya — Hyorinmaru"
description = chinese
    and "护廷十三队十番队队长，以冰轮丸迎战永恒领域。以理智维持卍解，借寒地与冷食调息；循序强化斩魄刀，身披八格防腐队长羽织。\n请勿与原版创意工坊人物（736626219）同时启用。"
    or "The captain of Squad Ten brings Hyorinmaru to the Constant. Sustain Bankai with sanity, draw strength from snowy ground and chilled food, strengthen your Zanpakuto, and carry supplies in an eight-pocket preserving haori.\nDisable the original Workshop character (736626219) before enabling."
author = "Silhh and Arcade"
version = "1.3.5"

-- Native development support: newly added files must not use a stale Workshop index.
forcemanifest = false

-- This is the URL name of the mod's thread on the forum; the part after the ? and before the first & in the url
forumthread = ""


-- This lets other players know if your mod is out of date, update it to match the current version in the game
api_version = 10

-- Compatible with Don't Starve Together
dst_compatible = true

-- Not compatible with Don't Starve
dont_starve_compatible = false
reign_of_giants_compatible = false

-- Character mods need this set to true
all_clients_require_mod = true 

icon_atlas = "modicon.xml"
icon = "modicon.tex"

-- The mod's tags displayed on the server list
server_filter_tags = {
"character",
}

configuration_options =
{
    {
        name = "key",
        label = chinese and "卍解按键" or "Bankai Key",
        hover = chinese
            and "松开此键开启或解除卍解，默认为X。Z专用于冰冻；旧存档的Z变身配置自动改用X。"
            or "Release this key to enter or leave Bankai (default X). Z is reserved for Freeze; legacy Z Bankai settings use X automatically.",
        options =
        {
            {description="TAB", data = 9},
            {description="KP_PERIOD", data = 266},
            {description="KP_DIVIDE", data = 267},
            {description="KP_MULTIPLY", data = 268},
            {description="KP_MINUS", data = 269},
            {description="KP_PLUS", data = 270},
            {description="KP_ENTER", data = 271},
            {description="KP_EQUALS", data = 272},
            {description="MINUS", data = 45},
            {description="EQUALS", data = 61},
            {description="SPACE", data = 32},
            {description="ENTER", data = 13},
            {description="ESCAPE", data = 27},
            {description="HOME", data = 278},
            {description="INSERT", data = 277},
            {description="DELETE", data = 127},
            {description="END", data   = 279},
            {description="PAUSE", data = 19},
            {description="PRINT", data = 316},
            {description="CAPSLOCK", data = 301},
            {description="SCROLLOCK", data = 302},
            {description="RSHIFT", data = 303}, -- use SHIFT instead
            {description="LSHIFT", data = 304}, -- use SHIFT instead
            {description="RCTRL", data = 305}, -- use CTRL instead
            {description="LCTRL", data = 306}, -- use CTRL instead
            {description="RALT", data = 307}, -- use ALT instead
            {description="LALT", data = 308}, -- use ALT instead
            {description="ALT", data = 400},
            {description="CTRL", data = 401},
            {description="SHIFT", data = 402},
            {description="BACKSPACE", data = 8},
            {description="PERIOD", data = 46},
            {description="SLASH", data = 47},
            {description="LEFTBRACKET", data     = 91},
            {description="BACKSLASH", data     = 92},
            {description="RIGHTBRACKET", data = 93},
            {description="TILDE", data = 96},
            {description="A", data = 97},
            {description="B", data = 98},
            {description="C", data = 99},
            {description="D", data = 100},
            {description="E", data = 101},
            {description="F", data = 102},
            {description="G", data = 103},
            {description="H", data = 104},
            {description="I", data = 105},
            {description="J", data = 106},
            {description="K", data = 107},
            {description="L", data = 108},
            {description="M", data = 109},
            {description="N", data = 110},
            {description="O", data = 111},
            {description="P", data = 112},
            {description="Q", data = 113},
            {description="R", data = 114},
            {description="S", data = 115},
            {description="T", data = 116},
            {description="U", data = 117},
            {description="V", data = 118},
            {description="W", data = 119},
            {description="X", data = 120},
            {description="Y", data = 121},
            {description="F1", data = 282},
            {description="F2", data = 283},
            {description="F3", data = 284},
            {description="F4", data = 285},
            {description="F5", data = 286},
            {description="F6", data = 287},
            {description="F7", data = 288},
            {description="F8", data = 289},
            {description="F9", data = 290},
            {description="F10", data = 291},
            {description="F11", data = 292},
            {description="F12", data = 293},
 
            {description="UP", data = 273},
            {description="DOWN", data = 274},
            {description="RIGHT", data = 275},
            {description="LEFT", data = 276},
            {description="PAGEUP", data = 280},
            {description="PAGEDOWN", data = 281},
 
            {description="0", data = 48},
            {description="1", data = 49},
            {description="2", data = 50},
            {description="3", data = 51},
            {description="4", data = 52},
            {description="5", data = 53},
            {description="6", data = 54},
            {description="7", data = 55},
            {description="8", data = 56},
            {description="9", data = 57},
        },
        default = 120,
    },
	 
} 

-- Keep legacy key codes/config saves, but show readable keyboard labels.
local keylabels = {
    KP_PERIOD = { "小键盘 .", "Numpad ." }, KP_DIVIDE = { "小键盘 /", "Numpad /" },
    KP_MULTIPLY = { "小键盘 *", "Numpad *" }, KP_MINUS = { "小键盘 -", "Numpad -" },
    KP_PLUS = { "小键盘 +", "Numpad +" }, KP_ENTER = { "小键盘回车", "Numpad Enter" },
    KP_EQUALS = { "小键盘 =", "Numpad =" }, SPACE = { "空格", "Space" },
    ENTER = { "回车", "Enter" }, ESCAPE = { "Esc", "Esc" }, TAB = { "Tab", "Tab" },
    HOME = { "Home", "Home" }, INSERT = { "Insert", "Insert" }, DELETE = { "Delete", "Delete" },
    END = { "End", "End" }, PAUSE = { "Pause", "Pause" }, PRINT = { "Print Screen", "Print Screen" },
    CAPSLOCK = { "Caps Lock", "Caps Lock" }, SCROLLOCK = { "Scroll Lock", "Scroll Lock" },
    RSHIFT = { "右 Shift", "Right Shift" }, LSHIFT = { "左 Shift", "Left Shift" },
    RCTRL = { "右 Ctrl", "Right Ctrl" }, LCTRL = { "左 Ctrl", "Left Ctrl" },
    RALT = { "右 Alt", "Right Alt" }, LALT = { "左 Alt", "Left Alt" },
    ALT = { "Alt", "Alt" }, CTRL = { "Ctrl", "Ctrl" }, SHIFT = { "Shift", "Shift" },
    BACKSPACE = { "退格", "Backspace" }, PERIOD = { ".", "." }, SLASH = { "/", "/" },
    LEFTBRACKET = { "[", "[" }, BACKSLASH = { "\\", "\\" }, RIGHTBRACKET = { "]", "]" },
    TILDE = { "` / ~", "` / ~" }, MINUS = { "-", "-" }, EQUALS = { "=", "=" },
    UP = { "方向键 ↑", "Up Arrow" }, DOWN = { "方向键 ↓", "Down Arrow" },
    LEFT = { "方向键 ←", "Left Arrow" }, RIGHT = { "方向键 →", "Right Arrow" },
    PAGEUP = { "Page Up", "Page Up" }, PAGEDOWN = { "Page Down", "Page Down" },
}
for i = 1, #configuration_options[1].options do
    local option = configuration_options[1].options[i]
    local label = keylabels[option.description]
    if label ~= nil then option.description = label[chinese and 1 or 2] end
end

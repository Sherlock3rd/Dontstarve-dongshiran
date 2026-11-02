-- Shared with client crafting limits and descriptions; progression lives on the sword.
local M = {}
M.PHYSICAL = { [0] = 40.8, 71.4, 81.6, 81.6, 45.6 }
M.MAINTENANCE = { [0] = 1.5, 1.5, 1.35, 1.2, 1.05 }
M.RECIPES = {
    { { "goldnugget", 4 }, { "bluegem", 1 } },
    { { "moonrocknugget", 8 }, { "bluegem", 1 } },
    { { "thulecite", 4 }, { "nightmarefuel", 6 } },
    { { "purebrilliance", 4 }, { "lunarplant_husk", 4 } },
}
M.ALTERNATE_III = { { "purebrilliance", 2 }, { "nightmarefuel", 6 } }
M.NAMES = { [0] = "0", "Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ" }
M.BUILD_RECIPES = {
    hitsugaya_soul_1 = { stage = 0, recipe = M.RECIPES[1] },
    hitsugaya_soul_2 = { stage = 1, recipe = M.RECIPES[2] },
    hitsugaya_soul_3 = { stage = 2, recipe = M.RECIPES[3] },
    hitsugaya_soul_3_lunar = { stage = 2, recipe = M.ALTERNATE_III },
    hitsugaya_soul_4 = { stage = 3, recipe = M.RECIPES[4] },
}
M.BUILD_ORDER = { "hitsugaya_soul_1", "hitsugaya_soul_2", "hitsugaya_soul_3", "hitsugaya_soul_3_lunar", "hitsugaya_soul_4" }
return M

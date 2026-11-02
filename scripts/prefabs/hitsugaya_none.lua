local assets =
{
	Asset( "ANIM", "anim/hitsugaya.zip" ),
	Asset( "ANIM", "anim/ghost_hitsugaya_build.zip" ),
}

local skins =
{
	normal_skin = "hitsugaya",
	bankai = "hitsugayabankai",
	ghost_skin = "ghost_hitsugaya_build",
}

local base_prefab = "hitsugaya"

local tags = {"HITSUGAYA", "CHARACTER"}

return CreatePrefabSkin("hitsugaya_none",
{
	base_prefab = base_prefab, 
	-- Generic skin UI queries the item build separately from skins.normal_skin.
	-- The existing base build is hitsugaya; hitsugaya_none is only the skin ID.
	build_name_override = "hitsugaya",
	skins = skins, 
	assets = assets,
	tags = tags,
	
	skip_item_gen = true,
	skip_giftable_gen = true,
})

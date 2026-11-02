-- Shared constants and bounded, server-side placement. No terrain edits.
local M = { RADIUS = 10, BANKAI_RADIUS = 20, COOLDOWN = 60, LIMIT = 2, DAYS = 2, LOOT = 3,
    BANKAI_LOOT = 7, TAG = "hitsugaya_skill_ice", PREFAB = "hitsugaya_iceglacier" }
local EXCLUDE = { "INLIMBO" }
local PONDS = { pond = true, pond_mos = true, pond_cave = true }
local offsets = {}
for x = -20, 20, 2 do
    for z = -20, 20, 2 do
        local d = x * x + z * z
        if d >= 4 and d <= 400 then offsets[#offsets + 1] = { x = x, z = z, d = d } end
    end
end
table.sort(offsets, function(a, b)
    return a.d < b.d or (a.d == b.d and (a.x < b.x or a.x == b.x and a.z < b.z))
end)

function M.GetRadius(player)
    local ability = player.components.hitsugaya_compat
    return ability ~= nil and ability.transformed and M.BANKAI_RADIUS or M.RADIUS
end

function M.Now()
    return (TheWorld.state.cycles + TheWorld.state.time) * TUNING.TOTAL_DAY_TIME
end

function M.Finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

function M.InRange(x, z, cx, cz, radius)
    return (x - cx) ^ 2 + (z - cz) ^ 2 <= (radius or M.RADIUS) ^ 2
end

function M.HasGlacier(x, z, radius)
    return #TheSim:FindEntities(x, 0, z, radius or M.RADIUS, { M.TAG }, EXCLUDE) > 0
end

function M.Clear(x, z)
    local map = TheWorld.Map
    -- Boats, docks, holes, occupied ground and the visual coast overhang are excluded.
    if not map:IsLandTileNoDocksAtPoint(x, 0, z)
        or not map:IsPassableAtPoint(x, 0, z, false, true)
        or map:GetPlatformAtPoint(x, z) ~= nil then return false end
    local pt = Vector3(x, 0, z)
    return not map:IsPointNearHole(pt, 1)
        and map:IsDeployPointClear(pt, nil, 2, nil, nil, true)
end

function M.FindShore(cx, cz, radius)
    radius = radius or M.RADIUS
    local ponds = {}
    for _, pond in ipairs(TheSim:FindEntities(cx, 0, cz, radius, { "pond" }, EXCLUDE)) do
        if PONDS[pond.prefab] and pond:IsValid() then
            local x, _, z = pond.Transform:GetWorldPosition()
            if M.InRange(x, z, cx, cz, radius) then ponds[#ponds + 1] = { x = x, z = z } end
        end
    end
    -- The precomputed grid bounds the search to 80/316 candidates. Do not stop
    -- at the first crowded stretch of shore while farther valid spots remain.
    for _, offset in ipairs(offsets) do
        if offset.d > radius * radius then break end
        local x, z = cx + offset.x, cz + offset.z
        if TheWorld.Map:IsLandTileNoDocksAtPoint(x, 0, z) then
            local water = false
            for _, pond in ipairs(ponds) do
                if (x - pond.x) ^ 2 + (z - pond.z) ^ 2 <= 16 then water = true; break end
            end
            if not water then
                -- Sample nearby water only inside this cast's circle, never outside it.
                for i = 0, 7 do
                    local angle = i * math.pi / 4
                    local wx, wz = x + 3 * math.cos(angle), z + 3 * math.sin(angle)
                    local dx, dz = wx - cx, wz - cz
                    local distance = math.sqrt(dx * dx + dz * dz)
                    if distance > radius then
                        wx, wz = cx + dx * radius / distance, cz + dz * radius / distance
                    end
                    if M.InRange(wx, wz, cx, cz, radius) and TheWorld.Map:IsOceanAtPoint(wx, 0, wz) then
                        water = true; break
                    end
                end
            end
            if water then
                if M.Clear(x, z) then return x, z end
            end
        end
    end
end

function M.Install(api)
    api.AddPrefabPostInit("world", function(inst)
        if inst.ismastersim then inst:AddComponent("hitsugaya_iceworld") end
    end)
    for _, name in ipairs({ "Request", "Grant", "Validate", "Validated", "Release", "Evict", "Evicted" }) do
        local method = name
        api.AddShardModRPCHandler("hitsugaya_ice", name, function(sender, ...)
            local manager = TheWorld ~= nil and TheWorld.components.hitsugaya_iceworld or nil
            if manager ~= nil then manager[method](manager, tostring(sender), ...) end
        end)
    end
end

return M

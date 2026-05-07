local ttEffects = {}

-- Shared RNG (set from main.lua)
local rng = nil

function ttEffects.Init(sharedRng)
    rng = sharedRng
end

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function getPlayer()
    return Isaac.GetPlayer(0)
end

local function getRoom()
    return Game():GetRoom()
end

local function randomPos()
    local room = getRoom()
    local p = getPlayer()
    if not room or not p then return Vector(320, 280) end -- fallback to center of a typical room
    return room:FindFreePickupSpawnPosition(p.Position, 80, true)
end

local AllCurses = (
    LevelCurse.CURSE_OF_DARKNESS +
    LevelCurse.CURSE_OF_THE_LOST +
    LevelCurse.CURSE_OF_THE_UNKNOWN +
    LevelCurse.CURSE_OF_BLIND +
    LevelCurse.CURSE_OF_MAZE
)

-- ── Chaos effects ─────────────────────────────────────────────────────────────

-- Bosses: Monstro, Chub, Gurdy, Gemini, Loki, Peep, Duke
local BOSS_TYPES = {
    {EntityType.ENTITY_MONSTRO, 0, 0},
    {EntityType.ENTITY_CHUB, 0, 0},
    {EntityType.ENTITY_GURDY, 0, 0},
    {EntityType.ENTITY_GEMINI, 0, 0},
    {EntityType.ENTITY_LOKI, 0, 0},
    {EntityType.ENTITY_PEEP, 0, 0},
    {EntityType.ENTITY_DUKE, 0, 0},
}

local ENEMY_TYPES = {
    {EntityType.ENTITY_GAPER, 0, 0},
    {EntityType.ENTITY_HORF, 0, 0},
    {EntityType.ENTITY_FLY, 0, 0},
    {EntityType.ENTITY_POOTER, 0, 0},
    {EntityType.ENTITY_CLOTTY, 0, 0},
    {EntityType.ENTITY_MULLIGAN, 0, 0},
    {EntityType.ENTITY_MAGGOT, 0, 0},
    {EntityType.ENTITY_HIVE, 0, 0},
    {EntityType.ENTITY_CHARGER, 0, 0},
    {EntityType.ENTITY_GLOBIN, 0, 0},
    {EntityType.ENTITY_HOPPER, 0, 0},
    {EntityType.ENTITY_MAW, 0, 0},
}

function ttEffects.boss_wave()
    for i = 1, 3 do
        local pick = BOSS_TYPES[rng:RandomInt(#BOSS_TYPES) + 1]
        local entityId = tostring(pick[1]) .. "." .. tostring(pick[2]) .. "." .. tostring(pick[3])
        
        -- Spawn 1 boss unit (SpawnBoss will handle segments internally)
        ttEffects.SpawnBoss(entityId, 1)
    end
    return true, "Boss wave spawned"
end

function ttEffects.enemy_wave()
    for i = 1, 15 do
        local pick = ENEMY_TYPES[rng:RandomInt(#ENEMY_TYPES) + 1]
        Isaac.Spawn(pick[1], pick[2], pick[3], randomPos(), Vector(0, 0), nil)
    end
    return true, "Enemy wave spawned"
end

function ttEffects.chaos_mode()
    -- 5 random items
    for i = 1, 5 do
        local item = 1 + rng:RandomInt(CollectibleType.NUM_COLLECTIBLES - 1)
        local pos = randomPos()
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, item, pos, Vector(0, 0), nil)
    end
    -- 10 random enemies
    for i = 1, 10 do
        local pick = ENEMY_TYPES[rng:RandomInt(#ENEMY_TYPES) + 1]
        Isaac.Spawn(pick[1], pick[2], pick[3], randomPos(), Vector(0, 0), nil)
    end
    return true, "Chaos mode!"
end

-- ── Curses ───────────────────────────────────────────────────────────────────

function ttEffects.all_curses()
    Game():GetLevel():AddCurse(AllCurses, true)
    return true, "All curses applied"
end

function ttEffects.random_curse()
    local curseList = {
        LevelCurse.CURSE_OF_DARKNESS,
        LevelCurse.CURSE_OF_THE_LOST,
        LevelCurse.CURSE_OF_THE_UNKNOWN,
        LevelCurse.CURSE_OF_BLIND,
        LevelCurse.CURSE_OF_MAZE,
    }
    local active = Game():GetLevel():GetCurses()
    local available = {}
    for _, c in ipairs(curseList) do
        if (active & c) ~= c then
            table.insert(available, c)
        end
    end
    if #available == 0 then
        return false, "All curses already active"
    end
    local pick = available[rng:RandomInt(#available) + 1]
    Game():GetLevel():AddCurse(pick, true)
    return true, "Random curse applied"
end

-- ── Punishment ────────────────────────────────────────────────────────────────

function ttEffects.near_death()
    local p = getPlayer()
    -- set hearts to minimum
    local maxHp = p:GetMaxHearts()
    p:AddMaxHearts(-maxHp, true)
    p:AddMaxHearts(2, true)  -- 1 full heart max
    p:AddHearts(-p:GetHearts())
    p:AddHearts(1) -- half heart
    return true, "Near death!"
end

function ttEffects.remove_item()
    local p = getPlayer()
    -- find a random held collectible
    local candidates = {}
    for i = 1, CollectibleType.NUM_COLLECTIBLES - 1 do
        if p:HasCollectible(i) then
            table.insert(candidates, i)
        end
    end
    if #candidates == 0 then
        return false, "No items to remove"
    end
    local pick = candidates[rng:RandomInt(#candidates) + 1]
    p:RemoveCollectible(pick)
    p:AnimateSad()
    return true, "Item removed!"
end

-- ── Timed state variables ─────────────────────────────────────────────────────

ttEffects.timedEffects = {}  -- active: {endTime, cleanupFn}

local savedSpeed = nil
local savedDamage = nil

function ttEffects.controls_reversed()
    if Game():GetSeeds():HasSeedEffect(SeedEffect.SEED_CONTROLS_REVERSED) then
        return false, "Controls already reversed"
    end
    Game():GetSeeds():AddSeedEffect(SeedEffect.SEED_CONTROLS_REVERSED)
    ttEffects.timedEffects["controls_reversed"] = {
        endTime = Isaac.GetTime() + 30000,
        cleanup = function()
            Game():GetSeeds():RemoveSeedEffect(SeedEffect.SEED_CONTROLS_REVERSED)
        end
    }
    return true, "Controls reversed for 30s"
end

function ttEffects.inverse_screen()
    -- Uses shader inversion via seed effect if available, else pixelation as fallback
    if SeedEffect and SeedEffect.SEED_RETRO_VISION then
        Game():GetSeeds():AddSeedEffect(SeedEffect.SEED_RETRO_VISION)
        ttEffects.timedEffects["inverse_screen"] = {
            endTime = Isaac.GetTime() + 20000,
            cleanup = function()
                if SeedEffect and SeedEffect.SEED_RETRO_VISION then
                    Game():GetSeeds():RemoveSeedEffect(SeedEffect.SEED_RETRO_VISION)
                end
            end
        }
    end
    return true, "Screen inverted for 20s"
end

function ttEffects.speed_boost()
    local p = getPlayer()
    local capturedSpeed = p.MoveSpeed
    p.MoveSpeed = p.MoveSpeed * 2
    ttEffects.timedEffects["speed_boost"] = {
        endTime = Isaac.GetTime() + 30000,
        cleanup = function()
            local cur = Isaac.GetPlayer(0)
            if cur then cur.MoveSpeed = capturedSpeed end
        end
    }
    return true, "Speed doubled for 30s"
end

function ttEffects.damage_boost()
    local p = getPlayer()
    local capturedDamage = p.Damage
    p.Damage = p.Damage * 2
    ttEffects.timedEffects["damage_boost"] = {
        endTime = Isaac.GetTime() + 30000,
        cleanup = function()
            local cur = Isaac.GetPlayer(0)
            if cur then cur.Damage = capturedDamage end
        end
    }
    return true, "Damage doubled for 30s"
end

function ttEffects.god_mode()
    if Game():GetSeeds():HasSeedEffect(SeedEffect.SEED_INVINCIBILITY) then
        return false, "Already invincible"
    end
    Game():GetSeeds():AddSeedEffect(SeedEffect.SEED_INVINCIBILITY)
    ttEffects.timedEffects["god_mode"] = {
        endTime = Isaac.GetTime() + 15000,
        cleanup = function()
            Game():GetSeeds():RemoveSeedEffect(SeedEffect.SEED_INVINCIBILITY)
        end
    }
    return true, "God mode for 15s"
end

-- ── Boons ─────────────────────────────────────────────────────────────────────

function ttEffects.full_heal()
    local p = getPlayer()
    p:AddHearts(p:GetMaxHearts())
    p:AddSoulHearts(6)
    return true, "Full heal!"
end

function ttEffects.give_devil_item()
    local p = getPlayer()
    local config = Isaac.GetItemConfig()
    -- Try to get a devil-pool item
    local devilItem = Game():GetItemPool():GetCollectible(ItemPoolType.POOL_DEVIL, true, rng:Next())
    if devilItem and devilItem ~= CollectibleType.COLLECTIBLE_NULL then
        p:AnimateCollectible(devilItem, "Pickup", "PlayerPickupSparkle")
        p:AddCollectible(devilItem, 0, true)
        return true, "Devil item given"
    end
    return false, "No devil item available"
end

function ttEffects.give_random_item()
    local p = getPlayer()
    local item = 1 + rng:RandomInt(CollectibleType.NUM_COLLECTIBLES - 1)
    p:AnimateCollectible(item, "Pickup", "PlayerPickupSparkle")
    p:AddCollectible(item, 0, true)
    return true, "Random item given"
end

function ttEffects.add_resources()
    local p = getPlayer()
    p:AddCoins(10)
    p:AddBombs(5)
    p:AddKeys(5)
    return true, "Supply drop!"
end

-- ── Combo effects (can't replicate with single custom action) ────────────────

function ttEffects.item_drain()
    for _ = 1, 3 do ttEffects.remove_item() end
    return true, "3 items drained!"
end

function ttEffects.cursed_blessing()
    -- 3 random items directly into inventory + all curses
    local p = getPlayer()
    if not p then return end
    for _ = 1, 3 do
        local item = 1 + rng:RandomInt(CollectibleType.NUM_COLLECTIBLES - 1)
        p:AddCollectible(item, 0, true)
    end
    ttEffects.all_curses()
    return true, "Cursed blessing!"
end

function ttEffects.sacrifice()
    -- near death then immediately get a devil item
    ttEffects.near_death()
    ttEffects.give_devil_item()
    return true, "Sacrifice!"
end

function ttEffects.chaos_reroll()
    -- spawn 5 item pedestals then D6 them all 3 times (viewer spawns items but they get rerolled)
    ttEffects.chaos_mode()
    local p = getPlayer()
    if not p then return end
    for _ = 1, 3 do
        p:UseActiveItem(CollectibleType.COLLECTIBLE_D6, UseFlag.USE_NOANIM | UseFlag.USE_NOANNOUNCER)
    end
    return true, "Chaos reroll!"
end

function ttEffects.absolute_trade()
    -- remove 2 held items, give devil item + heal (deal with the devil)
    ttEffects.remove_item()
    ttEffects.remove_item()
    ttEffects.give_devil_item()
    ttEffects.full_heal()
    return true, "Absolute trade!"
end

function ttEffects.worm_trio()
    -- Pin (62.0), Scolex (62.1), The Frail (62.2)
    Isaac.Spawn(EntityType.ENTITY_PIN, 0, 0, randomPos(), Vector(0,0), nil)
    Isaac.Spawn(EntityType.ENTITY_PIN, 1, 0, randomPos(), Vector(0,0), nil)
    Isaac.Spawn(EntityType.ENTITY_PIN, 2, 0, randomPos(), Vector(0,0), nil)
    return true, "Worm trio!"
end

function ttEffects.trapdoor()
    local p = getPlayer()
    if not p then return end
    if Isaac.GetChallenge ~= nil and Isaac.GetChallenge() ~= 0 then end -- skip in challenges
    p:UseActiveItem(CollectibleType.COLLECTIBLE_WE_NEED_TO_GO_DEEPER, UseFlag.USE_NOANIM | UseFlag.USE_NOANNOUNCER)
    return true, "Trapdoor!"
end

function ttEffects.UseActiveItem(itemId)
    itemId = tonumber(itemId)
    if not itemId then return false, "Invalid item" end
    if itemId == -1 then
        itemId = 1 + rng:RandomInt(CollectibleType.NUM_COLLECTIBLES - 1)
    end
    local p = getPlayer()
    if p then
        p:UseActiveItem(itemId, UseFlag.USE_NOANIM | UseFlag.USE_NOANNOUNCER)
        Isaac.DebugString("[TrinyTok] UseActiveItem ID=" .. tostring(itemId))
        
        local config = Isaac.GetItemConfig():GetCollectible(itemId)
        local name = config and config.Name or ("Item #" .. itemId)
        return true, "Used " .. name
    end
    return false, "Player not found"
end

function ttEffects.SpawnCollectible(itemId, amount, autoCollect)
    amount = tonumber(amount) or 1
    itemId = tonumber(itemId)
    if not itemId then return false, "Invalid item" end
    
    local isAuto = false
    if autoCollect == true or autoCollect == "true" or autoCollect == 1 or autoCollect == "1" then
        isAuto = true
    end

    Isaac.DebugString("[TrinyTok] SpawnCollectible ID=" .. tostring(itemId) .. " Qty=" .. tostring(amount) .. " Auto=" .. tostring(isAuto))
    
    local lastName = "Item"
    for i = 1, amount do
        local finalId = itemId
        if finalId == -1 then
            finalId = 1 + rng:RandomInt(CollectibleType.NUM_COLLECTIBLES - 1)
        end

        local config = Isaac.GetItemConfig():GetCollectible(finalId)
        lastName = config and config.Name or ("Item #" .. finalId)

        if isAuto then
            local p = getPlayer()
            if p then
                p:AnimateCollectible(finalId, "Pickup", "PlayerPickupSparkle")
                p:AddCollectible(finalId, 0, true)
            end
        else
            Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, finalId, randomPos(), Vector(0, 0), nil)
        end
    end

    local msg = (isAuto and "Gave " or "Spawned ") .. (amount > 1 and (amount .. "x ") or "") .. lastName
    return true, msg
end

-- Segmented bosses: must be spawned N times on the SAME tile to form one complete boss.
-- Format: [entityType_dot_variant] = requiredCount
local SEGMENTED_BOSSES = {
    ["28.0"]  = 3,  -- Chub 
    ["28.1"]  = 3,  -- C.H.A.D.
    ["28.2"]  = 3,  -- Carrion Queen
    ["19.0"]  = 10,  -- Larry Jr.
    ["19.1"]  = 4,  -- The Hollow
    ["19.2"]  = 6,  -- Tuff Twins
    ["19.3"]  = 5,  -- The Shell
    ["918.0"] = 5,  -- Turdlet
}

-- Returns the recommended segment count for a boss ID string (e.g. "28.0"), or nil.
function ttEffects.GetBossSegmentCount(entityId)
    if not entityId then return nil end
    local parts = {}
    for part in string.gmatch(tostring(entityId), "([^.]+)") do
        table.insert(parts, part)
    end
    local key = (parts[1] or "0") .. "." .. (parts[2] or "0")
    return SEGMENTED_BOSSES[key]
end

-- Spawns a boss (multiplies amount by segment count and puts them on the same tile).
function ttEffects.SpawnBoss(entityId, bossCount)
    bossCount = tonumber(bossCount) or 1
    if not entityId then return false, "Invalid entity" end

    local parts = {}
    for part in string.gmatch(tostring(entityId), "([^.]+)") do
        table.insert(parts, tonumber(part))
    end

    local eType    = parts[1] or 5
    local eVariant = parts[2] or 0
    local eSubtype = parts[3] or 0

    -- Get segment multiplier
    local segMultiplier = ttEffects.GetBossSegmentCount(entityId) or 1

    for b = 1, bossCount do
        -- Each boss unit gets its own random position
        local pos = randomPos()
        for s = 1, segMultiplier do
            Isaac.Spawn(eType, eVariant, eSubtype, pos, Vector(0, 0), nil)
        end

        -- Special case for Clutch (921.0): spawn 3 Clickety Clacks (889.0) needed for Phase 1
        if tostring(entityId) == "921.0" then
            for i = 1, 3 do
                Isaac.Spawn(889, 0, 0, randomPos(), Vector(0, 0), nil)
            end
        end

        -- Special case for Tuff Twins (19.2) or The Shell (19.3): spawn a Grimace (809.0) for bombs
        local tid = tostring(entityId)
        if tid == "19.2" or tid == "19.3" then
            Isaac.Spawn(809, 0, 0, randomPos(), Vector(0, 0), nil)
        end
    end
    
    local msg = "Spawned " .. bossCount .. "x " .. (segMultiplier > 1 and "segmented " or "") .. "boss"
    return true, msg
end

-- Spawns arbitrary entities each at a RANDOM position (suitable for mobs/enemies).
function ttEffects.SpawnEntity(entityId, amount)
    amount = tonumber(amount) or 1
    if not entityId then return false, "Invalid entity" end
    
    local parts = {}
    for part in string.gmatch(tostring(entityId), "([^.]+)") do
        table.insert(parts, tonumber(part))
    end
    
    local eType    = parts[1] or 5
    local eVariant = parts[2] or 0
    local eSubtype = parts[3] or 0
    
    for i = 1, amount do
        Isaac.Spawn(eType, eVariant, eSubtype, randomPos(), Vector(0, 0), nil)
    end
    return true, "Spawned " .. (amount > 1 and (amount .. "x entities") or "entity")
end

function ttEffects.SetHealth(amount)
    local p = getPlayer()
    if not p then return false, "Player not found" end
    p:SetFullHearts(tonumber(amount) or 6)
    return true, "Set health to " .. (tonumber(amount) or 6) .. " hearts"
end

function ttEffects.pixelation()
    Game():AddPixelation(600)
    return true, "Pixelation activated!"
end

function ttEffects.glitch_storm()
    local p = getPlayer()
    if not p then return false, "Player not found" end
    
    -- TMTRAINER is collectible ID 721
    local tmtrainerId = 721
    local hadTMTRAINER = p:HasCollectible(tmtrainerId)
    
    -- Temporarily give TMTRAINER to force item pools to return glitched IDs
    if not hadTMTRAINER then
        p:AddCollectible(tmtrainerId, 0, false)
    end
    
    local itemPool = Game():GetItemPool()
    for i = 1, 3 do
        local pos = randomPos()
        -- ItemPoolType.POOL_TREASURE is 1
        local glitchedSubType = itemPool:GetCollectible(1, true, rng:Next())
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, glitchedSubType, pos, Vector(0,0), nil)
    end
    
    if not hadTMTRAINER then
        p:RemoveCollectible(tmtrainerId)
    end
    
    return true, "Glitch storm!"
end

-- ── Timed effect tick (call from MC_POST_UPDATE) ───────────────────────────────

function ttEffects.Tick()
    local now = Isaac.GetTime()
    for key, info in pairs(ttEffects.timedEffects) do
        if now >= info.endTime then
            pcall(info.cleanup)
            ttEffects.timedEffects[key] = nil
        end
    end
end

-- ── Method map ────────────────────────────────────────────────────────────────

ttEffects.methods = {
    boss_wave         = ttEffects.boss_wave,
    enemy_wave        = ttEffects.enemy_wave,
    chaos_mode        = ttEffects.chaos_mode,
    all_curses        = ttEffects.all_curses,
    random_curse      = ttEffects.random_curse,
    near_death        = ttEffects.near_death,
    remove_item       = ttEffects.remove_item,
    controls_reversed = ttEffects.controls_reversed,
    inverse_screen    = ttEffects.inverse_screen,
    speed_boost       = ttEffects.speed_boost,
    damage_boost      = ttEffects.damage_boost,
    god_mode          = ttEffects.god_mode,
    full_heal         = ttEffects.full_heal,
    give_devil_item   = ttEffects.give_devil_item,
    give_random_item  = ttEffects.give_random_item,
    add_resources     = ttEffects.add_resources,
    spawn_item        = ttEffects.SpawnCollectible,
    use_item          = ttEffects.UseActiveItem,
    spawn_boss        = ttEffects.SpawnBoss,
    spawn_entity      = ttEffects.SpawnEntity,
    set_health        = ttEffects.SetHealth,
    item_drain        = ttEffects.item_drain,
    cursed_blessing   = ttEffects.cursed_blessing,
    sacrifice         = ttEffects.sacrifice,
    chaos_reroll      = ttEffects.chaos_reroll,
    absolute_trade    = ttEffects.absolute_trade,
    worm_trio         = ttEffects.worm_trio,
    trapdoor          = ttEffects.trapdoor,
    pixelation        = ttEffects.pixelation,
    glitch_storm      = ttEffects.glitch_storm,
}

return ttEffects


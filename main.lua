TrinyTokIsaac = RegisterMod("TrinyTokIsaac", 1)

local ttEffects  = require("ttEffects")
local ttprofiles = require("ttprofiles")

local socket_ok, socket = pcall(require, "socket")
local json_ok, json     = pcall(require, "json")

if not socket_ok then
    Isaac.DebugString("[TrinyTok] Socket Error: " .. tostring(socket))
end

-- ── Config ────────────────────────────────────────────────────────────────────

local TRINY_HOST      = "127.0.0.1"
local TRINY_PORT      = 58430
local RECONNECT_DELAY = 5000  -- ms

-- ── State ─────────────────────────────────────────────────────────────────────

local Client         = nil
local connected      = false
local lastReconnect  = 0
local buffer         = ""
local profilesSent   = false
local lastRawMessage = "None"

local rng = RNG()
rng:SetSeed(Random(), 1)
ttEffects.Init(rng)

-- ── Notifications ─────────────────────────────────────────────────────────────

local notifications = {}

local function notify(text)
    table.insert(notifications, { text = text, expiry = Isaac.GetTime() + 4000 })
end

local function canExecute()
    return Isaac.GetPlayer(0) ~= nil and Game():GetLevel():GetStage() > 0
end

-- ── TCP helpers ───────────────────────────────────────────────────────────────

local function sendPacket(tbl)
    if not connected or not Client then return end
    local ok, encoded = pcall(json.encode, tbl)
    if ok then
        pcall(function() Client:send(encoded .. "\0") end)
    end
end

local function tryConnect()
    if not socket_ok then return end
    
    -- Close existing client if any
    if Client then
        pcall(function() Client:close() end)
        Client = nil
    end

    Client = socket.tcp()
    if not Client then return end

    Client:settimeout(0)
    Client:setoption('keepalive', true)
    Client:setoption('tcp-nodelay', true)
    
    local _, err = Client:connect(TRINY_HOST, TRINY_PORT)
    if not err or err == "timeout" then
        connected = true
        profilesSent = false
        Isaac.DebugString("[TrinyTok] Connecting to server...")
    else
        connected = false
        Client = nil
    end
end

-- ── Execute a profile by ID ───────────────────────────────────────────────────

local function activateProfile(profileId, viewer)
    if not canExecute() then
        sendPacket({ type = "result", profileId = profileId, status = "game_not_started", viewer = viewer })
        return
    end

    local profile = nil
    for _, p in ipairs(ttprofiles.profiles) do
        if p.id == profileId then
            profile = p
            break
        end
    end

    if not profile then
        sendPacket({ type = "result", profileId = profileId, status = "unavailable", viewer = viewer })
        return
    end

    local success = true
    local msg = "ok"

    if type(profile.actions) == "function" then
        local ok, err = pcall(profile.actions, viewer)
        if not ok then success = false; msg = tostring(err) end
    elseif type(profile.actions) == "table" then
        for _, effectId in ipairs(profile.actions) do
            local fn = ttEffects.methods[effectId]
            if fn then
                local ok, err = pcall(fn)
                if not ok then success = false end
            end
        end
    end

    notify((viewer or "?") .. " -> " .. profile.name)
    sendPacket({ type = "result", profileId = profileId, status = success and "success" or "failure", viewer = viewer })
end

-- ── Core Update Loop ──────────────────────────────────────────────────────────

function TrinyTokIsaac:OnUpdate()
    local now = Isaac.GetTime()

    if not socket_ok then return end

    if not connected or not Client then
        if now > lastReconnect + RECONNECT_DELAY then
            lastReconnect = now
            tryConnect()
        end
        return
    end

    if not profilesSent then
        sendPacket({ type = "profiles", profiles = ttprofiles.profiles })
        profilesSent = true
    end

    local chunk, err, partial = Client:receive(8192)
    local data = chunk or partial
    
    if err == "closed" then
        connected = false
        profilesSent = false
        pcall(function() Client:close() end)
        Client = nil
        buffer = ""
        Isaac.DebugString("[TrinyTok] Connection closed by server")
        return
    end

    if data and #data > 0 then
        buffer = buffer .. data
    end

    while true do
        local i = string.find(buffer, "\n")
        if not i then break end
        local raw = string.sub(buffer, 1, i - 1)
        buffer = string.sub(buffer, i + 1)

        if #raw > 0 then
            lastRawMessage = raw
            Isaac.DebugString("[TrinyTok] Net Event: " .. raw)
            local ok, msg = pcall(json.decode, raw)
            if not ok then
                Isaac.DebugString("[TrinyTok] JSON Error: " .. tostring(msg))
            elseif msg and (msg.type == "activate" or msg.type == "custom_action") then
                if msg.type == "activate" then
                    activateProfile(msg.profileId, msg.viewer)
                                elseif msg.type == "custom_action" then
                    if not canExecute() then
                        sendPacket({ type = "result", status = "game_not_started", viewer = msg.viewer })
                    else
                        local success, resMsg = false, "Unknown action"
                        if msg.action == "spawn_item" then
                            success, resMsg = ttEffects.SpawnCollectible(msg.itemId, msg.amount, msg.autoCollect)
                        elseif msg.action == "use_item" then
                            success, resMsg = ttEffects.UseActiveItem(msg.itemId)
                        elseif msg.action == "spawn_boss" then
                            success, resMsg = ttEffects.SpawnBoss(msg.bossId, msg.amount)
                        elseif msg.action == "spawn_entity" then
                            success, resMsg = ttEffects.SpawnEntity(msg.entityId, msg.amount)
                        elseif msg.action == "set_health" then
                            success, resMsg = ttEffects.SetHealth(msg.hearts)
                        end
                        
                        notify((msg.viewer or "?") .. " -> " .. resMsg)
                        sendPacket({ type = "result", status = success and "success" or "failure", viewer = msg.viewer })
                    end
                end
            end
        end
    end

    if canExecute() then
        ttEffects.Tick()
    end
end

-- ── HUD render ────────────────────────────────────────────────────────────────

function TrinyTokIsaac:OnRender()
    local now = Isaac.GetTime()
    local keep = {}
    for _, n in ipairs(notifications) do
        if now < n.expiry then table.insert(keep, n) end
    end
    notifications = keep

    -- Status dot
    -- local dotColor = connected and {0.2, 0.9, 0.2} or {0.7, 0.2, 0.2}
    -- Isaac.RenderText("[TT]", 10, 10, dotColor[1], dotColor[2], dotColor[3], 1)

    -- Debug Info
    -- Isaac.RenderText("Last: " .. lastRawMessage, 10, 22, 0.7, 0.7, 0.7, 1)

    -- Notifications
    -- for i, n in ipairs(notifications) do
    --     Isaac.RenderText(n.text, 10, 35 + (i * 12), 1, 1, 1, 1)
    -- end
end

-- ── Game Start Cleanup ────────────────────────────────────────────────────────

function TrinyTokIsaac:OnGameStart(isContinued)
    local seeds = Game():GetSeeds()

    if seeds:HasSeedEffect(SeedEffect.SEED_CONTROLS_REVERSED) then
        seeds:RemoveSeedEffect(SeedEffect.SEED_CONTROLS_REVERSED)
    end
    if seeds:HasSeedEffect(SeedEffect.SEED_RETRO_VISION) then
        seeds:RemoveSeedEffect(SeedEffect.SEED_RETRO_VISION)
    end
    if seeds:HasSeedEffect(SeedEffect.SEED_INVINCIBILITY) then
        seeds:RemoveSeedEffect(SeedEffect.SEED_INVINCIBILITY)
    end

    -- Cancel all pending timed effect cleanups from the previous run
    ttEffects.timedEffects = {}
end

TrinyTokIsaac:AddCallback(ModCallbacks.MC_POST_UPDATE, TrinyTokIsaac.OnUpdate)
TrinyTokIsaac:AddCallback(ModCallbacks.MC_POST_RENDER, TrinyTokIsaac.OnRender)
TrinyTokIsaac:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, TrinyTokIsaac.OnGameStart)

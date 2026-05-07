--[[
    TrinyTok Profile Definitions
    ─────────────────────────────
    Add or edit profiles here. Each profile appears in the Triny-Tok website
    and can be assigned to a TikTok gift.

    Profile fields:
        id       (string) – unique key, no spaces
        name     (string) – display name shown in website
        desc     (string) – short description shown in website
        category (string) – grouping color in website: "Chaos", "Curses", "Punishment", "Timed", "Boon"
        actions  (table)  – list of effect IDs from ttEffects.lua to run in order
                            OR a custom function: actions = function(viewer) ... end
]]

local ttprofiles = {}

ttprofiles.profiles = {

    -- ── Chaos ────────────────────────────────────────────────────────────────
    {
        id       = "boss_rush",
        name     = "Boss Rush",
        desc     = "Spawns 3 random bosses",
        category = "Chaos",
        actions  = {"boss_wave"},
    },
    {
        id       = "total_chaos",
        name     = "Total Chaos",
        desc     = "5 items + 10 enemies + all curses at once",
        category = "Chaos",
        actions  = {"chaos_mode", "all_curses"},
    },
    {
        id       = "mob_rush",
        name     = "Mob Rush",
        desc     = "15 random enemies swarm the room",
        category = "Chaos",
        actions  = {"enemy_wave"},
    },

    -- ── Curses ───────────────────────────────────────────────────────────────
    {
        id       = "all_curses",
        name     = "All Curses",
        desc     = "Adds all floor curses for the current floor",
        category = "Curses",
        actions  = {"all_curses"},
    },
    {
        id       = "curse_roulette",
        name     = "Curse Roulette",
        desc     = "Random curse applied",
        category = "Curses",
        actions  = {"random_curse"},
    },

    -- ── Punishment ───────────────────────────────────────────────────────────
    {
        id       = "near_death",
        name     = "Near Death",
        desc     = "Reduces to half a heart",
        category = "Punishment",
        actions  = {"near_death"},
    },
    {
        id       = "item_yoink",
        name     = "Item Yoink",
        desc     = "Removes a random held item",
        category = "Punishment",
        actions  = {"remove_item"},
    },
    {
        id       = "nightmare",
        name     = "Nightmare",
        desc     = "Near death + all curses + enemy wave",
        category = "Punishment",
        actions  = {"near_death", "all_curses", "enemy_wave"},
    },

    -- ── Timed ────────────────────────────────────────────────────────────────
    {
        id       = "upside_down",
        name     = "Upside Down",
        desc     = "Reversed controls for 30 seconds",
        category = "Timed",
        actions  = {"controls_reversed"},
    },
    {
        id       = "speed_demon",
        name     = "Speed Demon",
        desc     = "Double speed for 30 seconds",
        category = "Timed",
        actions  = {"speed_boost"},
    },
    {
        id       = "god_mode",
        name     = "God Mode",
        desc     = "Invincible for 15 seconds",
        category = "Timed",
        actions  = {"god_mode"},
    },

    -- ── Buff ─────────────────────────────────────────────────────────────────
    {
        id       = "full_heal",
        name     = "Full Heal",
        desc     = "Restores all health",
        category = "Buff",
        actions  = {"full_heal"},
    },
    {
        id       = "devil_deal",
        name     = "Free Devil Deal",
        desc     = "Gives a random devil collectible",
        category = "Buff",
        actions  = {"give_devil_item"},
    },
    {
        id       = "supply_drop",
        name     = "Supply Drop",
        desc     = "10 coins + 5 bombs + 5 keys",
        category = "Buff",
        actions  = {"add_resources"},
    },
    {
        id       = "jackpot",
        name     = "Jackpot",
        desc     = "Random item + full heal + supplies",
        category = "Buff",
        actions  = {"give_random_item", "full_heal", "add_resources"},
    },
    {
        id       = "sacrifice",
        name     = "Sacrifice",
        desc     = "Drops to half heart — then immediately gives a devil item",
        category = "Buff",
        actions  = {"sacrifice"},
    },

    -- ── Chaos ────────────────────────────────────────────────────────────────
    {
        id       = "chaos_reroll",
        name     = "Chaos Reroll",
        desc     = "Spawns 5 item pedestals + enemies, then D6s them all 3 times",
        category = "Chaos",
        actions  = {"chaos_reroll"},
    },
    {
        id       = "cursed_blessing",
        name     = "Cursed Blessing",
        desc     = "3 random items directly into inventory — but adds all curses for the current floor",
        category = "Chaos",
        actions  = {"cursed_blessing"},
    },

    {
        id       = "trapdoor",
        name     = "Trapdoor",
        desc     = "Spawns a trapdoor under you",
        category = "Chaos",
        actions  = {"trapdoor"},
    },
    {
        id       = "worm_trio",
        name     = "Worm Trio",
        desc     = "Spawns Pin, Scolex, and The Frail",
        category = "Chaos",
        actions  = {"worm_trio"},
    },

    -- ── Punishment ───────────────────────────────────────────────────────────
    {
        id       = "item_drain",
        name     = "Item Drain",
        desc     = "Removes 3 random held items",
        category = "Punishment",
        actions  = {"item_drain"},
    },
    {
        id       = "health_scare",
        name     = "Health Scare",
        desc     = "Near death + reversed controls for 30s",
        category = "Punishment",
        actions  = {"near_death", "controls_reversed"},
    },
    {
        id       = "absolute_trade",
        name     = "The Trade",
        desc     = "Removes 2 held items, gives a devil item + full heal",
        category = "Punishment",
        actions  = {"absolute_trade"},
    },




    -- ── Glitch / Misc ────────────────────────────────────────────────────────
    {
        id       = "retro_vision",
        name     = "Retro Vision",
        desc     = "Adds intense pixelation to the screen",
        category = "Glitch",
        actions  = {"pixelation"},
    },
    {
        id       = "glitch_storm",
        name     = "Glitch Storm",
        desc     = "Spawns 3 TMTRAINER items",
        category = "Glitch",
        actions  = {"glitch_storm"},
    },

    --[[
    ── Add your own profiles below ───────────────────────────────────────────

    Example using multiple effects:
    {
        id       = "my_profile",
        name     = "My Custom Profile",
        desc     = "Does crazy stuff",
        category = "Chaos",
        actions  = {"boss_wave", "all_curses", "near_death"},
    },

    Example using a custom Lua function (full control):
    {
        id       = "custom_fn",
        name     = "Custom Function",
        desc     = "Runs custom Lua code",
        category = "Chaos",
        actions  = function(viewer)
            local p = Isaac.GetPlayer(0)
            p:AddHearts(99)
            Isaac.RenderText("Hello " .. viewer, 100, 100, 1,1,1,1)
        end,
    },
    ]]
}

return ttprofiles

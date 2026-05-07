# TrinyTok Isaac Bridge

A **The Binding of Isaac: Repentance** mod that connects to the [TrinyTok](https://github.com/Pencea-Flavius/Triny-Tok) backend, letting TikTok viewers trigger in-game effects by sending gifts during a livestream.

## How It Works

```
TikTok Gift → TrinyTok Backend (Node.js) → TCP :58430 → Isaac Mod → Game Effect
```

The mod opens a TCP socket to `127.0.0.1:58430` and listens for JSON commands from the TrinyTok server. On startup it sends the full list of available profiles to the backend so the website can display them.

## Effects

### Chaos
| Profile | Description |
|---|---|
| Boss Rush | Spawns 3 random bosses |
| Mob Rush | 15 random enemies swarm the room |
| Total Chaos | 5 items + 10 enemies + all curses |
| Chaos Reroll | Spawns 5 item pedestals + enemies, D6s them 3 times |
| Cursed Blessing | 3 random items in inventory — but adds all curses |
| Trapdoor | Spawns a trapdoor under you |
| Worm Trio | Spawns Pin, Scolex, and The Frail |

### Curses
| Profile | Description |
|---|---|
| All Curses | Adds all floor curses |
| Curse Roulette | Applies one random curse |

### Punishment
| Profile | Description |
|---|---|
| Near Death | Reduces to half a heart |
| Item Yoink | Removes a random held item |
| Item Drain | Removes 3 random held items |
| Nightmare | Near death + all curses + enemy wave |
| Health Scare | Near death + reversed controls for 30s |
| The Trade | Removes 2 held items, gives a devil item + full heal |

### Timed
| Profile | Duration | Description |
|---|---|---|
| Upside Down | 30s | Reversed controls |
| Speed Demon | 30s | Double movement speed |
| God Mode | 15s | Full invincibility |

### Buff
| Profile | Description |
|---|---|
| Full Heal | Restores all health |
| Free Devil Deal | Gives a random devil collectible |
| Supply Drop | 10 coins + 5 bombs + 5 keys |
| Jackpot | Random item + full heal + supplies |
| Sacrifice | Drops to half heart, then immediately gives a devil item |

### Glitch
| Profile | Description |
|---|---|
| Retro Vision | Intense screen pixelation |
| Glitch Storm | Spawns 3 TMTRAINER glitched items |

## Adding Custom Effects

Edit `ttprofiles.lua` to add new profiles. Each profile maps to one or more effects from `ttEffects.lua`:

```lua
{
    id       = "my_profile",
    name     = "My Profile",
    desc     = "Short description shown on the website",
    category = "Chaos",   -- Chaos | Curses | Punishment | Timed | Buff | Glitch
    actions  = {"boss_wave", "all_curses"},  -- run effects in order
},
```

Or use a custom Lua function for full control:

```lua
{
    id      = "custom_fn",
    name    = "Custom",
    desc    = "Does something custom",
    category = "Chaos",
    actions = function(viewer)
        local p = Isaac.GetPlayer(0)
        p:AddHearts(99)
    end,
},
```

## Protocol

The mod communicates over TCP using newline-delimited JSON (`\n`).

**Incoming (server → mod):**
```json
{ "type": "activate", "profileId": "boss_rush", "viewer": "username" }
{ "type": "custom_action", "action": "spawn_item", "itemId": 114, "amount": 1, "autoCollect": false, "viewer": "username" }
```

**Outgoing (mod → server):**
```json
{ "type": "profiles", "profiles": [...] }
{ "type": "result", "profileId": "boss_rush", "status": "success", "viewer": "username" }
```

**Custom action types:** `spawn_item`, `use_item`, `spawn_boss`, `spawn_entity`, `set_health`
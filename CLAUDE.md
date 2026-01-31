# Kodo Tag - Project Context

## Overview
A Roblox adaptation of the classic **Warcraft 3 custom map "Kodo Tag"**. Players must survive against waves of Kodos by building mazes and towers. Uses a **lobby/game server architecture** where players select game modes in a lobby, then teleport to reserved servers for actual gameplay.

## Original Warcraft 3 Kodo Tag

### Core Concept
In the original WC3 map, players control a fragile "Runner" unit (1 HP) that must survive for **30 minutes** against pursuing Kodos. The Kodos chase players relentlessly, and getting caught means death.

### Original Mechanics
- **Maze Building**: Players build walls/burrows to create long mazes. Runners can slip through small gaps that Kodos cannot fit through.
- **Kodo Behavior**: Kodos prioritize chasing players. They only attack buildings when no players are accessible.
- **Towers**: Deal damage to Kodos and generate income when attacking.
- **Economy**: Gold/lumber earned from killing Kodos. Central shop sells powerful items.
- **Death Mechanic**: Caught players can spend gold on abilities to help surviving teammates.
- **Workers/Mechanics**: Harvest gold and repair buildings.

### Original Game Modes (from Kodo Tag: Reforged)
| Mode | Description |
|------|-------------|
| **Maze** | Classic - build long mazes like tower defense |
| **Bunker** | Kodos attack ALL buildings, not just when blocked |
| **Tower Defense** | Stronger towers, more Kodos |
| **God** | Stronger heroes and towers, massive Kodo waves |

### Win Condition
Survive 30 minutes OR eliminate all Kodos through coordinated defense.

## Roblox Adaptation Differences
This version adapts the concept for Roblox with some changes:
- **Wave-based** instead of continuous 30-minute survival
- **Shared team lives** instead of individual permadeath
- **Resurrection shrines** allow reviving teammates
- **Third-person player control** instead of RTS-style unit control
- **Gold mines** as resource nodes instead of worker harvesting
- **Lobby matchmaking** with game pads for different player counts

## Architecture

### Server Split
- **Lobby Server** (main place): Players spawn here, walk onto game pads to queue
- **Game Server** (reserved): Actual gameplay happens here, created on-demand via `TeleportService:ReserveServer()`

Scripts check `isReservedServer` to determine which mode to run:
```lua
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
```

### Key Server Scripts
| Script | Lobby | Game | Purpose |
|--------|-------|------|---------|
| `GameInitializer` | ✓ | ✓ | Detects server type, sets up spawns, receives teleport data |
| `PadManager` | ✓ | - | Handles game pads (SOLO/SMALL/MEDIUM/LARGE), countdown, teleport |
| `RoundManager` | - | ✓ | Wave spawning, player lives, game over, return to lobby |
| `BuildingManager` | - | ✓ | Placement system for structures |
| `TurretManager` | - | ✓ | Turret targeting and firing |
| `GoldMineManager` | - | ✓ | Gold mine mechanics |
| `UpgradeManager` | - | ✓ | Structure upgrades |
| `SellSystemServer` | - | ✓ | Selling structures for gold |
| `KodoAI` | - | ✓ | Enemy pathfinding and behavior |

### Key Client Scripts
| Script | Purpose |
|--------|---------|
| `NotificationHandler` | Game HUD, notifications, game over screen |
| `PlacementSystem` | Building placement UI and preview |
| `MiningSystem` | Gold mine interaction |
| `SoloStartHandler` | E key to start solo games |
| `Workshop` | Building selection menu |
| `SellSystem` | Sell mode UI |
| `GoldDisplayUpdater` | Gold counter (being phased into game info panel) |

## Game Flow
1. Player joins → spawns in lobby at `LobbySpawns`
2. Player walks onto a game pad (SOLO, SMALL, MEDIUM, LARGE)
3. For SOLO: Press E to start immediately
4. For multiplayer: Wait for min players, countdown starts, then teleport
5. `TeleportService:TeleportAsync()` sends players to reserved server with game data
6. `GameInitializer` receives teleport data, signals `RoundManager` when players ready
7. Waves of Kodos spawn, players defend
8. On all players dead: Show game over screen, teleport back to lobby after 10s

## Current Status (as of Jan 2026)

### Recently Implemented
- Lobby pad system with SOLO/SMALL/MEDIUM/LARGE modes
- Reserved server teleportation with game config passing
- Game over screen with player stats (kills, deaths, saves, gold earned)
- Auto-return to lobby after game over
- Game info panel UI (top-right, shows wave/gold/lives)
- Player stats panel (deaths, saves, kills)
- Lobby Pad UI - Shows game mode info when standing on pads
- Sell Mode UI - Press X or click button, then click buildings to sell
- Difficulty Scaling - Exponential scaling with special wave types

### Difficulty Scaling System
- **Exponential growth**: Stats scale by multipliers each wave (not linear)
- **Player count scaling**: More players = more Kodos + higher health
- **Pad type difficulty**: SOLO is easier, LARGE is harder
- **Special waves**:
  - Boss waves (every 5): One powerful boss Kodo
  - Swarm waves (every 7): Triple kodos, but weaker and faster (all Horde type)
  - Elite waves (every 10): Half kodos, but much stronger, 2x gold

### Kodo Types & Turret Counters
| Kodo Type | Color | Resistances | Weaknesses | Best Counter |
|-----------|-------|-------------|------------|--------------|
| Normal | Brown | None | None | Any turret |
| Armored | Gray | -50% physical | +50% poison, AOE | Poison, Cannon |
| Swift | White | -30% poison, Fast | +50% frost effect | Frost Turret |
| Frostborn | Ice Blue | Immune to frost | +30% physical | Basic turrets |
| Venomous | Green | Immune to poison | +30% frost | Frost Turret |
| Horde | Dark Red | -20% physical, Small | +100% AOE/multishot | Cannon, MultiShot |
| Mini | Orange | -20% physical (small target) | +50% AOE/multishot | Cannon, MultiShot |

**Mini Kodos**: Tiny kodos that can fit through maze gaps (same size as players). Very fast, very fragile. Spawn on wave 6, 12, 18, etc. Forces players to use turrets, not just mazes!

**Spawn Rates**: Normal kodos decrease over time, special types appear progressively (Armored/Swift from wave 4+, Frostborn/Venomous from wave 6+, Horde from wave 8+).

### Turret Types
| Turret | Cost | Damage Type | Special | Best Against |
|--------|------|-------------|---------|--------------|
| Turret | 50g | Physical | Balanced | Frostborn |
| FastTurret | 75g | Physical | Rapid fire | Frostborn |
| SlowTurret | 30g | Physical | High damage | Frostborn |
| FrostTurret | 100g | Frost | 50% slow, 3s | Swift, Venomous |
| PoisonTurret | 90g | Poison | 10 DPS, 5s | Armored |
| MultiShotTurret | 120g | Multishot | 3 projectiles | Horde |
| CannonTurret | 150g | AOE | 15 radius | Armored, Horde |

### Maze Building Mechanics
The core mechanic from original WC3 Kodo Tag - players build mazes to slow Kodos while turrets deal damage.

**Two Structure Types**:
| Structure | Cost | Health | Size | Purpose |
|-----------|------|--------|------|---------|
| **Barricade** | 15g | 75 HP | 2x5x2 | Small pillar for mazes. 3-stud gaps let players kite through |
| **Reinforced Wall** | 60g | 500 HP | 12x8x2 | Heavy defense, protects turrets |

**Gap Mechanics**:
- **Kodo Agent Size**: `AgentRadius = 3.5`, `AgentHeight = 8` - Kodos need 7+ stud gaps to pass
- **Player Size**: Players can fit through 3+ stud gaps
- **Tactical Gaps**: 3-6 studs = player-only passage, 7+ studs = both can pass

**Kodo Pathfinding Behavior**:
- Kodos use PathfindingService with large agent size
- They try to find paths around walls before attacking
- **Frustration System**: Kodos must fail pathfinding 3+ times AND reach frustration level 5+ before attacking
- This gives players time to escape through small gaps while Kodos take the long way

**Building Strategy**:
- Use **Barricades** to build long mazes - cheap, fast, disposable
- Use **Reinforced Walls** around your base/turrets for protection
- Place turrets behind walls so Kodos must navigate the maze
- Grid size is 5 studs for precise placement

### Next Steps (Suggested)
1. **All-Players Leaderboard** - Show everyone's stats on game over screen
2. **High Score Tracking** - Save best wave reached (DataStore)
3. **Death Abilities** - Dead players can help survivors (from original WC3)
4. **Map Variations** - Different maps for SOLO vs LARGE games
5. **Visual damage indicators** - Show resist/weak floating text

### Features to Consider (from Original)
- **Maze Mode vs Bunker Mode** - Toggle whether Kodos only attack buildings when blocked
- **Death Abilities** - Dead players can spend gold to help teammates (slow Kodos, heal, etc.)
- **Runner Variety** - Different player classes with unique abilities
- **Central Shop** - Powerful items purchasable mid-game
- **30-Minute Timer** - Classic survival win condition as alternative to waves
- **Income Towers** - Towers that generate gold when attacking

## Game Pad Types
| Type | Min | Max | Use Case |
|------|-----|-----|----------|
| SOLO | 1 | 1 | Single player, instant start with E key |
| SMALL | 2 | 4 | Quick co-op games |
| MEDIUM | 3 | 6 | Standard multiplayer |
| LARGE | 4 | 10 | Big team games |

Pads are configured via attributes: `PadType`, `MinPlayers`, `MaxPlayers`, `CountdownTime`

## Remote Events
| Event | Direction | Purpose |
|-------|-----------|---------|
| `ShowNotification` | Server→Client | Display notification text |
| `ShowGameOver` | Server→Client | Trigger game over screen |
| `UpdatePadStatus` | Server→Client | Broadcast pad player counts (lobby) |
| `SoloStartRequest` | Client→Server | Player pressed E on solo pad |
| `UpdateGold` | Server→Client | Sync gold amount |
| `UpdateWave` | Server→Client | Sync current wave |
| `UpdateLives` | Server→Client | Sync remaining lives |
| `PlayerStatsUpdate` | Server→Client | Sync player stats |

## Conventions
- Server scripts: `*.server.lua`
- Client scripts: `*.client.lua`
- Module scripts: `*.lua` (no suffix)
- Use attributes on workspace objects for configuration
- Check `isReservedServer` at top of scripts to determine behavior

## References
- [Kodo Tag: Reforged](https://wc3maps.com/map/305001) - Modern WC3 version with multiple game modes
- [Kodo Tag: X-Treme](https://maps.w3reforged.com/maps/categories/tag-tiggy-tick/kodo-tag-x-treme) - Popular variant with 8 runner classes
- [Kodo Tag Overview](https://gaming-tools.com/warcraft-3/kodo-tag/) - Strategy guide and mechanics breakdown

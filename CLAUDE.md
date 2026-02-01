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
| `RepairManager` | - | ✓ | Hold F to repair structures for gold |
| `HighScoreManager` | - | ✓ | DataStore high scores and global leaderboard |
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
- **High Score System** - Persistent personal bests + global top 10 leaderboard
- **Farm Income Visual** - Floating "+X gold" text above farms when generating income
- **Health-Based Selling** - Sell value scales with structure health percentage
- **Ghost Power-Up** - Makes player semi-transparent, Kodos completely ignore them for 5s
- **Frost Turret Fix** - Blue projectile, 30% slow, "SLOWED" indicator (no physics issues)
- **Bigger Barricades** - 3x6x3 size with 2-stud gaps for tighter maze kiting
- **Repair System** - Hold F near damaged structures to repair (1 gold per 5 HP)

### Difficulty Scaling System
- **Exponential growth**: Stats scale by multipliers each wave (not linear)
- **Player count scaling**: More players = more Kodos + higher health
- **Pad type difficulty**: SOLO is easier, LARGE is harder
- **Special waves**:
  - Boss waves (every 5): One powerful boss Kodo
  - Swarm waves (every 7): Triple kodos, but weaker and faster (all Horde type)
  - Elite waves (every 10): Half kodos, but much stronger, 2x gold

### Kodo Types & Turret Counters
| Kodo Type | Color | Speed | HP | Struct Dmg | Resistances | Weaknesses |
|-----------|-------|-------|-----|------------|-------------|------------|
| Normal | Brown | 1.0x (16) | 1.0x | 1.0x | None | None |
| Swift | White | 1.5x (24) | 0.6x | 0.7x | -30% poison | +50% frost |
| Mini | Orange | 1.6x (26) | 0.25x | 0.3x | -20% physical | +50% AOE/multi |
| Horde | Dark Red | 1.3x (21) | 0.4x | 0.5x | -20% physical | +100% AOE/multi |
| Venomous | Green | 1.1x (18) | 0.9x | 1.0x | Immune poison | +30% frost |
| Frostborn | Ice Blue | 0.9x (14) | 1.1x | 1.0x | Immune frost | +30% physical |
| Armored | Gray | 0.7x (11) | 1.5x | 1.5x | -50% physical | +50% poison/AOE |
| Brute | Dark Brown | 0.5x (8) | 2.0x | **3.0x** | -40% phys, -20% frost | +30% poison |

**Speed Reference**: Player speed = 16. Normal Kodo = same speed as player.

**Mini Kodos**: Tiny kodos that can fit through maze gaps (same size as players). Very fast, very fragile. Spawn after wave 5.

**Brute Kodos**: Slow but devastating. 30% larger, triple structure damage. Can be outrun but destroys walls fast. Spawn after wave 8.

### Death Abilities
Dead players can spend gold to help surviving teammates:

| Ability | Cost | Cooldown | Effect |
|---------|------|----------|--------|
| **Slow Aura** | 40g | 15s | Slow all Kodos by 50% for 5 seconds |
| **Lightning Strike** | 50g | 20s | Deal 100 damage to all Kodos |
| **Speed Boost** | 30g | 25s | All survivors run 50% faster for 8 seconds |
| **Quick Revive** | 100g | - | Instantly respawn (one-time per death) |

Death abilities panel appears on the left side of screen when player dies.

### Power-Ups
Random power-ups spawn around the map every 25 seconds (max 5 at once). They despawn after 30 seconds if not collected. Shown as pulsing white dots on minimap.

| Power-Up | Effect | Weight |
|----------|--------|--------|
| **Gold Rush** | +50 gold instantly | 30% |
| **Speed Surge** | 50% movement speed for 10s | 20% |
| **Ghost** | Invisible to Kodos for 5s (semi-transparent, Kodos ignore you) | 10% |
| **Turret Boost** | Your turrets deal 2x damage for 15s | 15% |
| **Repair Kit** | Heal all your structures 50% | 15% |
| **Freeze Bomb** | Freeze all Kodos for 4s | 10% |

Power-ups spawn at random positions, avoiding player spawn areas. They incentivize leaving base to take risks for rewards.

### Economy System
Multiple income sources with different risk/reward profiles:

| Source | Risk | Income Rate | Notes |
|--------|------|-------------|-------|
| **Base Passive** | None | 1g / 5 sec | Always active |
| **Farms** | Low | 1g / 5 sec per farm | Build near base, can be destroyed |
| **Gold Mines** | High | ~10g / sec while mining | Must stand at mine, exposed to Kodos |
| **Kill Gold** | Medium | Per Kodo kill | Rewards good turret placement |
| **Power-ups** | High | Variable | Random spawns, Gold Rush = +50g |

### Fixed Gold Mines
4 permanent gold mines at fixed locations around the map (North, South, East, West - 70 studs from center):

- **300 gold** per mine
- **45 second respawn** after depletion
- Shown as **gold diamonds** on minimap/full map
- Labels show mine name (e.g., "North Mine")
- Mining requires standing within 12 studs

Strategic importance: Mines are placed between player spawns and the dangerous outer areas, creating risk/reward decisions.

### Bonus Veins
Random small gold veins that spawn around the map, creating opportunistic moments:

- **30-50 gold** per vein (random)
- Spawn every **35 seconds** at random locations
- Despawn after **18 seconds** if not collected
- Shown as **pulsing bright gold circles** on minimap (faster pulse than fixed mines)
- UI notification when a vein spawns nearby
- Does NOT respawn - one-time collection

Adds dynamic "split-second decision" gameplay: "A vein just spawned near those Kodos... do I risk it?"

**Spawn Rates**: Normal kodos decrease over time, special types appear progressively (Armored/Swift from wave 4+, Frostborn/Venomous from wave 6+, Horde from wave 8+).

### Turret Types
| Turret | Cost | Damage Type | Special | Best Against |
|--------|------|-------------|---------|--------------|
| Turret | 50g | Physical | Balanced | Frostborn |
| FastTurret | 75g | Physical | Rapid fire | Frostborn |
| SlowTurret | 30g | Physical | High damage | Frostborn |
| FrostTurret | 100g | Frost | 30% slow, 3s (blue projectile, "SLOWED" indicator) | Swift, Venomous |
| PoisonTurret | 90g | Poison | 10 DPS, 5s | Armored |
| MultiShotTurret | 120g | Multishot | 3 projectiles | Horde |
| CannonTurret | 150g | AOE | 15 radius | Armored, Horde |

### Maze Building Mechanics
The core mechanic from original WC3 Kodo Tag - players build mazes to slow Kodos while turrets deal damage.

**Two Structure Types**:
| Structure | Cost | Health | Size | Purpose |
|-----------|------|--------|------|---------|
| **Barricade** | 15g | 100 HP | 3x6x3 | Maze pillar. 2-stud gaps let players squeeze through for kiting |
| **Reinforced Wall** | 60g | 500 HP | 12x8x2 | Heavy defense, protects turrets |

**Gap Mechanics**:
- **Kodo Agent Size**: `AgentRadius = 3.5`, `AgentHeight = 8` - Kodos need 7+ stud gaps to pass
- **Player Size**: Players can squeeze through 2+ stud gaps
- **Tactical Gaps**: 2-6 studs = player-only passage, 7+ studs = both can pass
- **Grid**: 5 studs. Barricades (3 wide) create 2-stud gaps - tight but passable for players

**Kodo Pathfinding Behavior**:
- Kodos use PathfindingService with large agent size
- They try to find paths around walls before attacking
- **Frustration System**: Kodos must fail pathfinding 2+ times OR reach frustration level 3+ before attacking
- Faster stuck detection (0.8s) and quicker wall attacks (0.6s cooldown)
- **Spreading**: Each kodo has random target offset (±8 studs) to prevent clumping
- Prioritizes attacking walls/barricades over turrets when stuck

**Building Strategy**:
- Use **Barricades** to build long mazes - cheap, fast, disposable
- Use **Reinforced Walls** around your base/turrets for protection
- Place turrets behind walls so Kodos must navigate the maze
- Grid size is 5 studs for precise placement

### Recent Session (Jan 2026) - Visual Polish & Custom Models

#### Visual Effects Added
- **Projectile trails** - Proper trails with width taper and color fade
- **Projectile glow** - PointLight on bullets
- **Impact effects** - Particle burst + light flash on hit
- **Muzzle flash** - Improved with fade and light
- **Building pop-in** - Scale animation with sparkles when construction completes
- **Kodo death** - Ragdoll physics + dissolve particles + soul effect rising

#### Dynamic Model Sizing System

The placement preview now automatically reads model sizes from ReplicatedStorage, eliminating size mismatches between preview and actual buildings.

**How it works:**
1. Models are stored in `ReplicatedStorage > BuildableItems` (copy of ServerStorage folder)
2. On load, PlacementSystem reads each model's bounding box size
3. Preview clones the actual model (with Highlight effect for valid/invalid)
4. Server still spawns from ServerStorage

**Folder structure:**
```
ReplicatedStorage
└── BuildableItems
    ├── Turrets (Turret, FastTurret, etc.)
    ├── Economy (Farm, Workshop)
    ├── Defense (Barricade, Wall)
    └── Auras (SpeedAura, DamageAura, etc.)
```

**When you change a model:**
1. Edit it in ServerStorage (where server spawns from)
2. Copy/paste the updated model to ReplicatedStorage (for client preview)
3. That's it - sizes update automatically

#### Custom Model Setup

**Turrets** (in `ServerStorage > BuildableItems > Turrets`):
- Turrets do NOT rotate to aim - they stay still
- Projectiles shoot from top center toward enemies
- Required structure:
  ```
  Turret (Model)
  ├── [Any parts]       ← Your model parts
  ├── PrimaryPart       → Set to main body part
  ├── DisplayName (StringValue) = "Basic Turret"
  └── Cost (IntValue) = 50
  ```
- All parts should be `Anchored = false` (code handles anchoring)

**Kodos** (in `ServerStorage > KodoStorage > Kodo`):
- Must be a rigged character with Humanoid
- Required structure:
  ```
  Kodo (Model)
  ├── Humanoid           ← Required
  ├── HumanoidRootPart   ← Required, CanCollide = true
  └── [Body parts]       ← Weld to HumanoidRootPart
  ```
- If model parts don't move with root, weld them:
  ```lua
  -- Run in Command Bar with model selected
  local model = game.Selection:Get()[1]
  local root = model:FindFirstChild("HumanoidRootPart")
  for _, part in pairs(model:GetDescendants()) do
      if part:IsA("BasePart") and part ~= root then
          local weld = Instance.new("WeldConstraint")
          weld.Part0 = root
          weld.Part1 = part
          weld.Parent = part
          part.Anchored = false
      end
  end
  ```
- Code auto-adds: facing direction via BodyGyro (smooth rotation)
- If movement is glitchy, ensure only HumanoidRootPart has `CanCollide = true`, other parts = false
- Set Humanoid `HipHeight` = 2-3 if model drags on ground

#### Minimap
Already implemented in `StarterGui/MinimapGui/Minimap.client.lua`:
- Corner minimap (always visible)
- Full map overlay (press M to toggle)
- Shows: players, kodos, structures, gold mines, power-ups

#### Sell System
- Sells for 50% of original cost × health percentage
- Full health wall (60g) = 30g refund
- Half health wall = 15g refund
- Shows yellow notification when selling damaged buildings
- Located in `ServerScriptService/SellSystemServer.server.lua`

#### Deferred for Later
- Turret barrel rotation (requires multi-part turret model with separate Barrel)
- Custom walk animations (currently just facing direction)
- Sound effects

### High Score System
Persistent high scores and global leaderboard using DataStore:

**Server Script**: `ServerScriptService/HighScoreManager.server.lua`

**Features**:
- **Personal Best**: Tracks each player's highest wave reached
- **Global Leaderboard**: Top 10 players across all servers (OrderedDataStore)
- **Auto-Save**: High scores saved automatically on game over
- **New Record Indicator**: Shows animated "NEW RECORD!" when player beats personal best

**Data Stored Per Player**:
- `bestWave` - Highest wave reached
- `bestWaveDate` - When the record was set (os.time)
- `totalGames` - Number of games played
- `totalKills` - Lifetime Kodo kills

**Client Access** (RemoteFunction):
```lua
-- Get personal high score
local data = ReplicatedStorage.GetHighScore:InvokeServer()

-- Get global top 10
local top10 = ReplicatedStorage.GetHighScore:InvokeServer("global")

-- Get both at once
local both = ReplicatedStorage.GetHighScore:InvokeServer("both")
-- both.personal, both.global
```

**Game Over Screen** shows:
- Session stats (kills, deaths, saves, gold earned)
- Personal best wave
- "NEW RECORD!" indicator with gold animation
- Global Top 10 leaderboard (right side)

### Farm Income Visual
Floating "+X gold" text appears above each farm when it generates income (every 5 seconds). Gold-colored text floats up and fades out.

### Repair System
Hold F near your damaged structures to repair them:

- **Range**: 15 studs (client UI) / 20 studs (server validation)
- **Repair Rate**: 20 HP per second
- **Cost**: 1 gold per 5 HP (0.2 gold per HP)
- **Visual Feedback**: Green particles on structure being repaired

**UI Features** (BillboardGui indicators):
- Shows indicators above ALL damaged structures in range (not just nearest)
- Each indicator shows:
  - **Prompt**: "[F] Repair" (yellow) or "REPAIRING..." (green)
  - **Health bar**: Color-coded (green >60%, yellow >30%, red ≤30%)
  - **Health text**: "50 / 100 HP (50%)"
- **Highlight**: Green outline on structure being actively repaired
- Nearest damaged structure gets repaired when holding F

Only works on structures you own that are damaged.

### Session Summary (Jan 2026 - Latest)

**Fixes Applied This Session:**
1. **Keybind Conflict** - Player Upgrades changed from U to P (Workshop stays on U)
2. **Gold Rush Power-Up** - Fixed to use RoundManager.playerStats instead of non-existent Gold value
3. **Frost Turret Physics** - Removed welded ice ball that was launching Kodos, now uses BillboardGui "SLOWED" indicator + particles
4. **Ghost Power-Up** - Replaced Shield (which had physics issues) with Ghost:
   - Player becomes 60% transparent
   - "GHOST" indicator above head
   - Kodos completely ignore player (won't chase, won't kill)
   - No physics parts that cause movement issues
5. **Barricades** - Increased size from 2x5x2 to 3x6x3 for better maze gameplay
6. **Repair System** - New feature: Hold F to repair damaged structures
   - 20 HP per second repair rate
   - Costs 1 gold per 5 HP
   - Green particle feedback
   - BillboardGui indicators on ALL damaged structures in range
   - Shows "[F] Repair" prompt with health bar and percentage
   - "REPAIRING..." state with green Highlight on active structure
   - Health bar color-coded: green >60%, yellow >30%, red ≤30%

**Custom Model Issues to Watch:**
- When swapping custom models (turrets, etc.), ensure:
  - Model has `PrimaryPart` set to base part
  - `Cost` IntValue exists as child
  - PrimaryPart should be at BOTTOM of model (or use invisible anchor part at base)
  - All parts anchored

**Current State:**
- Game is playable with wave-based survival
- High scores save to DataStore with global leaderboard
- Power-ups spawn and work correctly
- Frost turret slows without physics glitches
- Ghost power-up provides temporary Kodo immunity
- Barricades create tight 2-stud gaps for kiting

### Next Steps (Suggested)
1. **Map Variations** - Different maps for SOLO vs LARGE games
2. **Visual damage indicators** - Show resist/weak floating text
3. **Custom turret models** - Create turret models with Barrel parts for rotation
4. **Sound effects** - Shooting, building, kodo growls, death sounds
5. **Test barricade gaps** - Verify 2-stud gaps work well for player kiting

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
| `GetHighScore` | Client→Server | RemoteFunction - get personal/global high scores |
| `HighScoreUpdated` | Server→Client | Notify client of high score update |
| `ShowFarmIncome` | Server→Client | Show floating gold text above farms |

## Keybinds
| Key | Action |
|-----|--------|
| **B** | Open/close Build menu |
| **E** | Interact (mining, solo start) |
| **F** | Hold to repair nearby damaged structures (costs gold) |
| **M** | Toggle minimap/full map |
| **P** | Open/close Player upgrades |
| **R** | Rotate building (in placement mode) |
| **U** | Open Workshop upgrades (when near Workshop) |
| **X** | Toggle Sell mode |
| **Shift** | Sprint |
| **Escape** | Close menus / cancel placement |

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

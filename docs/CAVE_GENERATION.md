# Cave Generation System

## Overview

The procedural cave generation system creates varied, playable cave environments using cellular automata combined with FastNoiseLite for biome variation. This is the foundation for Mycelium Empire's destructible terrain and resource gathering mechanics.

## Implementation Status

✅ **Completed (Phase 1)**
- Cellular automata-based cave generation
- FastNoiseLite integration for biome variation
- Nutrient vein placement with clustering
- Connectivity validation (ensures single connected cave region)
- TileMap visualization system
- Interactive camera controls for testing

## File Structure

```
mycelium-empire/
├── scripts/
│   ├── generation/
│   │   ├── cave_generator.gd       # Core procedural generation logic
│   │   └── cave_world.gd           # Cave visualization and interaction
│   └── camera_controller.gd        # Test camera controls
├── scenes/
│   ├── world/
│   │   └── cave_world.tscn         # Cave world scene
│   └── main.tscn                   # Main test scene
├── resources/
│   └── tilesets/
│       └── cave_tileset.tres       # Tileset resource
└── assets/
    └── sprites/
        └── cave_tileset.svg        # Placeholder tile graphics
```

## Core Components

### CaveGenerator (`scripts/generation/cave_generator.gd`)

**Purpose**: Generates procedural cave layouts using cellular automata

**Key Features**:
- **Cellular Automata**: Classic cave generation algorithm with configurable rules
- **Noise Overlay**: FastNoiseLite adds organic variation to cave shapes
- **Connectivity**: Flood-fill algorithm ensures single connected playable area
- **Nutrient Veins**: Strategic resource placement in wall tiles with clustering

**Configurable Parameters**:
```gdscript
# Cave dimensions
cave_width: 100
cave_height: 60

# Cellular automata rules
initial_wall_probability: 0.45
smoothing_iterations: 5
wall_survival_threshold: 4
wall_birth_threshold: 5

# Biome variation
use_noise_overlay: true
noise_influence: 0.3
noise_scale: 0.05

# Resource placement
nutrient_vein_density: 0.15
nutrient_vein_cluster_size: 3

# Quality control
ensure_connectivity: true
min_open_area_size: 20
```

**Tile Types**:
- `EMPTY`: Open floor space (no tile rendered)
- `WALL`: Solid rock walls (dark grey)
- `NUTRIENT`: Harvestable nutrient veins (glowing cyan)

### CaveWorld (`scripts/generation/cave_world.gd`)

**Purpose**: Manages cave visualization and interaction

**Key Features**:
- Auto-generates cave on ready
- Renders cave data to TileMapLayer
- Provides tile querying methods
- Supports destructible terrain

**API**:
```gdscript
generate_new_cave()                           # Generate and render new cave
get_tile_at_position(world_pos: Vector2)      # Query tile type at position
destroy_tile_at_position(world_pos: Vector2)  # Remove tile (harvesting)
get_cave_bounds()                             # Get cave rect in world coords
```

## Testing Controls

**Camera Controls** (`scripts/camera_controller.gd`):
- **WASD / Arrow Keys**: Pan camera
- **Mouse Wheel**: Zoom in/out
- **R Key**: Regenerate cave

## How It Works

### 1. Initialization
```
1. Create random initial grid (45% walls, 55% empty)
2. Force all border tiles to be walls
3. Apply FastNoiseLite overlay for organic variation
```

### 2. Cellular Automata Smoothing
```
For each iteration (default: 5 iterations):
  For each tile:
    Count wall neighbors in 3x3 grid
    Apply survival/birth rules:
      - Walls survive with >= 4 wall neighbors
      - Empty tiles become walls with >= 5 wall neighbors
```

### 3. Connectivity Validation
```
1. Flood-fill to find all connected open regions
2. Keep largest region
3. Fill all smaller regions with walls
   → Ensures no isolated unreachable areas
```

### 4. Nutrient Vein Placement
```
1. Find all wall tiles adjacent to open space
2. Place nutrient vein clusters (15% of eligible walls)
3. Each cluster: 1-3 connected nutrient tiles
   → Creates strategic resource deposits
```

### 5. Rendering
```
1. Clear TileMapLayer
2. For each tile in cave_data:
   - EMPTY → No tile (transparent)
   - WALL → Place wall tile at (0,0) atlas coords
   - NUTRIENT → Place nutrient tile at (1,0) atlas coords
```

## Performance

**Typical Generation Times** (100x60 cave, M2 chip):
- Generation: ~350-400ms
- Rendering: Instant (TileMapLayer is highly optimized)

**Optimization Opportunities** (Future):
- Move generation to worker thread
- Use custom tile data layers for metadata
- Implement chunk-based generation for larger caves

## Future Enhancements

### Phase 2 Planned Features
- [ ] Multiple biomes (3+ distinct visual/mechanical themes)
- [ ] Strategic chokepoint detection
- [ ] Flood risk areas (environmental hazards)
- [ ] Directional flow for mycelium spread pathfinding
- [ ] Save/load cave layouts for reproducibility

### Phase 3 Potential Features
- [ ] Multi-layer caves (vertical exploration)
- [ ] Dynamic cave-ins (triggered by events)
- [ ] Regenerating nutrient veins (balancing mechanic)
- [ ] Procedural cave decorations (visual polish)

## Design Philosophy

**Destructive Harvesting**: Unlike traditional base builders, gathering resources permanently destroys terrain:
- Creates strategic tension between resource gain and map control
- Opens new paths but creates defensive vulnerabilities
- Forces player to adapt to changing cave layouts

**30-60 Minute Runs**: Cave size and resource density calibrated for roguelite session length:
- Finite resources create natural time pressure
- Exploration vs exploitation tradeoffs
- Replayability through procedural variety

## Integration Points

This system integrates with:
- **Mycelium Spread**: Uses EMPTY tiles as valid spread locations
- **Minion AI**: Pathfinding around WALL tiles, harvesting NUTRIENT tiles
- **Event System**: Cave modifications trigger tactical changes
- **Lighting**: Mycelium provides dynamic light in dark caves

## Testing

**Run Project**:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --editor
# Or press F5 in editor
```

**Expected Behavior**:
1. Cave generates on startup (console: "Generating new cave...")
2. Dark grey walls, cyan nutrient veins visible
3. Camera at (400, 300) with 1.5x zoom
4. Press R to regenerate different cave layouts

**Common Issues**:
- Tileset not loading → Ensure Godot imported cave_tileset.svg
- No tiles visible → Check TileMapLayer has tileset assigned
- Parser errors → Verify all scripts have `class_name` declarations

## Version History

**v0.1.0** - Initial Implementation (2025-11-15)
- Cellular automata cave generation
- FastNoiseLite biome variation
- Nutrient vein clustering
- Connectivity validation
- Basic visualization

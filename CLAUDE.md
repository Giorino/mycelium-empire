# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mycelium Empire is a solo-developed roguelite fungal base builder created with Godot 4.5. Players control a sentient fungal colony spreading through procedurally generated cave systems. The game focuses on 30-60 minute runs with emergent gameplay driven by:

- **Dynamic Terrain Excavation**: Minions harvest finite "Nutrient Veins" embedded in walls, permanently destroying tiles and carving new strategic paths
- **Organic Mycelium Spread**: Growth mechanic visualized with `GPUParticles2D` that creates pathways for minions
- **Needs-driven Minion AI**: Finite State Machine (FSM) creating emergent behaviors based on colony needs
- **Escalating Event System**: Dynamic "Threat Meter" triggering varied events (threats, opportunities, wrinkles)
- **Mutation System**: 50+ combinable mutations defining playstyle and strategy

## Development Environment

### Running the Project

The Godot editor is located at `/Applications/Godot.app` (configured in `.vscode/settings.json`).

To run the project:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --editor
```

To run headless for testing:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --headless
```

### Project Structure

This is an early-stage Godot 4.5 project currently in Phase 1 (Prototype, weeks 1-8) of a 9-month development roadmap. The codebase will grow to include:

- **Phase 1 (Current)**: Procedural cave generation (cellular automata + `FastNoiseLite`), mycelium spread mechanics, basic minion AI
- **Phase 2**: Mutation system, dynamic events, meta-progression, data persistence
- **Phase 3**: Multiple biomes, 50+ mutations, audio implementation
- **Phase 4**: UI polish, Steamworks integration, demo release

## Key Technical Concepts

### Procedural Cave Generation
Caves are generated using cellular automata combined with `FastNoiseLite` to create varied biomes with:
- Strategic chokepoints
- Environmental hazards (flood risks)
- Non-uniform walls containing harvestable nutrient veins

### Resource Gathering as Excavation
Unlike traditional base builders, harvesting is destructive terrain modification:
- Gathering nutrients permanently destroys wall tiles
- Creates new paths and defensive vulnerabilities
- Strategic tradeoff between resource gain and map control

### Minion Autonomy
Minions operate on needs-based FSM rather than direct player control:
- Player influences through mycelium network spread
- Starvation and other needs affect behavior (potential rebellion)
- Emergent interactions between minions

### Event-Driven Progression
Rather than predictable waves, a hidden "Threat Meter" triggers varied events:
- **Threats**: Hostile creatures, rival colonies, parasitic infections, disasters
- **Opportunities**: Resource blooms, powerful artifacts requiring risky decisions
- **Wrinkles**: Cave-ins and environmental changes forcing adaptation

## Art and Game Feel Requirements

### Visual Feedback ("Juice")
All core interactions should have satisfying feedback:
- **Mycelium growth**: Pulsing glow, particles, flowing shaders, soft sounds
- **Terrain destruction**: Crumbling animation, rock particles, dust clouds, screen shake, crunchy audio
- **Minion movement**: Squash-and-stretch animation, wobble effects, "plip-plop" sounds

### Bioluminescent Noir Aesthetic
- **High contrast**: Dark desaturated caves (blues, purples, greys) vs vibrant neon living elements
- **Dynamic 2D lighting**: Glowing mycelium as primary light source with shadows
- **Low-resolution chunky pixels**: Readable silhouettes, clean animation
- Pixel art style throughout

## Development Constraints

This is an **aggressive 9-month solo dev project** heavily accelerated by AI-assisted coding:
- Strict adherence to phase scope is critical
- Focus on core addictive loop over feature creep
- 30-60 minute run length is target for all balancing decisions
- Godot 4.3+ features should be leveraged where appropriate

# ANTIGRAVITY.md

This file serves as the primary context document for Antigravity (Google Deepmind's agentic AI coding assistant) when working on the **Mycelium Empire** project.

## Project Identity
**Mycelium Empire** is a solo-developed roguelite fungal base builder made in Godot 4.5.
- **Theme**: Sentient fungal colony spreading through procedural caves.
- **Core Loop**: 30-60 minute runs. Spread mycelium -> Command minions -> Mutate -> Survive events.

## Art Direction: "Bioluminescent Noir"
The visual style is critical.
- **Contrast**: Extreme. Dark, desaturated backgrounds (caves) vs. vibrant, neon foregrounds (mycelium, minions).
- **Lighting**: Mycelium is the primary light source. Dynamic 2D shadows.
- **Style**: Pixel art. Low-res, chunky, readable silhouettes.
- **Juice**: High emphasis on visual feedback (particles, screen shake, squash-and-stretch).

## Technical Context
- **Engine**: Godot 4.5 (using 4.3+ features).
- **Language**: GDScript.
- **Key Systems**:
    - Procedural Generation: Cellular Automata + `FastNoiseLite`.
    - AI: Finite State Machine (FSM) for minions.
    - Visuals: `GPUParticles2D` for mycelium spread.

## Agent Guidelines
1.  **Art First**: Always consider the "Bioluminescent Noir" aesthetic. If generating assets or UI, ensure high contrast and neon accents.
2.  **Godot Best Practices**: Use strict typing in GDScript (`@export var`, `func _ready() -> void:`).
3.  **Documentation**: Keep `CLAUDE.md` and `README.md` in mind, but this file is your primary anchor.

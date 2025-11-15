# Mycelium Empire

A solo-developed roguelite fungal base builder, created with Godot 4 and extensive AI-assisted tooling.

## Game Concept

Mycelium Empire is a bite-sized, emergent-story-driven game inspired by titles like RimWorld. Players take on the role of a sentient fungal colony, spreading through procedural cave systems. The core gameplay loop is designed for addictive 30-60 minute runs and focuses on:

-   **Spreading:** Organically grow your mycelium network through dark, neon-lit caves.
-   **Commanding:** Direct a swarm of 20-50 spore minions to gather resources and defend the colony.
-   **Mutating:** Unlock and combine powerful mutations to adapt and overcome challenges.

The game aims for a pixel art aesthetic, emphasizing the satisfying visual and audio feedback of your empire's growth.

## Core Mechanics

-   **Procedural Cave Generation:** Each run takes place in a unique cave system generated with cellular automata and `FastNoiseLite`. This creates varied biomes with distinct resources, strategic chokepoints, and environmental hazards like flood risks.

-   **Dynamic Terrain and Resource Gathering:** Walls are not uniform. Minions harvest finite "Nutrient Veins" embedded within the rock, and doing so permanently destroys the wall tile, carving new paths through the level. This makes resource gathering a strategic act of excavation, forcing players to balance the reward of new resources against the risk of creating new defensive vulnerabilities.

-   **Organic Mycelium Spread:** Players plant a root, and the mycelium network expands towards nutrient-rich tiles. This growth mechanic, powered by `GPUParticles2D`, not only visualizes your expanding territory but also creates the pathways your minions use.

-   **Emergent Minion AI:** Your spore minions operate on a needs-driven Finite State Machine (FSM). They harvest, defend, and interact, leading to emergent behaviors. A starving colony might see its minions become less efficient, or even rebel.

-   **Mutation System:** Discover and unlock over 50 mutations throughout your runs. These can be combined to create powerful synergies, defining your colony's strengths and playstyle.

-   **Escalating Event System:** To create an addictive, high-tension experience, the game uses a dynamic event system driven by a hidden "Threat Meter" that rises over time. At regular intervals, events are triggered that are not just enemy attacks, but a mix of:
    -   **Threats:** Hostile creatures, rival colonies, parasitic infections, or environmental disasters.
    -   **Opportunities:** Sudden resource blooms or powerful artifacts that reward risky, decisive action.
    -   **Wrinkles:** Minor environmental changes like cave-ins that force strategic adaptation.

## Art Direction and Game Feel

### Game Feel: Making Interactions Satisfying ("Juice")

To ensure the game is addictive, every core action will be enhanced with satisfying feedback:

-   **Mycelium Growth:** Veins will pulse with a soft, glowing light, emit particles, and have a flowing, organic feel via shaders. Growth will be accompanied by soft, "squishy" sounds.
-   **Terrain Destruction:** Harvesting a wall won't just make it disappear. It will crumble, spawning small rock particles and a dust cloud, punctuated by a crunchy sound effect and subtle screen shake.
-   **Minion Movement:** Minions will use "squash and stretch" animation to feel like living blobs, wobbling when idle and stretching when moving, accompanied by small "plip-plop" sounds.

### Art Style: Bioluminescent Noir

The game will use a striking, high-contrast pixel art style that is both atmospheric and practical for a solo developer.

-   **Core Principle:** Extreme contrast. The environment (caves, rocks) will use a dark, desaturated palette (deep blues, purples, greys), while all living elements (mycelium, minions, nutrients) will be vibrant, glowing neon colors.
-   **Lighting as a Mechanic:** The glowing mycelium will be the primary light source, casting dynamic 2D shadows and creating a sense of pushing back the darkness as you expand.
-   **Aesthetic:** The overall feel will be a low-resolution, "chunky" pixel look that is highly readable and focuses on clean silhouettes and fluid animation.

## Development Roadmap

This project follows an aggressive 9-month development schedule, heavily accelerated by AI-assisted coding. Sticking to the defined scope for each phase will be critical for success. The development is broken down into four key phases:

| Phase            | Weeks | Milestones                                                                                      | Key Tools                                    |
| ---------------- | ----- | ----------------------------------------------------------------------------------------------- | -------------------------------------------- |
| **1: Prototype** | 1-8   | Implement core mechanics: procedural cave generation, mycelium spread, and basic minion AI.       | Cursor for noise/automata prototyping.       |
| **2: Core Loop** | 9-20  | Develop roguelite meta-progression: mutations system, dynamic events, and player data persistence. | Claude for FSM and game logic scripting.     |
| **3: Content**   | 21-28 | Expand the game world: design and implement 3 distinct biomes, create 50+ mutations, and add audio. | Gemini for balancing and content generation. |
| **4: Polish & Launch** | 29-36 | Build a polished UI, create a public demo, integrate with Steamworks, and add final visual polish. | All AI tools for final polish and bug fixing. |

## Technology Stack

-   **Game Engine:** Godot 4.3+
-   **AI Development Tools:**
    -   Cursor IDE
    -   Claude API
    -   Gemini CLI
-   **Audio:** Audacity for sound design.

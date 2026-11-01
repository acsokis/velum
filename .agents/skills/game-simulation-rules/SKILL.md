---
name: game-simulation-rules
description: Apply the user's reusable simulation, procedural-world, creature spawning and rendering-performance rules while developing their games. Select only rules relevant to the current game's mechanics and engine; consult the VELUM reference only for VELUM or an explicitly requested similar setting.
---

# Game simulation rules

Apply these preferences to the user's game projects when the corresponding system is in scope. Preserve the game's existing identity, perspective, engine and explicit requirements. This skill does not authorize adding every system to every game, installing engines, publishing releases, or changing unrelated projects.

## Procedural worlds and persistent state

- Use explicit seeds and independently seeded subsystems so adding decoration does not scramble terrain or encounters. Persist seed, generator version, section revisions, simulation state and relevant random-generator state.
- Keep intended terrain elevation and traversability. Validate slopes, clearance, boundaries, connections and support surfaces before placing props or creatures. Deliberate integrated growth needs proper contact and transitions; accidental wall intersections are bugs.
- Where changing labyrinth sections are requested, validate a route from entry through objectives to exit after start, transition and load. Identify the bounded resident area honestly; do not label it a completed seamless planet.
- Resource routes should form a coherent network with actual sources, consumers and endpoints. Gathering must use the game's intended interaction rather than merely removing decoration.

## Spawning and creature movement

- Distinguish biome-aware **Natural Spawns** from **Autonomous Spawners** for nests and scripted encounters. Select a valid player tether, use local population limits and define spawn/despawn distances without visible popping where practical.
- Every autonomous encounter explicitly declares whether its creatures consume natural population limits. Exempt encounters still have their own bounded limits. Centralize accounting across spawn, death, despawn, save and load; prevent duplicate reservations.
- Validate terrain placement and reachable escape space, not just an unoccupied point. Reject isolated pockets, unsuitable dead ends and locations the creature cannot leave. Navigation should also prevent entering such traps.
- Use locomotion appropriate to the creature. Rolling bodies turn away from impassable ledges and walls; hover creatures use clearance-aware altitude changes and bounded maneuvers instead of getting stuck against terrain. Keep behavior deterministic enough to reproduce failures.
- Where ecology is part of the game, give organisms actual energy/material/repair/cooling roles. Connect consumption, transport, regeneration and decomposition to game state rather than unrelated visual timers.

## Weather, atmosphere and fluid effects

- Drive randomized weather and day/night transitions from explicit state. Rain originates under actual cloud coverage; impacts follow real surfaces. If rain feeds a resource network, route packets through connected edges to real consumers.
- Tie steam and condensation to heat sources and ambient conditions. Player/NPC wakes should affect local atmosphere when supported. Bound simulation domains, velocities, lifetimes and actor influence.
- Prefer engine-supported volumetrics or a measured approximation. Do not call animated noise, analytic vortices, rigid-body cubes or billboard mist physical voxel fluids, CFD or full voxel destruction.
- Keep functional visual parameters consistent with simulation state: coolant flow, charge, heat and disabled pumps should change the corresponding effects.

## Performance and presentation

- Profile representative gameplay before optimizing: CPU/GPU frame times, high-percentile spikes, draw calls, triangles, upload cost and simulation update cost. Distinguish startup shader compilation and GI baking from steady-state rendering.
- Batch repeated geometry with shared materials and instancing/MultiMesh equivalents. Preserve useful culling bounds; one world-sized batch can waste GPU work. Disable unnecessary shadows and per-object material copies on particles, mist and tiny details.
- Share airflow/heat fields across effects; bound actor lists and spatial queries. Use distance/visibility updates and separate simulation frequency from render interpolation. Time-slice FFT and other expensive CPU work; avoid repeated allocations and redundant texture uploads.
- Keep expensive GI baking and generation off the interactive main thread where supported. Report progress and preserve a playable fallback. Verify background work does not merely move the bottleneck to GPU contention.
- Offer resolution scale, sensible quality presets, window/fullscreen and supported upscalers. Enable RTX, volumetrics, voxel GI, frame generation or similar features only when the actual backend supports them; label fallbacks and unverified features.
- Target the requested 60–144 FPS through measured budgets; do not promise a minimum from a short stationary test. Browser and native builds may require different techniques and fidelity.
- Start music OFF. Use original or properly licensed audio, retain attribution and provide separate music, atmosphere and notification controls.

## Validation and delivery

Exercise actual gameplay, traversal, seed reproducibility, save/load, population accounting, disconnects and long-running resource bounds. Test route validity and creature escape behavior after section regeneration.

For optional companions, preserve single-screen play. Validate simultaneous clients, explicit pairing/approval, read/control permissions, revocation, reconnection without duplicate messages and synchronized unread state. Keep external services distinct, secrets server-side and unavailable integrations visibly mocked.

Report separately: implemented, build-verified, runtime-verified, browser-emulated, real-hardware-tested, mocked and unavailable. Desktop emulation does not establish Android/iOS hardware compatibility. Provide launchable artifacts and controls when requested.

For VELUM-specific art direction and interactions, read [references/velum.md](references/velum.md). Do not transfer that setting to unrelated games unless requested.

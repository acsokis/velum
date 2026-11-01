# VELUM — first playable 0.1

## Public download and launch

Source repository: [acsokis/velum](https://github.com/acsokis/velum). Download **VELUM-web.zip** from [Releases](https://github.com/acsokis/velum/releases), extract it, install Node.js 22 or newer if needed, and double-click **RUN_WEB.cmd**. It starts/reuses the local web server and opens the playable game in your browser. The web release includes the export; it does not require Godot or NVIDIA engine installation. Keep its `build-web` directory beside the launcher.

The source checkout excludes `.tools`, generated builds, local saves, credentials and certificates. Its native NVIDIA runtime must be built/configured separately with the included development scripts. The web game uses stock Godot WebGL; native NVIDIA features are not available in browsers. Windows launchers keep startup failures visible. If LINK port 8787 is occupied, native gameplay starts offline and leaves the existing process running. Web play uses port 8789.

Original techno-organic exploration/survival prototype. The default game now contains **81 connected procedural labyrinth sections**, with one **198 × 198 metre chamber** resident at a time. This is checkpoint-based section streaming, not a seamless planet. All meshes are original procedural placeholder art. No local AI model or local AI service is used.

## Reconfiguring labyrinth milestone

**Terrain/engine correction:** the default maze retains all 57 layered PCB slabs and seven walkable ramps. Cooling walls are split into terrain-following low panels, approximately 0.55m above the higher sampled ground, clearable with the ordinary jump. Ramp corridors and steep slab edges stay open. Component mesh bounds are reserved before geometry batching and across maze revisions, so panels do not slice through existing plants or props. Coolant channels and fins are resized to the low walls. `RUN_VELUM.cmd` and `RUN_BUILD.cmd` now require the validated NVIDIA/Vulkan build; the initial NVIDIA profile uses VoxelGI 512 and DLSS Quality. `RUN_DX12.cmd` remains the explicit stock fallback; `RUN_VELUM.ps1 -Source` runs editable stock source. Maze GI rebakes on section changes. Previous flat-maze FPS measurements do not validate this changed terrain/GI profile. The game stays fully 3D; no 2.5D conversion was made.

**Seed, corrosion and detail:** LINK contains a world-seed selector. Generate starts that seed with reset unsaved progress; saves are kept separately as `save-SEED.json`, with fallback support for the older `save.json`. Native launch also accepts `--seed=123456`; web accepts `?seed=123456`. The seed controls the maze network, resource/component placements, corrosion/patina patterns, micro-growths, sky noise and FFT spectrum. Startup/traversal/load revisions still deliberately change the resident maze interior, and weather evolves over time. Twenty-four instanced voxel-shaped accretion clusters are culled beyond 45m native / 28m web. Salvage emits physical chips with a hard 24-native / 12-web limit and six-second expiry. These are ordinary rigid bodies shaped as small voxels, not full-world voxel destruction.

The LINK frame-budget selector offers 60/90/120/144 FPS (default 144 native, 60 web); web adaptive render scale uses that target while focused. A measured stock-DX12 run on this RTX 4080 at native 1280 × 800 averaged **116.97 FPS**, median **8.60 ms**, p95 **9.655 ms**, across 720 sampled frames with a rotating stationary camera and active ecology/effects. This is a bounded scene measurement, not a guarantee across all sections, devices, resolutions or full traversal.

**Spectral atmosphere and bokeh:** LINK settings now include Triangle bokeh DOF, FFT sky/gel, and aperture strength. A seeded 32 × 32 frequency spectrum evolves over time and is reconstructed with a two-dimensional radix-2 inverse FFT (10 Hz native, 6 Hz web). The resulting periodic wave texture drives a displaced gel basin below/outside the board and an upper sky layer behind the existing clouds. The gel has a rotating funnel and restrained procedural electrical veins; Signal flashes disables its discharge pulses. Perimeter containment windows expose the exterior. This is a spectral wave approximation with a procedural vortex, not an electrical-field or full fluid-dynamics solver. DOF uses a triangular sampling aperture on opaque scenery; nearby terminal geometry, glass/fluid and UI remain sharp. Native uses 15 samples, web uses 8; both effects can be disabled.

Maze bulkheads are layered PCB cooling panels with metal radiator fins and closed, translucent coolant loops on both faces. The same flowing working fluid appears inside organism reservoirs and conduits. Its phase advances with simulation time; charge, temperature and remaining coolant affect its appearance. Unplugging an organism's pump reduces circulation to a slow residual flow. This is shader-driven circulation visualization, not computational fluid dynamics. Wall channels are rendered in three instanced batches (fluid, glass, fins).

Hatch with E, follow the LINK local map and the HUD gate direction, and cross the open perimeter gate to enter the next section. Authenticate the central interfaces in **PSU (2:2), RAM (6:2), LIQUID COOLER (6:6), then SoC (4:4)** with E. Reach the far-side **exit interface (8:8)** and use E to escape. SoC requires the other three authentications. Survival, salvage and membrane growth remain active. F refills at the resident checkpoint.

The seeded 9 × 9 macro network stays connected. Each resident chamber contains a connected 11 × 11 procedural maze. Its revision changes on startup, section traversal and load. Load preserves mission/inventory and resumes at the section's central checkpoint; it intentionally does not restore an arbitrary position inside a changed wall. Walls have real collision, one instanced render batch, and spatially indexed clearance checks. Resource sockets stay away from all possible wall lines. NPC navigation is rebuilt against the resident walls. Current sections reuse the same component ecology, weather and resource population; distinct megacomplex architecture, background streaming and persistent independent ecology per section remain unfinished. Section transitions currently rebuild synchronously and may pause briefly. Use `--survey` to run the earlier layered-board survey sector.

Native warm vapor uses six local Godot froxel FogVolumes with a custom density shader. Moving player/NPC velocities inject bounded, rising, dissipating wakes that displace mist and carve/swirl fog density. This is an analytical airflow approximation, **not** a voxel fluid/pressure simulation. Web uses displaced mist billboards and heat distortion, without native volumetric fog. The NVIDIA default rebuilds VoxelGI for each new maze section, using temporary SDFGI while preparing it; static survey caches are never reused for maze walls.

The current art direction is an **abstract electronic ecosystem**: the landscape consists of 57 actual overlapping PCB slabs with visible laminate edges, at heights up to 6.75m, connected by seven physical ramps. Copper traces, vias and worn silkscreen follow the individual boards. Three-legged transistor trees and capacitor growths form the canopy; resistors, diodes, fuses, inductors, LEDs, crystals, connectors, relays, ceramic components, trim pots and ICs form the understory. Filament webs bridge component leads and GPU dust drifts through machine mist. The procedural sky is a surreal cable-management canopy of sweeping bundles, bindings, connector nodes and moving light pulses. It is background atmosphere rather than a literal server ceiling. Board and ramp winding, physical traversal and saved resource coordinates are audited.

## Start on this Windows PC

Browser play is available separately: run **[RUN_WEB.cmd](./RUN_WEB.cmd)** and open **http://127.0.0.1:8789/**. This serves the actual Godot WebAssembly/WebGL 2 game, not the LINK companion. Click the canvas, press E to hatch, then WASD; drag with the left mouse button if pointer lock is unavailable. K/L or the terminal's Save/Load buttons replace browser-reserved shortcuts. Saves use this browser/origin's local storage and may be removed when site data is cleared. Rebuild with **[BUILD_WEB.ps1](./BUILD_WEB.ps1)**. Official SHA512-verified export templates and portable editor settings are on D:.

The web build shares terrain, organisms, survival, crafting and the physical terminal. Its Compatibility renderer uses procedural sky, distance fog, shadows and MSAA. It does **not** reproduce native SDFGI/VoxelGI, volumetric fog, SSIL/SSR, DLSS or frame generation. Desktop Chromium gameplay was tested; no real Android/iOS test is claimed. The web game's remote LINK host connection is currently unavailable; its physical terminal, map, scanner and probe remain local and playable. Native companion pairing/chat remains a separate experience on port 8787. No native host key is included in the web bundle.

Legless **conductor masses** move with a distance-driven contact wave; **coolant skimmers** use ground-following thrust, variable hover height and a climbing roll maneuver. The connected, deforming body has an optical eye, ceramic filter intake and fluid-bladder belly, inspired by the proportions of Keegan Sullivan's [Blob Creature reference](https://www.artstation.com/artwork/nzZ6e). Its meshes/shaders are original; no reference image is bundled as a game asset. A clearance graph with 18,060 connected nodes excludes isolated pockets, narrow board edges and leaf corridors from spawning and roller routes. Agents yield to the player and cannot block player traversal. Transported charge only regenerates a destination after the organism arrives.

Weather randomly selects quiet bus, matrix condensation, ion drizzle, packet storms or static mist, with varying durations and eased transitions. An 18-minute day includes sunrise, sunset and night lighting/color treatment. Rain is born at the shared 35m cloud layer only under sufficient cloud coverage, and ray-tests board, major component and organism surfaces. Warm machine sources produce humidity/temperature-driven condensation and heat shimmer; these are bounded visual approximations, not a fluid simulation. Native fog volumes and lighter browser mist share the same sources. Time of day and weather generator state are saved. Weather, flashes and atmosphere FX have separate switches in the scrollable LINK menu.

All visible functional traces form one procedural copper graph: 1,088 junctions, 1,120 edges and 300 component sockets. Every leaf ends at a plant, prop, collectible socket or the egg condenser. Surface packets enter the nearest circuit intake and follow that graph to a plant, increasing its energy and accelerating a nearby deposit. Edge conductors join stacked boards. Collecting a component leaves its connected socket behind. Sky cables occasionally pulse along one selected strand, independently of ground signals.

Natural spawns use biome-weighted species, player tethers and a local natural budget of 9 (global natural cap 18; total safety cap 28). Autonomous encounters have explicit policies: reclaimer den, at most 2 tougher creatures outside the natural budget; charged warden, at most 1 tougher creature consuming the natural budget. Dens themselves do not consume that budget. All placements use the clearance network. Population origins, health, disabled valves and budgets survive saves. Tether selection supports multiple authoritative player records; actual networked two-player movement remains unimplemented.

Salvage is deliberate: select **T**, then **hold E**. UNPLUG recovers connectors or interrupts an organism's coolant valve; DESOLDER takes 2s and 6 energy for ceramic components; RIP is destructive and costs player integrity, with slower deposit recovery. Wardens have 250 shell integrity and a short-range discharge; unplugging their valve interrupts them for 14s. This is an original, small component-hunting prototype, not a Horizon port or a complete combat game.

Music is **Dark Horse — Centurion_of_war**, a credited [CC0 chiptune recording](./assets/audio/CREDITS.md), replacing the generated beep loop. **Music starts OFF every launch**, even if enabled previously. Volume is remembered; enable music intentionally in LINK. Notification sound stays separate. No literal Atari-chip emulation is claimed.

**Current RTX status:** the current package passed native Vulkan DLSS with both SDFGI and VoxelGI. The automatic launcher can select that hash-validated package; stock DX12 remains available explicitly. Frame Generation did not confirm extra frames in the current fullscreen test and is disabled. Old successful FG runs are historical evidence, not validation of this build.

Double-click **[RUN_BUILD.cmd](./RUN_BUILD.cmd)** to start the built game and companion server together. It chooses the tested NVIDIA/Vulkan package when its validation record matches the current files, otherwise stock Godot / DX12. **[RUN_RTX.cmd](./RUN_RTX.cmd)** selects native DLSS explicitly, with unverified FG disabled; **[RUN_DX12.cmd](./RUN_DX12.cmd)** selects the standard DX12 build. **[RUN_VELUM.cmd](./RUN_VELUM.cmd)** runs the editable stock-Godot source project. Close an already-running VELUM/LINK instance before starting another; the launcher intentionally refuses to take over an occupied server port.

The launchable files are **build/VELUM.exe** and **build/VELUM.pck**. This is a portable developer build using the full, verified Godot binary plus an explicitly allowlisted resource pack. It is larger than a stripped release export. Keep the two files together. The full companion experience also needs this project and the existing Node.js 24 runtime.

The separate **build-rtx** directory contains the locally compiled NVIDIA engine and signed NVIDIA runtime libraries. Keep that directory intact. Its release template loads adjacent `VELUM.pck` automatically. Its full-effect DLSS/FG profile uses Vulkan on this PC because the experimental fork's DX12 route encountered a driver-module crash; the stock DX12 route remains available. See **[GRAPHICS.md](./GRAPHICS.md)** for the verified feature matrix and graphics controls.

Godot 4.7.2 was downloaded from the official godotengine/godot-builds release and its ZIP verified against the release SHA512 list. New engine files live only in this project's `.tools` folder on D:. No CUDA Toolkit is required or installed. NVIDIA RTX 4080, Godot Forward+, and **Direct3D 12** were verified in the actual engine log. Visual Studio C++ tooling is unnecessary for this GDScript milestone. VS Code tasks are supplied; the optional Godot Tools extension is configured but was not installed or claimed connected.

## Play

| Input | Action |
|---|---|
| E / hold E | Hatch; then hold to recover the nearby component within 3.5m |
| T | Cycle UNPLUG / DESOLDER / RIP |
| WASD / mouse | Move / look |
| Shift / Space | Sprint / jump |
| C | Grow thermal membrane: 2 ceramic + 2 conductive fiber |
| F | Refill energy and working fluid near the egg condenser |
| Tab / Escape | Open LINK controls and release cursor |
| 1–6 | Status, map, scanner, probe, messages, pairing |
| M | Handheld → left/right wrist → left/right forearm → dock → inspection |
| O | Portrait / landscape, with upright reflowing display |
| Arrow keys | Constrained tilt and pivot while mouse is captured |
| Q / R | Move the probe around the player |
| F5 / F9 | Save / load |
| F10 | Graphics/display menu: GI method, quality, resolution, upscaling and FG |
| Alt+Enter | Fullscreen / windowed |

Move toward the four nearby glowing resource nodes. Gather both materials, grow a membrane, and explore the capacitor flats and transistor grove. These replace the initial ceramic steppe/antenna-grove artwork while retaining the same seeded terrain, resources and survival boundaries. The membrane reduces working-fluid consumption and slows temperature drift. Grazers collect solar charge and accelerate regeneration of neighbouring deposits. Empty energy/fluid and extreme temperatures damage integrity; a failed shell is reconstituted at the hatch site. The current resources are retained on reconstitution.

The physical LINK is a real rendered 3D object with a SubViewport display, smoothly interpolated attachment transforms and constrained angles. Wrist/forearm sockets are a visual prototype without an animated humanoid body or a physical strap simulation. The world dock remains fixed while you move. Inspection supports tilting/pivoting; arbitrary object dragging and vehicles are not implemented.

All gameplay remains available without the companion server. Pop-ups never focus the chat input; Reply explicitly focuses it. Native chat has a destination selector and `player-id: message` syntax for DMs. Use the second browser chat actor to exercise two-client communication; this is not a second playable multiplayer world.

## Companion pairing

1. Start VELUM and open LINK with Tab, then choose Pair code. Panel 6 shows the code and pending devices.
2. On this PC open **http://127.0.0.1:8787**. Enter a device name and the six-digit code within two minutes.
3. In the game review the first pending device's name, then choose **Approve READ** or **Approve CONTROL**. New requests cannot approve themselves.
4. Select a panel independently on each device. Read permission permits state, history and personal notification preferences; it cannot control the probe, terminal or send chat.
5. Revoke all from the game or disconnect an individual browser. Sessions expire after eight hours and are invalidated when the server restarts. No credentials or sessions enter the resource pack or game save.

Control requests use a 750ms device lease; conflicting controllers receive an explicit conflict instead of silently overriding each other. Native game input remains authoritative. Command IDs are acknowledged; browser history is returned with stable message IDs, avoiding duplication on reconnect.

For another physical device use **HTTPS on port 8788**, on the same trusted LAN. [SETUP_LAN_TLS.ps1](./SETUP_LAN_TLS.ps1) creates a seven-day, self-signed development certificate and private key **only in runtime on D:** using the already-installed Git OpenSSL. The script preserves existing keys and changes no trust store or firewall rules. Restart LINK after certificate creation. It prints the local addresses and certificate fingerprint. An actual phone must trust the development certificate through supported device settings, or use a properly trusted replacement certificate. Do not bypass browser certificate warnings. Firewall permission and real-device certificate setup may require the user. Never distribute `runtime/tls-key.pem` or `runtime/host.key`.

The responsive UI targets Windows browsers, Android Chrome/Samsung Internet and iOS/iPadOS Safari. **Only desktop Chromium and a 390px mobile viewport have been exercised here. No real Android, Samsung, iPhone or iPad compatibility claim is made.** Probe snapshots are actual low-rate JPEG renders, not desktop mirroring. No orientation-sensor permissions are requested.

## Messaging, privacy and services

Native global/local/party/direct channels route by player identity. Local range is 35m; the QA actor can have another party/location. Device approval authorizes a trusted local prototype session; this is not an internet multiplayer identity service. History is bounded to 500 messages in volatile server memory; delivery status means accepted and routed by this local server, not proof a human read it. Read cursors synchronize across devices sharing a player. Each device has separate DND, preview, sound, popup and mute/block preferences. Preview and sound default off. Notifications group within five seconds; sending is rate-limited. Reports stay in volatile local memory: **there is no moderation backend**.

Twitch and Discord have visibly separate offline mock adapters, simulated events, connect/disconnect controls, and no automatic forwarding. Real linking, OAuth token storage, live chat, EventSub, Discord Social SDK presence/invites and authorized bot-channel messaging are **not implemented/live-verified** because no application registrations or credentials were supplied. The prototype never asks for a Discord user token or assumes access to personal DMs. See [INTEGRATIONS.md](./INTEGRATIONS.md).

## Development and validation

High enables cascaded SDFGI, true volumetric fog, SSAO/SSIL/SSR and four-split shadows. Ultra increases SDFGI to six cascades. A separate baked **512 VoxelGI / two-bounce** option is available. Window/display changes have a 15-second Keep/Revert safety timer; settings persist locally. DLSS/DLAA and Frame Generation appear only with actual native runtime support; FG uses Reflex and pauses in menus. Fullscreen uses monitor output resolution, while render scale/upscaling controls internal 3D resolution.

- `powershell -NoProfile -ExecutionPolicy Bypass -File BUILD.ps1` rebuilds the allowlisted PCK and portable executable.
- `node --test tests/link.test.mjs` tests permissions, routing and sessions using two or more HTTP clients.
- `.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --smoke` exercises the actual scene, physics movement, hatching, collection, survival drift, upgrade, save/load, deterministic terrain, attachment transforms, landscape and probe visibility. It uses a separate smoke save and does not connect to LINK.
- `-- --visual-test` runs a DX12 scene sequence and saves five real rendered frames under runtime.
- `-- --sky-test` saves DX12 cloud/terrain captures; `--headless --path . --script res://tools/check_sky_motion.gd` checks motion between the captured sky frames.
- `-- --interior-test` captures the abstract cable canopy, transistor/web close-up, PCB ground detail and an elevated stacked-board overview using the actual DX12 scene.
- `-- --terrain-test` drives the actual character across all seven slab bridges and checks that each upper board is reached without jumping.
- `--headless --path . --script res://tools/audit_normals.gd` checks outward slab/ramp winding, negative mesh scales and compatibility with existing smoke-save resource X/Z positions.
- VS Code tasks expose play, gameplay smoke and companion tests.

See [VALIDATION.md](./VALIDATION.md) for exact status and limitations. Save data stays under project `runtime` when launched through the supplied launchers. All generated runtime state, certificates, keys, caches and build/tool binaries are ignored by Git. Automated smoke tests never replace `save.json`.

Terrain saves are now version 2. Loading an earlier heightfield save preserves inventory/survival/resource state and relocates the player's vertical position onto the new board surface. Resource X/Z coordinates and IDs remain compatible. Both native and browser LINK maps receive the actual slab layout. Decorative component props and sky cables remain visual geometry; the slabs and connecting ramps have real collision.

## Remaining work

Production art/animation; animated player arms and attachment collision; free object manipulation; richer ecological species, reproduction and decomposition; advanced component combat; oceans and underground exploration; streaming planetary chunks/orbit/space; full-sector traffic/navigation stress testing; actual two-player multiplayer movement; browser-hosted remote companion pairing; durable identity/history/moderation; full external OAuth/SDK integration; trusted deployment certificates; real Android/iOS and touch-control tests; broader accessibility/audio tests; stable revalidation of the experimental RTX profile; stripped signed production export and installer. No completed planetary scope or production security certification is claimed.

Elapsed implementation time and token usage are unavailable as reliable measurements; no remaining-effort estimate is given.

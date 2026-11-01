# VELUM WebGL 2 build

Start `RUN_WEB.cmd`, then visit http://127.0.0.1:8789/. Keep the server terminal open. The server binds loopback only. `build-web/index.html` must be served over HTTP, not opened as a file. All exported files stay together. WebAssembly MIME handling is included.

The same GDScript gameplay and original procedural assets run through Godot's single-threaded web template. No browser engine installation is required. Desktop Chromium was exercised with actual canvas rendering and keyboard input. Phone/tablet touch controls and real mobile hardware validation remain outstanding.

Controls: E hatch / hold salvage, T tool, WASD move, click for mouse capture or left-drag to look, Tab terminal, C membrane, F refill, 1–6 panels, M attachment, O orientation, arrows tilt/pivot, Q/R probe, K save, L load. **Music starts OFF on every launch.** Enable it in LINK; its volume is remembered. Browser storage is per origin/profile; clearing site data removes saves. Private browsing durability is not guaranteed.

F10 offers web performance/balanced/quality/ultra presets and **40–100% render scale**, with optional adaptive scaling toward 60 FPS. `[ / ]` change manual scale; `P` cycles web quality. UI stays at output resolution. The live panel reports measured FPS, internal scale and frame time. The latest steady full-game desktop Chromium sample reached 78 FPS, 75% scale and 13.9ms p95 on the RTX 4080; this is not a universal minimum or a mobile-hardware result. Additional gameplay/probe views are separately validated in VALIDATION.md.

The web bridge in `web/presentation-state.js` mirrors only scissor enable state and draw framebuffer binding. Emscripten's offscreen presentation queried those synchronously each frame; CPU profiling showed this dominated frame time. The bridge observes the actual GL state-changing calls, passes every other query through, handles context loss and has a runtime truth check that disables caching if states differ. Semantic tests and real-context comparisons passed. Opt out with `?gpu-state-cache=off`; performance can decrease. No browser security setting or vendor SDK file is modified.

WebGL's Compatibility renderer cannot provide the native Forward+ GI/volumetric/DLSS feature set. This build preserves geometry, procedural cable sky, signal weather, directional shadows, local map/scanner/probe and gameplay, with distance fog and MSAA. It is not visually identical to the desktop Ultra profile. See [official Godot web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

Remote pairing/chat from a browser-hosted game is not implemented yet. The native host API is loopback-authenticated and its key must never enter a browser bundle. The web export contains no runtime key/session files. A separate approved browser-host protocol is required for full companion parity; the existing companion remains available with the native game.

`BUILD_WEB.ps1` imports and exports using verified 4.7.2 templates on D:. `tools/SETUP_WEB_TEMPLATES.ps1` downloads the official archive, verifies SHA512, and extracts web templates. The portable `_sc_` marker keeps editor configuration on D:. The main build is single-threaded. `/fast/index.html` is a separate threaded test build needing cross-origin isolation; separate render-thread mode was rejected by the display server and removed. It is not the default or an assumed performance improvement.

The `#qa` URL fragment exposes read-only state for local browser QA; it grants no host/server permission. `#render-benchmark` runs a clearly labeled rotating-cube engine baseline without gameplay. Its numbers must never be presented as VELUM game performance.
# Labyrinth update

**One-click web release:** extract `VELUM-web.zip` from the GitHub Releases page, then run `RUN_WEB.cmd`. Node.js 22+ is required. The launcher opens the browser automatically, reuses an existing VELUM web server and shows failures instead of immediately closing. Developers can use `RUN_WEB.ps1 -NoBrowser` to validate readiness without opening a tab. The source repository does not store generated WebAssembly exports; the release ZIP includes them and the required third-party notices.

The performance default leaves triangular DOF **off** on WebGL; enable it in LINK if desired. Native defaults to DOF on. Chromium profiling found synchronous `checkFramebufferStatus` stalls in the depth/screen-reading pass, so the baseline avoids that pass rather than caching potentially stale framebuffer completeness. FFT sky/gel, corrosion, flowing coolant and distance-culled growth remain available. Real mobile testing and sustained 60 FPS across all scenes remain unverified.

After disabling that pass by default, the active desktop Chromium test at seed 123456 reported **60 FPS**, **16.67ms** frame time/p95, **75% render scale**, 175 draw calls and 6.3ms process time. This was a short local sample, not a complete level traversal or a phone test. The native and web builds intentionally use different effect budgets.

The default web game now runs the 81-section labyrinth mission described in [README](./README.md). The same hatch, movement, local map and revision state have been browser-tested. Native fog is approximated with mist billboards on WebGL. The previous survey-sector FPS measurements do not establish 60 FPS for this new maze; new sustained foreground performance is unverified. Section rebuilding is currently synchronous. Real Android/iOS hardware remains untested.

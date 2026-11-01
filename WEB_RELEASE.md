# VELUM — playable web preview

1. Extract the entire ZIP into a folder.
2. Install Node.js 22 or newer from https://nodejs.org/ if it is unavailable.
3. Double-click **RUN_WEB.cmd**. The launcher opens http://127.0.0.1:8789/ in your browser.

Click the game, press **E** to hatch, use **WASD** to move, mouse/left-drag to look, **Space** to jump, **T** to select a tool, hold **E** to salvage, **C** to grow the membrane, **Tab** for LINK, and **F10** for graphics. **K/L** save/load in browser storage. The LINK menu contains the world seed and visual-effect controls. Music starts off.

Keep `build-web` and `tools` beside the launchers. The local server runs in the background. Re-running the launcher reuses an existing VELUM server. To use another port: `powershell -ExecutionPolicy Bypass -File RUN_WEB.ps1 -Port 8791`.

This is a bounded, streamed 3D labyrinth prototype, with placeholder procedural art and incomplete megacomplex content. WebGL uses a reduced effect budget; native VoxelGI, DLSS and NVIDIA frame generation are unavailable in browsers. Triangular DOF is optional and defaults off on web. Real mobile hardware and sustained 60 FPS across every scene are unverified. Remote LINK pairing for the web-hosted game is unfinished. Native service adapters are labeled mocks; no live Twitch/Discord integration is claimed.

The ZIP includes Godot engine notices and CC0 music attribution under `licenses`. Source and current status: https://github.com/acsokis/velum .

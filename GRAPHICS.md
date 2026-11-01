# VELUM graphics profiles

The default native launcher now requires the validated **NVIDIA Godot branch / Vulkan**. Its initial profile is **VoxelGI 512 + DLSS Quality**; F10 still permits selecting SDFGI. Maze VoxelGI is freshly baked for the current section and rebuilt after section changes, with SDFGI used during preparation. Survey caches are not reused for maze geometry. Rebuilding can cause a pause. WebGL remains on the official Compatibility renderer without native VoxelGI/DLSS. Native warm vapor uses six local froxel volumes with actor-velocity wakes; WebGL uses displaced billboards. This is analytical swirling/dissipation, not a pressure-based fluid solver.

Open **F10**, or LINK → **Graphics / Display**. **Alt+Enter** toggles fullscreen. Stock settings persist in `runtime/graphics.cfg`; the NVIDIA engine uses `runtime/graphics-rtx.cfg`, both on D:. Window/display changes require **Keep display** within 15 seconds or the previous configuration returns automatically. Native resolution, 3D render resolution and upscaling are reported separately.

## Illumination and effects

- **SDFGI**: cascaded signed-distance-field global illumination, with occlusion and bounce feedback. High uses four GI cascades / 0.35m minimum cells; Ultra uses six / 0.22m. This is not hardware path tracing.
- **VoxelGI**: optional baked 512-cell volume covering 248 × 64 × 248m, with two bounces. The current generated volume contains 20,463,312 bytes of cell data; its complete serialized cache is about 66MB. Cache filenames include the circuit revision and engine version and stay under runtime on D:. First use prepares the cache, subsequent use loads it. Higher spatial detail or a fixed voxel volume is not automatically superior for every view; compare both modes. VoxelGI 512 is costly on this scene and no fixed frame-rate gain is promised.
- **Real volumetric fog**, temporal reprojection, anisotropic scattering, GI injection and three shadowed colored spotlights. The procedural cable-canopy shader remains the backdrop; its dust-cloud pattern is separate from the world-space volumetric effect.
- **Four-split directional PSSM shadows** with blended splits and a 4096px atlas. These shadow cascades are separate from SDFGI's cascades. High shadow range is 110m; Ultra is 150m.
- Separate **SSAO**, **SSIL**, **SSR**, bloom/glow and VSync controls. Static board/component geometry contributes to GI; moving creatures, egg petals, resources and LINK are marked dynamic.

## Resolution and window controls

Window resolutions include 1280×720, 1280×800, 1600×900, 1920×1080, 2560×1440 and 3840×2160, clamped to the desktop's usable area when necessary. Fullscreen uses monitor output resolution; use render scale or upscaler quality to change the internal 3D resolution. Modes: windowed, borderless fullscreen and exclusive fullscreen. This does not change Windows' desktop resolution or HDR configuration.

Native + TAA supports 50–100% internal scale. FSR 2 Quality/Balanced/Performance use approximately 66.7/58.8/50%. DLSS/DLAA modes appear only when the actual NVIDIA engine/runtime reports support. FSR is never labeled DLSS.

## NVIDIA DLSS / Frame Generation profile

The normal stock Godot 4.7.2 build has no DLSS/FG API. A separate engine was compiled from the official [NVIDIA Godot branch](https://github.com/NVIDIA-RTX/godot/tree/nvidia-pt-dlss), pinned to commit `135dff3887a3d2ccf45cafbd9bdffa7b718e1e76`, with the matching production [Streamline 2.10.0 SDK](https://github.com/NVIDIA-RTX/Streamline/releases/tag/v2.10.0). It identifies as `4.8.dev.custom_build`, and is an experimental engine integration rather than an official Godot stable release.

All new tools, dependencies and outputs live on D:. Existing Visual Studio C++/Windows SDK/Python installations were reused. No CUDA Toolkit, local AI development service or inference framework was installed. The local engine build disables Streamline's automatic runtime-download flags and uses the pinned libraries. NVIDIA runtime signatures and the Microsoft DX12 runtime signature were checked. Licenses accompany the build. These checks are not a malware-free certification.

**On the tested RTX 4080, the current package passes native DLSS + SDFGI and DLSS + VoxelGI through Vulkan. FG remains disabled because the current fullscreen check produced zero extra presentations.** SDK support flags alone are not treated as success. The NVIDIA fork's Direct3D 12 path previously crashed inside `nvwgf2umx.dll` when running this scene. Stock Godot's DX12 GI/VoxelGI path passed. No system driver was changed. Therefore the launch profiles remain separate:

- **RUN_BUILD.cmd** chooses the hash-validated NVIDIA/Vulkan package when available, otherwise the standard DX12 package.
- **RUN_RTX.cmd** explicitly selects the validated NVIDIA/Vulkan package.
- **RUN_DX12.cmd** explicitly selects stock Godot / Direct3D 12; DLSS/FG are unavailable there.
- **RUN_VELUM.cmd** runs the editable stock-Godot project.

Supported NVIDIA hardware/OS/driver capabilities are checked through the native Streamline API. Reflex is automatically enabled with FG. In-game VSync is disabled for this FG profile. FG pauses during graphics/LINK menus, display confirmation, loading and voxel-cache preparation. The main renderer warms before temporal upscaling/FG activates.

The fork includes small local diagnostic counters: successful `slEvaluateFeature` calls and SDK-reported actual presentations from `slDLSSGGetState`, queried on the presenting thread. A historical SDFGI run recorded 1307 SR evaluations / 891 extra FG presentations, but later runs were inconsistent. The current 3840×2160 fullscreen test reported 2592 SR evaluations and zero extra FG frames, so it correctly failed FG validation. The subsequent DLSS-only runs passed with 1133 SR evaluations (SDFGI) and 255 (VoxelGI, including first-bake time). `validated.json` records `frame_generation_verified: false`; the UI/runtime require a verified exact-package marker before enabling FG. No 2× FPS or artifact-free interpolation claim is made.

## Build and verification

`BUILD.ps1` packs eight allowlisted source files plus an empty exported script-class cache. `tools/BUILD_RTX_ENGINE.ps1` compiles the local NVIDIA source and stages signed runtime libraries. The stored source contains local diagnostic-counter additions and the no-OTA change; these must be retained when rebuilding. The first successful native-engine compile reported **00:09:09.62** in its build log; this is only that compile's measured duration, not total task time or an estimate. Token usage is unavailable.

Useful runtime tests:

- `-- --graphics-test`: real display/viewport changes, High→Ultra GI, FSR2, windowed/borderless/exclusive, auto-revert and isolated settings save/load.
- `-- --voxel-test`: actual bake/load/render of the populated 512 VoxelGI volume.
- NVIDIA executable: `--rendering-driver vulkan -- --dlss-test`, optionally `--gi-voxel` after the separator, verifies native SR/FG counters.

The NVIDIA release template automatically loads adjacent `VELUM.pck`; it intentionally does not accept `--main-pack`. `tools/VERIFY_RTX_RUNTIME.ps1` requires successful full-GI and VoxelGI SR/FG logs, then records the tested executable/PCK hashes and runtime DLL hashes. The launcher checks that marker against the current package. Repacking code invalidates a previous package marker until revalidated. Hardware validation so far is this Windows / RTX 4080 PC only.

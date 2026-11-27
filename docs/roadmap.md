# Development roadmap

| Phase | Work | Exit evidence |
|---|---|---|
| 1. Research and architecture | Record upstream compatibility, boundaries and licenses. Implement portable PE and Wine version diagnostics. | Linux tests and documented gaps. Initial foundation is in this repository. |
| 2. Compatibility engine | Provision Apple Silicon and Xcode. Pin a user-provided Darwin Wine 11 build by digest. Inspect host slices and dependencies, probe the loader, and bootstrap two distinct test prefixes. Start a separate native Darwin Wine/FEX spike. | Repeatable prefix creation and Windows x86-64/x86 fixture runs on macOS. Record ARM64 and ARM32 feasibility independently. |
| 3. Installation | Add isolated EXE/MSI install, registered uninstall, operation state and cancellation recovery. Test local and external APFS roots. | Known EXE and MSI install, repair or uninstall as appropriate. Recover from cancelled installation and external disk removal with catalog integrity. |
| 4. Execution | Persist launch targets and overrides, track child process lifecycle and return structured diagnostics. Add dependency recipes as specific compatibility cases require. | Arguments and working directory survive round trips, apps relaunch after reboot, and independent prefixes retain distinct settings. |
| 5. Graphics | Compare WineD3D, DXMT and pinned DXVK with tested Vulkan ICDs. Evaluate VKD3D-Proton after required capabilities are observed. | D3D9/11/12 results recorded per backend, including unsupported paths, with rendering checks and frame-time measurements. |
| 6. Steam | Validate the experimental Steam installer and App ID launcher with [GTA V Legacy Story Mode](gta-v-m4.md) on Apple Silicon. | Login, install, launch, update and relaunch work for the tested title. Document title-specific DRM and anti-cheat limitations. |
| 7. Gaming optimisation | Measure controller, display, CPU translation, sync, cache and storage effects. Add title profiles from observed regressions. | Repeatable benchmark reports include cold/warm runs, median and tail frame times, memory pressure and visual checks. |
| 8. Native macOS integration | Build typed Swift service adapters and the SwiftUI app in Xcode. Connect library, settings, install and diagnostics flows. | Xcode builds and macOS UI tests pass, including external volume disconnect and remount. |
| 9. Qualification and distribution | Test demanding workloads across Apple Silicon generations and supported macOS versions. Sign and notarize a release after artifact and license review. | Reproducible engine builds or provenance, published support matrix, verified distributable and documented recovery steps. |

## Next milestone

On an Apple Silicon Mac with Xcode, select a trusted, pinned Darwin Wine build and record its digest, Mach-O slices, macOS version, SoC and Rosetta state. Run `probe-wine`, then implement explicit-prefix bootstrap and supervised launch. Build small Win32 fixtures from source with a suitable cross-compiler. Run x86-64 and x86 fixtures in separate prefixes, assert their exit codes and distinct registry markers, and retain stdout, stderr and Wine logs. Repeat with Rosetta or the expected slice unavailable and verify the diagnostic. Use the native Darwin Wine/FEX spike to assess feasibility beyond the Rosetta support window.

The release qualification set should include a demanding D3D11 game, a D3D12 game and a non-game workload with substantial installer and runtime dependencies. Compatibility reports should name the engine digest, guest architecture, macOS build, hardware, backend, reproduction inputs and observed outcome.

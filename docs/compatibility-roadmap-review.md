# WinBridge compatibility against the original brief

WinBridge combines Windows API compatibility, CPU translation, and software
management. Wine implements Windows user-mode APIs, loads PE files, and
provides the process, registry, and Windows installation environment.
Rosetta translates the x86-64 host process on Apple Silicon. New WoW64 runs
32-bit Windows code within that environment. Graphics translation and
additional Windows-compatible libraries are separate components. WinBridge
can improve a stock engine by managing those components and validated
per-application settings. New Windows API coverage still requires an
upstream engine change or a compatible implementation of the missing API.

| Original requirement | Current preview | Next engineering gate |
|---|---|---|
| Core Engine | Pinned Wine 11.0, Rosetta and new WoW64, PE preflight, explicit process arguments, per-action logs | Versioned runtime capabilities and reproducible builds with Wine TLS, font and media support |
| Application Manager | Native catalog with separate prefixes, EXE run and installer routing, MSI install/uninstall, per-profile DLL imports | Installed EXE discovery and registry-backed uninstall entries, dependency recipes, interrupted-install recovery |
| Gaming Engine | Steam workflow, Metal HUD opt-in and frame-time analysis | Validate DXMT and DXVK with their exact Darwin prerequisites, add shader cache and controller/fullscreen checks, then qualify GTA V Legacy |
| Storage Manager | Separate generated prefix per app under a selectable storage folder, separate Steam prefix | External SSD identity across mounts, reclaimable cache reporting, safe migration |
| Native UI | Windows Apps and Steam tabs, path selection, file preflight, logs, SwiftUI, signed updater integration | Installed game library and performance presets after real game validation |
| CPU architectures | x86 and x86-64 exercised using Wine. PE headers recognize ARM32, ARM64, ARM64EC, and ARM64X | Qualify macOS ARM64 Wine first, then native Wine plus a verified Darwin FEX port for x86 execution. ARM32 needs its own guest execution path |

## General Windows application workflow

1. In **Windows Apps**, add a profile. Each profile gets a unique Windows
   directory and registry. The profile can use the bundled engine or select
   an alternate Wine executable for the same x86/x86-64 guest targets.
2. Select a Windows EXE and choose **Run EXE**. For an installer, choose an
   EXE or MSI under **Install or uninstall**. Windows Installer validates
   MSI packages after the native preflight recognizes the compound-file
   header. Bootstrappers can launch children with a different architecture.
3. Use **Browse Windows Files** to find the installed EXE. Keep the original
   MSI to uninstall via Windows Installer. For an EXE uninstaller, use Run EXE.
4. If an application needs a compatible native DLL, initialize the profile
   and import the DLL obtained from a trusted, appropriately licensed source.
   WinBridge keeps x86 and x86-64 DLLs separate, checks their declared
   architecture, and supplies profile-local search paths and load preferences.
   Packages that require registry entries or native host libraries still need
   their own installers. An isolated Wine environment shares the host user's
   permissions. Inspect logs for execution failures or missing dependencies.

## Extending compatibility

- **Dependencies first.** The baseline omits GnuTLS, FreeType, GStreamer and
  Vulkan. Add these through reproducible, relocatable builds with corresponding
  source and notices. Verify Windows HTTPS, font rendering, media and
  application installers independently before selecting them as defaults.
- **Graphics next.** DXMT needs the matching Wine macOS driver interfaces.
  DXVK and VKD3D-Proton need their host Vulkan profiles checked against
  MoltenVK or KosmicKrisp on Apple Silicon. Qualify correctness and frame
  pacing on real hardware. Use GTA V Legacy Story Mode as the first demanding
  benchmark. [DXMT runtime requirements](https://github.com/3Shain/dxmt/wiki/Device-System-Runtime-Specifications)
- **Native emulation track.** The experimental Darwin Wine/FEX ports are
  candidates for an additional engine. Validate 16 KiB host page assumptions,
  Windows thread/exception handling, JIT signing and both x86 guest widths
  before offering one in the app. Apple lists general-purpose Rosetta support
  through macOS 27. Linux FEX and Proton results need independent macOS
  reproduction. [Darwin Wine/FEX experiment](https://github.com/Irz-Z/wine-macos-native) ·
  [Apple's Rosetta timeline](https://developer.apple.com/news/?id=w5ngl9k2)
- **Windows drivers and compatibility claims.** Kernel drivers and specific
  DRM or anti-cheat systems may require a Windows kernel or vendor support.
  The project uses Windows-compatible components and CPU translation
  without installing a Windows OS image. Publish test results per app,
  architecture, runtime, graphics backend and macOS version.

The release checks native profile persistence and PE classification. On
Apple Silicon it initializes a new Wine environment, runs an EXE before and
after installing a profile-local DLL, installs and uninstalls a real MSI,
and checks the installed file and prefix isolation. These small test
programs come from source in this repository. They establish that the
paths work and provide no performance or compatibility rating for GTA V.

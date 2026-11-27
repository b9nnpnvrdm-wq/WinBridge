# Bundled Wine engine

WinBridge builds [Wine 11.0 from source](https://github.com/wine-mirror/wine/tree/db11d0fe6a169c457e23d007e20404643d067aa8)
for x86-64 macOS with new WoW64 and includes the installed runtime under
`WinBridge.app/Contents/SharedSupport/Wine`. WinBridge itself is native
arm64. The bundled x86-64 engine requires Apple's Rosetta on Apple Silicon.
An external, separately supplied engine can still be selected in the app.

The WinBridge build [patches wineserver's default idle timeout](https://github.com/b9nnpnvrdm-wq/WinBridge/blob/main/scripts/patches/wine-idle-server.patch)
from three seconds to 45 seconds. Reopening the same environment soon after a
Windows process exits can reuse the wineserver state. A fresh environment
still has to initialize its Windows files and registry. The published
corresponding source archive includes this change.

The [build recipe](https://github.com/b9nnpnvrdm-wq/WinBridge/blob/main/scripts/build-wine-macos.sh)
uses Xcode and a pinned LLVM-MinGW toolchain. Wine is licensed under
LGPL-2.1-or-later. The exact Wine source is supplied as
`wine-11.0-source.tar.gz` with the same [GitHub prerelease](https://github.com/b9nnpnvrdm-wq/WinBridge/releases)
as the app. Wine's license and author notices are inside the runtime.
The runtime carries Wine's open-source implementations of Windows system
components. Steam, Rockstar components and proprietary Windows files are
supplied through their normal installers.

The engine includes FreeType 2.15.0 under the FreeType License (FTL).
The release includes its exact source archive, and the engine carries its
license and notices. The engine still omits GnuTLS, GStreamer and Vulkan.
It can therefore lack Windows TLS, multimedia and graphics capabilities
required by specific applications. Use an external engine with the necessary components
for broader Steam testing. No GTA V compatibility or performance rating has
been established for the built-in engine.

WinBridge bundles the Wine Mono 10.4.1 shared runtime expected by Wine 11.0.
It is stored under `share/wine/mono` in the engine and is available offline
to prefixes. The release carries the corresponding upstream source.
The WinBridge build uses its own name for the macOS application menu and
the runtime's primary environment update and error dialogs. Wine and Wine
Mono remain credited in the included notices and source archives.

[Wine Mono 10.4.1 source and releases](https://github.com/wine-mono/wine-mono/releases/tag/wine-mono-10.4.1)

# WinBridge

WinBridge is an Apple Silicon-first project for running Windows applications and games on macOS using Wine and graphics translation. The repository contains development diagnostics, the technical design, and an experimental Windows Steam launcher that uses a supplied Wine runtime. Steam gameplay on macOS remains unverified.

## Open the Mac app

WinBridge has a native graphical preview for Apple Silicon and macOS 14 or
later. Download the macOS preview ZIP from [GitHub Releases](https://github.com/b9nnpnvrdm-wq/WinBridge/releases),
unzip it, and double-click `WinBridge.app`. First-run setup asks which Wine
engine to use. Change it later in **WinBridge → Settings** (⌘,). In Finder,
Control-click an EXE and choose **Open With → WinBridge** to open it and save
it to the library. Drag EXEs onto **Windows Apps** to add them for later.
The **Windows Apps** tab runs Windows EXEs,
installs through EXE or MSI, and uninstalls MSI packages. Create a separate
profile for each app to keep its Windows files and registry isolated. The
**Steam** tab guides you through Steam Setup and launching by App ID. Windows
processes use the included [Wine 11.0](docs/bundled-wine.md) under Rosetta.
The app does not require Python. [Automatic update setup](docs/automatic-updates.md)
describes how signed releases reach existing installations.

The preview is ad hoc signed. Developer ID signing and Apple notarization
are pending. See [macOS packaging and download publishing](docs/macos-preview.md)
for the build and GitHub Pages setup.

## Run the development diagnostics

From the repository root on Linux or macOS with Python 3.10 or later:

```sh
python3 -m winbridge inspect-pe '/path/to/application.exe'
python3 -m winbridge probe-wine --wine '/path/to/trusted/wine'
python3 -m unittest discover -s tests -v
```

Successful commands write a JSON object to stdout. Errors go to stderr and return a nonzero status. The Wine command searches PATH when no executable is supplied. Use a trusted executable, since the probe runs it with `--version`. The version result describes a loader invocation. The PE result describes the machine field and image headers, so hybrid payloads and the architectures of bundled programs can require further inspection. MSI packages require separate inspection.

## Try Windows Steam on macOS

Use a trusted Darwin Wine build with x86 and x86-64 guest support, its required
dependencies, and Rosetta if the loader is x86-64. Get Windows Steam Setup from
[Valve](https://store.steampowered.com/about/). Run from the repository root and
replace the Wine path with the loader from your build.

```sh
wine_loader='/absolute/path/to/wine'
steam_prefix="$HOME/Library/Application Support/WinBridge/Steam"
mkdir -p "$(dirname "$steam_prefix")"
python3 -m winbridge steam-install "$HOME/Downloads/SteamSetup.exe" \
  --wine "$wine_loader" --prefix "$steam_prefix"
```

Let Steam update, sign in, and install a Windows game you can access. If Steam
is closed, start it with `steam-launch` and omit the App ID. Use the actual
`Steam.exe` path if you changed the install directory.

```sh
steam_client="$steam_prefix/drive_c/Program Files (x86)/Steam/Steam.exe"
game_app_id='YOUR_NUMERIC_APP_ID'
python3 -m winbridge steam-launch "$steam_client" \
  --wine "$wine_loader" --prefix "$steam_prefix" --app-id "$game_app_id"
```

The command forwards Valve's `-applaunch` argument and returns the Wine
process status. Confirm the game reaches its main menu and renders gameplay.
An already running Steam client can accept the request and run the game in
another process. The supplied Wine build and prefix determine graphics support.

## Repository layout

- `winbridge/` contains the portable diagnostics and Steam launcher.
- `tests/` contains generated PE fixtures and process tests. No Windows binaries are included.
- [Architecture and upstream research](docs/architecture.md)
- [Development roadmap and validation gates](docs/roadmap.md)

GTA V Legacy Story Mode is the first demanding game target.
See the [M4 Mac mini validation guide](docs/gta-v-m4.md) for the Steam App ID,
graphics backend comparison, and frame-time analysis.

[Compatibility roadmap review](docs/compatibility-roadmap-review.md) tracks what this preview implements and what still requires engine work.

For Steam update errors, use **Quit Steam**, then **Repair Steam Environment**
in the Steam tab before opening the client again. Repair runs the engine's
configuration update in place after saving its existing Windows registry files.
For a black Steam window, keep **Use software rendering for the Steam
interface** enabled and quit/reopen Steam so the client receives the new flags.
**Open Steam Logs** shows the client-side bootstrap and browser logs.

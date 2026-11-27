# GTA V on the M4 Mac mini

## First compatibility target

Run the Steam copy of GTA V Legacy in Story Mode using the base M4 Mac mini as
the first reference device. Take the user's copy through Steam and the Rockstar
Games Launcher, including normal sign-in and entitlement checks. Rockstar lists
DirectX 11 support for Legacy. CodeWeavers rates Legacy “Runs Great” on Mac in
CrossOver 26.3.0 and Enhanced “Limited Functionality” in the same version.
These results establish a comparison point for a separately tested WinBridge
engine. Enhanced uses DirectX 12 and has its own qualification track.
Rockstar requires BattlEye for GTA Online. This milestone covers Story Mode,
using Rockstar's supported Story Mode option if needed.
[Legacy on Steam](https://store.steampowered.com/app/271590/Grand_Theft_Auto_V_Legacy/) ·
[Rockstar PC requirements](https://support.rockstargames.com/articles/lMQXeP2Z1mN3g9oZiBZFR/grand-theft-auto-v-pc-system-requirements) ·
[Legacy CrossOver results](https://www.codeweavers.com/compatibility/crossover/grand-theft-auto-v) ·
[Enhanced CrossOver results](https://www.codeweavers.com/compatibility/crossover/grand-theft-auto-v-enhanced) ·
[Rockstar BattlEye FAQ](https://support.rockstargames.com/articles/1nenwhZlVrJY6CTFeSS2Fx/grand-theft-auto-online-battleye-faq)

## Apple Silicon bring-up

1. Record the Mac model, memory, macOS build, display refresh rate and game and
   launcher versions. Set up separate Steam prefixes for each backend. Start
   with a pinned Darwin Wine build and record its version and artifact digest.
2. Install Windows Steam with [WinBridge's Steam commands](../README.md#try-windows-steam-on-macos).
   Install Legacy and test first-run Rockstar sign-in, launcher restart,
   save loading and Story Mode launch via App ID `271590`.
3. Test WineD3D as the baseline. For a second run, provision a Wine build with
   a matching DXMT build and its required winemac interfaces. Verify the game
   actually loads that renderer using backend logs. Compare pinned DXVK only
   after its required host Vulkan features and presentation work.
   [DXMT runtime requirements](https://github.com/3Shain/dxmt/wiki/Device-System-Runtime-Specifications) ·
   [DXMT setup](https://github.com/3Shain/dxmt/wiki/DXMT-Installation-Guide-for-Geeks)
4. Run the built-in benchmark and a repeatable Story Mode driving route.
   Record audio, visual correctness, input, and a 20-minute stability run.
   Capture first-run and warmed-up performance separately. Keep display mode,
   game settings, route and storage fixed when comparing backends or builds.
   Record actual results for each hardware configuration.

## Measure performance and responsiveness

Start at 1920×1080 with DirectX 11, a 60 FPS cap, and the same documented graphics
settings across comparable runs. Use 60 FPS as an engineering target. A frame
has about 16.67 ms at that rate. Track median, p95, p99, worst frame interval,
and the share above budget across at least three warm benchmark runs. Treat
p95 at or below 20 ms and p99 at or below 25 ms as initial frame-pacing goals
for the driving route. These are proposed thresholds to validate on hardware.
Keep first-run stalls visible in a separate report.

For a Metal backend, fully quit Windows Steam and the game, then launch with
`steam-launch --app-id 271590 --metal-hud` alongside the usual client, prefix,
and Wine arguments. The option enables Apple's Metal Performance HUD for the
launch environment. An already-running client may keep its old environment.
Use Instruments' Game Performance template or another per-frame capture source
to export or derive presentation intervals. Keep only the chosen gameplay
window and record its start and end. Normalize its intervals to milliseconds
with one presented-frame interval per row and a `frame_ms` column. Use
present-to-present intervals. GPU duration is a separate measurement and an
averaged HUD FPS sample cannot recover the underlying frame intervals.
[Apple Metal Performance HUD](https://developer.apple.com/videos/play/tech-talks/110339/) ·
[Apple Game Performance in Instruments](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app)

```sh
python3 -m winbridge frame-stats driving-capture.csv --target-fps 60
```

Compare frame pacing at equivalent visuals before raising quality or
resolution. If spikes persist, use Instruments to distinguish CPU work, GPU
saturation, shader compilation, and memory or storage stalls. Measure
controller-to-display latency separately with a high-speed camera and the
same display, controller and repeatable in-game action. Compare against a
Windows baseline only when hardware, frame cap and display differences are
documented. Frame-time statistics alone cannot establish input latency.

## Verification status

The frame analysis and the launch environment are covered by Linux tests.
No GTA V performance or compatibility result for WinBridge has been
collected on macOS.

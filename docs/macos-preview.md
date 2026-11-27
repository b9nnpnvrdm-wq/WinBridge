# macOS preview packaging

The graphical app uses SwiftUI and a Foundation launcher. Its minimum supported
configuration is Apple Silicon with macOS 14. It includes a packaged Wine
runtime built on an Intel macOS runner. See [bundled Wine](bundled-wine.md). The Windows Steam installer and registered Steam client remain
user-provided.

## Build with Xcode

Install Xcode on a Mac and use its default command-line toolchain. Run
`scripts/build-wine-macos.sh` on Intel macOS to produce the runtime archive,
or use the runtime build artifact from the matching GitHub Actions run. Put
the archive in `dist/` on the Apple Silicon Mac, then run from the repository
root:

```sh
xcrun swift test --package-path macOS --arch arm64
./scripts/package-macos.sh
open dist/WinBridge.app
```

The script builds an arm64 executable with the Xcode toolchain, embeds Wine
and Sparkle, assembles
`dist/WinBridge.app`, verifies the bundle, and writes the ZIP and its SHA-256
checksum. The app has an ad hoc signature and is prepared for subsequent
Developer ID signing. The ad hoc preview may be blocked by Gatekeeper when
downloaded. Developer ID and notarization are release steps. Use an unmodified
build and replace the ad hoc signature before submitting it to Apple.
[Apple distribution documentation](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

## Publish the download page

In the GitHub repository, set **Settings → Pages → Build and deployment →
Source** to **GitHub Actions**. Then run **Actions → macOS preview and download
page → Run workflow** on `main`. The workflow builds the app and publishes the
ZIP as a prerelease and as a download on GitHub Pages. A build can publish a
prerelease even if Pages has not been enabled. [GitHub Pages configuration](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)

For signing a release, use a Developer ID Application certificate, enable the
hardened runtime, notarize and staple the final app, then repackage and update the
checksum before distribution.

See [automatic updates](automatic-updates.md) for publishing a signed appcast.

# Automatic app updates

WinBridge uses [Sparkle](https://sparkle-project.org/documentation/) to check
for new app builds on launch and periodically afterward. In a configured
build, Sparkle downloads and verifies signed updates and can install them
automatically. The WinBridge menu also offers a manual check. The feed should
point to published releases with a higher numeric bundle build number.

A repository commit can trigger a preview build. Only a signed release
published to the update feed can update installed copies. Development
previews without a feed and public key link to GitHub Releases instead.
A manually installed update-enabled release is needed to start the update
chain. Keep the same bundle identifier, Developer ID team, and Sparkle update
key on subsequent releases.

## Enable a release channel

1. On the signing Mac, download the [matching Sparkle tools](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.1)
   and run `bin/generate_keys`. Keep the private signing key in the Keychain.
   The tool prints a public key for embedding in the app.
2. Set `WINBRIDGE_UPDATE_PUBLIC_KEY` to the printed public key and
   `WINBRIDGE_UPDATE_FEED_URL` to the public HTTPS URL of `appcast.xml` (for
   example, `https://b9nnpnvrdm-wq.github.io/WinBridge/appcast.xml` once Pages
   is working). These two values are public. The packaging script accepts
   them as environment variables. The GitHub workflow can also read them
   from repository Actions variables.
3. Package each release with a higher `WINBRIDGE_BUILD_NUMBER`. GitHub Actions
   defaults to its run number. Sign the framework and helpers from the
   inside out, then sign the containing app with Developer ID, notarize,
   staple and ZIP the final bundle. Test the embedded Wine engine with the
   production signatures. Wine's translated code may need different hardened
   runtime entitlements from the SwiftUI host. [Sparkle signing guidance](https://sparkle-project.org/documentation/)
4. Upload the final ZIP as a GitHub Release asset. Generate an appcast entry
   with Sparkle's `generate_appcast` tool, using the final ZIP and its permanent
   HTTPS release download URL. Preserve the signed enclosure metadata.
   Publish `appcast.xml` under `pages/` and deploy GitHub Pages, or host it at
   the HTTPS feed URL selected above. Test updating from the preceding
   Developer ID build before distributing widely.

Do not commit the update private key, Apple signing private key, or Apple
credentials. Do not regenerate the Sparkle key for routine releases.

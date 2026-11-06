# Shelf 1.0 release preparation

## Current distribution decision

- GitHub Releases; prepare an **unnotarized preview** first, with the GitHub release marked **Pre-release**. Suggested tag/title: `v1.0-preview.4` / `Shelf 1.0 Preview 4 (Apple Silicon, unnotarized)`.
- Apple Silicon (`arm64`), macOS 15+. Intel support is deferred until separately built and tested.
- The developer currently uses a free Apple account. The preview uses local ad-hoc signing, without Developer ID or notarization. This does not establish a trusted developer identity or guarantee Gatekeeper acceptance.
- Publication is a separate, explicitly authorized step. Local package generation does not create a tag, push commits, or upload assets.

## Build the local preview

From the repository root, with Xcode installed:

```sh
bash scripts/package-preview.sh
```

The script builds Release with certificate signing disabled, copies the app into a staging directory, then applies ad-hoc signing with Hardened Runtime and the project's sandbox/read-write entitlements. It verifies the signature, architecture, and entitlements before creating:

- `dist/Shelf-1.0-preview.4-arm64.zip`: a folder containing `Shelf.app`, bilingual `README.txt`, `LICENSE`, and `BUILD.txt` with version, signing status, and source revision.
- `dist/Shelf-1.0-preview.4-arm64.zip.sha256`: checksum with a relative filename, suitable for `shasum -a 256 -c` from the download directory.

Existing output packages are not overwritten. To rebuild, provide a new output directory, for example `bash scripts/package-preview.sh /private/tmp/ShelfPreviewOutput2`. Temporary build/staging files are kept at the path printed by the script for inspection. Generated `dist/` artifacts are ignored by Git. For a public candidate, commit reviewed source and packaging changes first, then generate a package whose `BUILD.txt` reports a clean tree.

Preview 4 must also include the exact corresponding source archive on the same Release page. Generate it from the clean, tagged commit used to build the binary, and verify that the bundled license and source match.

## Manual preview acceptance

The user accepted the local Preview 2 checklist and reported that Preview 3 login-item registration was resolved. Preview 4 is a newly generated package; validate that exact artifact before relying on earlier results. VoiceOver speech remains deferred.

- Quit the development copy, extract the ZIP, install into Applications, and open it outside Xcode. Repeat on a different Apple Silicon Mac or clean user account if available. Test the actual browser-downloaded asset before promoting a release; local builds do not reproduce download quarantine.
- Check menu-bar launch, shortcut, settings/language persistence, and quit/relaunch. Confirm fresh sessions clear references while keeping source files.
- With disposable files, verify importing, moved/renamed file opening, drag-out, cancellation, and permission/deletion failure **in this ad-hoc signed Release app**. Previous signed Debug acceptance does not establish sandbox/bookmark behavior for this artifact.
- Replace an earlier preview after quitting it, then recheck settings and newly imported files. Do not promise migration of bookmark permissions across signing identities; Shelf does not restore staged files on launch.
- Confirm the ZIP's checksum after download. Record the tested package SHA-256 and Mac/macOS details in the roadmap. VoiceOver speech remains deferred by user choice.
- Check Settings in English and Simplified Chinese: General/Language/Shortcut/About are reachable by scrolling, version is 1.0 (build 4), and copyright is © 2026 Rinko. Disable shake, verify menu/shortcut still work, restart and confirm the preference persists, then re-enable and verify shake gestures resume.
- In the installed ad-hoc signed Preview 4, enable Launch at Login and compare with macOS Login Items. Approve it if requested, return to Shelf to check status synchronization, then log out/in and verify it starts only in the menu bar. Disable, log out/in again, and verify it no longer auto-starts. A failed registration must show its error and actual status; record whether this signing identity is accepted. Disable macOS's separate “Reopen windows when logging back in” option for this test so it does not mask login-item behavior.

If macOS blocks the preview, link users to [Apple's instructions](https://support.apple.com/102445) for the per-app approval flow, where available. Device management may prohibit exceptions. Do not describe the app as notarized or instruct users to disable Gatekeeper globally.

## Before public release

- AppIcon uses the user-supplied document-tray artwork in all ten macOS size/scale entries. Check its Finder and Get Info appearance using the installed app. Shelf's accessory lifecycle does not provide a normal Dock or application-switcher entry.
- Review the usage/privacy/limitations text in `docs/PREVIEW_README.txt` and the draft notes below, including source deletion after successful destination writes.
- Shelf is licensed under GPL-3.0-only; before distributing a release, ensure the package and accompanying source offer meet the license's requirements. Previously generated preview packages have not been checked for GPL compliance.
- The user reported that the current candidate's login-item registration issue is resolved. Verify logout/login and the remaining downloaded-first-launch and upgrade limitations above. After explicit approval, push the selected commit(s), create the chosen tag and GitHub **Pre-release**, and attach the exact tested ZIP and checksum. Do not publish a plain `v1.0` final release from this preview workflow.
- For later Developer ID distribution, join Apple Developer Program, prepare the Developer ID Application signing identity, export the Release archive, submit for notarization, staple the ticket to the app, then re-create and verify the ZIP. Repeat downloaded-install acceptance. See [Developer ID](https://developer.apple.com/developer-id/) and [Apple's notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## Draft GitHub pre-release notes

**Shelf 1.0 Preview 4 — Apple Silicon / macOS 15+**

This is an **unnotarized test preview**, locally ad-hoc signed without Developer ID. macOS may block first launch. Read the bundled bilingual README and [Apple's per-app approval instructions](https://support.apple.com/102445) before installing.

Shelf temporarily stages file references in a menu-bar panel, with mouse-shake and keyboard activation, multi-file selection, file/folder imports, duplicate detection, and English/Simplified Chinese. Moving a source file can be followed through its bookmark; unavailable files and opening failures display warning badges.

Preview 3 added native Launch at Login, a persisted mouse-shake gesture toggle, version/build and © 2026 Rinko in Settings, and a GitHub feedback link. Login registration is opt-in and reflects macOS approval/errors.

**File behavior:** dragging out successfully writes a destination copy before attempting to delete the source. If source deletion fails, the item remains and the destination may already have a copy. Cancelling a drag or failing to write preserves the source. Removing, clearing, or hiding Shelf only removes references. Hiding or restarting clears the temporary session.

Download `Shelf-1.0-preview.4-arm64.zip` and its `.sha256` file, verify with `shasum -a 256 -c Shelf-1.0-preview.4-arm64.zip.sha256`, extract, and drag `Shelf.app` into Applications after quitting any running copy.

Preview 4 includes the GPL-3.0-only license and matching source distribution. Verify this newly generated package independently. Known limitations: no Intel build; no Developer ID/notarization; VoiceOver speech unverified. Browser-downloaded first launch, other machines, and preview-to-preview upgrades remain unverified. Report issues with macOS version, reproduction steps, and error text, without private files.

# Shelf

Shelf is a macOS menu bar utility for temporarily holding files. Drag files from Finder and shake the mouse left and right to open Shelf near the pointer, or use the menu bar or `⌃⌥Space`.

## Usage

* Drag files or folders into Shelf for temporary storage. Repeated files or folders are kept only once.
* Drag them out to Finder or another app. After a successful transfer, Shelf moves the files by deleting the originals.
* Cancelled or failed transfers keep the original files unchanged.
* Removing items or clearing Shelf only removes references, not the source files.
* Shelf is temporary and clears its contents when the app launches, is hidden, or starts a new session.
* Settings includes native launch at login, a mouse-shake gesture switch, language and shortcut controls, version/build information, and a feedback link. Login startup is opt-in; menu and shortcut activation work with shake disabled.

## Privacy

Shelf does not upload or edit file contents. It only stores temporary file bookmarks and basic metadata required for thumbnails and drag-and-drop.

Original files are deleted only after you drag them out and the destination successfully completes the transfer.

## Development

For local Apple Silicon preview packaging, distribution decisions, and release acceptance, see [release preparation](docs/RELEASE.md). This workflow produces an unnotarized test preview, not a final release.

Project instructions are in [AGENTS.md](AGENTS.md); see the [architecture](docs/ARCHITECTURE.md) and [roadmap](docs/ROADMAP.md).

From the repository root on Apple Silicon, run the following separately. UI tests require a usable macOS desktop; signing is disabled and these checks do not validate a release build.

```sh
xcodebuild -quiet build -project Shelf.xcodeproj -scheme Shelf -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/ShelfWorkflowDD CODE_SIGNING_ALLOWED=NO
xcodebuild -quiet test -project Shelf.xcodeproj -scheme Shelf -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/ShelfWorkflowDD -only-testing:ShelfTests CODE_SIGNING_ALLOWED=NO
xcodebuild -quiet test -project Shelf.xcodeproj -scheme Shelf -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/ShelfWorkflowDD -only-testing:ShelfUITests CODE_SIGNING_ALLOWED=NO
```

Use disposable files for manual transfer and deletion tests. Record actual results and unverified cases in the roadmap.

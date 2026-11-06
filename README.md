# Shelf

Shelf is a macOS menu bar utility for temporarily holding files. Drag files from Finder and shake the mouse left and right to open Shelf near the pointer, or use the menu bar or `⌃⌥Space`.

## Requirements

Shelf requires macOS 15 or later. The current preview is for Apple Silicon; Intel builds have not been tested.

## Getting started

Open Shelf and use its menu bar icon, press `⌃⌥Space`, or shake the mouse while dragging files to show the shelf. Drag files or folders onto it, then drag them to their destination when ready.

**Moving files:** after the destination successfully receives a drag, Shelf attempts to delete the originals. If deletion fails, the destination may already contain copies and the affected items remain in Shelf. Use disposable files when trying this behavior for the first time.

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

## License

Shelf is licensed under the [GNU General Public License v3.0](LICENSE) (GPL-3.0-only).

## Development

For local Apple Silicon preview packaging, distribution decisions, and release acceptance, see [release preparation](docs/RELEASE.md). This workflow produces an unnotarized test preview, not a final release.

Project instructions are in [AGENTS.md](AGENTS.md); see the [architecture](docs/ARCHITECTURE.md) and [roadmap](docs/ROADMAP.md).

From the repository root on Apple Silicon, run the following separately. UI tests require a usable macOS desktop; signing is disabled and these checks do not validate a release build.

To run a normally signed build in Xcode, select your own development team in Signing & Capabilities.

```sh
xcodebuild -quiet build -project Shelf.xcodeproj -scheme Shelf -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/ShelfWorkflowDD CODE_SIGNING_ALLOWED=NO
xcodebuild -quiet test -project Shelf.xcodeproj -scheme Shelf -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/ShelfWorkflowDD -only-testing:ShelfTests CODE_SIGNING_ALLOWED=NO
xcodebuild -quiet test -project Shelf.xcodeproj -scheme Shelf -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/ShelfWorkflowDD -only-testing:ShelfUITests CODE_SIGNING_ALLOWED=NO
```

Use disposable files for manual transfer and deletion tests. Record actual results and unverified cases in the roadmap.

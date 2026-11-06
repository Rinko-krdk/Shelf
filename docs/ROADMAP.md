# Roadmap

Updated 2026-11-07. Implementation does not imply acceptance. See [architecture](ARCHITECTURE.md) for current design and transfer safety boundaries.

## Current stage

The core MVP is implemented: duplicate-file detection, menu bar and floating panel, shortcut and shake interactions, ordered file and folder imports, temporary sessions, thumbnails, selection, English and Simplified Chinese, and single or multiple file-promise exports. Phase 5 (reliability and release readiness) is in progress; earlier phases still need desktop acceptance.

### Verification baseline: 2026-11-06

From the repository root, using the commands in [README](../README.md#development), macOS arm64, `/private/tmp/ShelfWorkflowDD`, and signing disabled:

- Build: exit 0. Swift concurrency isolation and captured-variable warnings remain, as does a redundant cast warning.
- Unit tests: exit 0, 37 passed.
- UI tests: the window-drag UI test was removed after repeated simulated drags failed to move the panel. Manual window movement remains unverified for release acceptance. The selection/expansion flow passed in an earlier run; the latest full run before removal passed three of four tests. Rerun the remaining suite to establish its current result. An earlier signing-disabled runner was blocked before connection, with a system trust prompt and certificate temporal-validity errors in the logs.
- Real Finder/other-app drag-and-drop, signing, notarization, and clean installation remain unverified. A signing-disabled build is not release validation.

### Verification update: 2026-11-07

- After adding file-location deduplication, 39 unit tests and all four existing UI tests passed with normal signing. Real duplicate-file drag-and-drop still needs a manual check.

- A normally signed macOS arm64 UI run passed all four remaining tests before the two warning-only source edits; the deleted window-drag test is not included.
- After those edits, the signed unit-test build and all 37 unit tests passed. The shortcut closure capture and redundant drop-import cast warnings were addressed; persistence actor isolation warnings remain for separate investigation. No clean build was performed.
- The working tree includes existing panel diagnostics that write to `/private/tmp/shelf-drag-log.txt` and change the window level; review these before release. Manual window movement and real drag-and-drop remain unverified.

## Active development

1. Investigate persistence actor isolation warnings; review existing panel diagnostics and verify window movement. Repeat UI tests after relevant changes.
2. Use disposable files to validate Finder → Shelf → Finder and at least one other target, including cancellation, rejection, copy failure, missing deletion permission, deletion failure, and partial success.
3. Verify session boundaries, external file changes, persistence recovery, window behavior, accessibility, and performance. Record defects and results here.
4. Review usage, privacy, and limitations before separately authorized signing, notarization, and release work.

## MVP acceptance

- [ ] Menu bar, shortcut registration and fallback, Esc, panel placement, focus, and drag behavior work across apps, screens, and Spaces.
- [ ] Files and folders import in order; repeated file locations are deduplicated; names with spaces, Chinese, emoji, and special characters work.
- [ ] Thumbnails fall back to icons; unavailable items and recovery, long names, empty state, and errors are understandable.
- [ ] Selection, select all, Shift sweep, double-click, list expansion, keyboard and accessibility behavior work in light and dark modes and at scale.
- [ ] Transfer succeeds to Finder and another app; cancellation and failed writes preserve the source and item. Deletion failures and partial successes are reported per item, including possible destination copies.
- [ ] Manual removal and session cleanup preserve sources; startup and explicit hiding clear references without restoring old items. Check shake and empty-window timeout behavior.
- [ ] Moving, renaming, deleting, or changing permissions on a source produces understandable status and recovery. Validate atomic saves, concurrent saves, versions, and corrupt data handling.
- [ ] Latest build, unit and UI test results are recorded; UI runner failure and concurrency warnings are resolved or understood.
- [ ] Signing, notarization, sandbox permissions, clean installation, documentation, privacy, and known limitations are checked.

## Optional and unresolved

Window-position restoration, reordering, multiple shelves, search, grouping, context actions, and launch at login are optional. Confirm intended behavior before treating outside-click hiding, the old edge drop zone, or cross-Spaces Peek/Expand as requirements.

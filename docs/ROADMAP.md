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
- At that point the working tree included panel diagnostic logging and a changed window level; see the later reliability update for cleanup.

### Reliability update: 2026-11-07

- A fresh signed build and 40 unit tests passed; the earlier persistence actor-isolation warnings did not appear. Four UI tests passed after diagnostic cleanup.
- The user reported manually testing the UI and functionality successfully before this cleanup. The removed window-drag UI test does not cover the cleaned version; recheck movement and real file transfer when preparing the release candidate.
- Temporary pointer and window-stack logging was removed. The previously tested window level and first-mouse behavior remain in place.

### File warning update: 2026-11-07

- Compact and expanded file icons now show the same warning badge for unavailable files or opening failures, with localized hover text and accessibility help. Double-clicking refreshes the bookmark before opening; launch errors stay with the item instead of appearing as transfer errors. Successful opening clears the session-only launch error.
- A signed build and 44 unit tests passed, including same-volume move/rename before opening, deleted sources, per-item launch failures, retry, and exclusion of launch errors from persisted data. The old `/private/tmp/ShelfWorkflowDD` test runner could not be linked; the test run succeeded in a fresh `/private/tmp/ShelfFileWarningsDD` directory.
- The user reported the prior transfer acceptance had no issues and other manual checks were generally successful. A Finder-only source-move issue could not be reproduced on retry; the cause is unconfirmed. Keep it under observation rather than treating it as a diagnosed Finder defect.
- The four existing UI tests passed in the full run. After correcting the new tests to hover the target row before clicking (avoiding the previous row's long tooltip during synthetic hit testing), both new light/dark warning tests passed in a targeted run. Compact/expanded screenshots were inspected in both appearances; warning reasons and selection are visible. The final signed build passed. Commands used `xcodebuild -quiet build` and `test` with the README's project/scheme/destination, `/private/tmp/ShelfFileWarningsDD`, and normal signing; test selections were `ShelfTests`, `ShelfUITests`, then `ShelfUITests/ShelfUITests/testFileWarningsInDarkAppearance` and `ShelfUITests/ShelfUITests/testFileWarningsInLightAppearance`.
- The user confirmed manual acceptance of permission-loss behavior and desktop drag-and-drop with warning badges, and accepted that Shelf can still open a source after it is moved by resolving its bookmark to the new location.
- VoiceOver speech is unverified and explicitly deferred by the user; do not record it as passed or schedule it as an immediate acceptance task.

## Active development

1. Recheck window movement and representative file transfers on the cleaned release candidate; review remaining release configuration and repeat relevant tests after changes.
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

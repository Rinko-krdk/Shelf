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

### Preview packaging update: 2026-11-07

- Committed the accepted per-file warning changes as `9c13bfd` (`Improve per-file opening warnings and refresh moved references`). No push or public release has been performed.
- `bash -n scripts/package-preview.sh` passed. An unsigned arm64 Release build passed; the full packaging script then passed outside the execution sandbox after SwiftUI compiler macros were blocked inside it.
- Generated `dist/Shelf-1.0-preview.1-arm64.zip` and its checksum. Extracting the ZIP with `ditto`, checking the extracted app with `codesign --verify --deep --strict`, inspecting `lipo -archs`, and checking the checksum all passed. Embedded entitlements include App Sandbox and user-selected file read/write; signature flags are ad-hoc and Hardened Runtime. Minimum system is macOS 15.0. These are artifact checks, not installation or runtime acceptance.
- ZIP SHA-256: `75ac36f25d4e50b5ef86b110629881a758bea25a0e7b45cb17478b9d815fe4e5`. `BUILD.txt` identifies source commit `9c13bfd` and the uncommitted packaging work. Regenerate from reviewed, committed preparation files before public upload; the checksum will change.
- Added packaging instructions, bilingual bundled usage/privacy/limitations, and draft GitHub pre-release notes. New packaging changes remain in the working tree for review. Installed/downloaded preview acceptance, the app icon, and licensing decisions remain outstanding; no new unit/UI test run was needed for these script/documentation-only changes.

### Preview 2 icon update: 2026-11-07

- Added the user's `Glossy Glass Document Tray.png` artwork to all ten macOS AppIcon entries, preserving the supplied artwork. Pixel dimensions were checked against every catalog entry. App build number is now 2; packaging and current release instructions identify `preview.2`.
- `bash scripts/package-preview.sh` passed, producing `dist/Shelf-1.0-preview.2-arm64.zip` and its checksum. After extraction, signature verification and arm64 checks passed; `Info.plist` references AppIcon and build 2, and `AppIcon.icns` plus `Assets.car` are present. No runtime code changed, so unit/UI suites were not repeated for this icon update.
- Preview 2 SHA-256: `d93ed687a94fafa0ae2b5815b41a174e060d5ac785a48ecd391ed84bd59c420b`. This is the current local acceptance candidate; Preview 1 above is historical. Installed icon appearance and packaged-app runtime/download acceptance remain manual and unverified. The package records the uncommitted preparation/icon work; regenerate from committed reviewed files before public upload.

### Preview 2 manual acceptance: 2026-11-07

- The user confirmed that the supplied Preview 2 checklist passed without issues: local installation and icon appearance, launch outside Xcode, menu/shortcut/settings access, source relocation and opening, drag-out/cancellation, session cleanup, and settings persistence.
- Acceptance applies to the existing `dist/Shelf-1.0-preview.2-arm64.zip`, SHA-256 `d93ed687a94fafa0ae2b5815b41a174e060d5ac785a48ecd391ed84bd59c420b`; its checksum was rechecked successfully. The archive was not rebuilt or changed after this report.
- Browser-download quarantine/first-launch behavior, other machines, and preview-to-preview upgrades are not established by this local checklist. VoiceOver remains deferred. Publication and a new Git commit are not authorized by this acceptance report.

### Preview 3 settings update: 2026-11-07

- Added grouped General/Language/Shortcut/About settings: native Launch at Login, a persistent mouse-shake toggle (default enabled), bundle-derived version/build and `© 2026 Rinko`, and a GitHub Issues feedback link. Both settings entry points share the same services. Version remains 1.0; app build is 3.
- Login startup reads `SMAppService.mainApp` status, registers only on user request, supports cancellation while approval is pending, refreshes on settings display/app activation, and reports errors inline after re-reading system status. All automated registration tests use substitute clients and do not modify real login items.
- Shake preference changes install/remove the event monitor immediately. Generation checks reject callbacks queued before disabling/replacing it. Tests cover this behavior, preference persistence, registration lifecycle, pending/denied approval, errors, unavailable services, and overlapping requests.
- The final full run passed **53 unit tests and all 10 UI tests** with normal signing: `xcodebuild -quiet test -project Shelf.xcodeproj -scheme Shelf -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/ShelfSettingsDD -only-testing:ShelfTests -only-testing:ShelfUITests`. English/light and Chinese/dark settings, scrolling, shortcut recording/cancellation, copyright/version, preference relaunch persistence, and login status/error UI were exercised. Screenshots of English/light and Chinese/dark About were inspected; the pending-approval layout was also inspected during diagnosis.
- UI checks initially needed numeric switch-value handling; they also found that native LabeledContent kept stale accessibility version text after switching language. Recreating that row on language changes fixed the issue; the targeted test and final complete run passed.
- The final `bash scripts/package-preview.sh` Release build/package passed. Extraction, strict signature verification, embedded sandbox/read-write entitlements, arm64 architecture, build/copyright metadata, and checksum checks passed. Current ZIP: `dist/Shelf-1.0-preview.3-arm64.zip`, SHA-256 `4700d684d0bdf9b1ff3f025528bac652c6bf14b0938bdec8a7fc400916b3b3ac`. An earlier unaccepted Preview 3 candidate is kept under `dist/preview3-before-accessibility-fix/`; use the ZIP at the dist root. Preview 2's accepted ZIP/checksum is unchanged and was rechecked.
- Installed Preview 3 shake behavior, actual native login registration with ad-hoc signing, system-setting synchronization, and logout/login launch/disable behavior require manual acceptance. Disable macOS's separate “Reopen windows when logging back in” during login tests. Browser-download first launch and upgrades remain unverified; VoiceOver stays deferred. No commit, push, or upload was performed.

### Login item not-found investigation: 2026-11-07

- The user reported `notFound` even after installing Shelf into `/Applications`; the installed bundle was present and ad-hoc signed. `notFound` does not establish why macOS could not find the service, and the prior text incorrectly attributed it to installation location.
- Allow an explicit registration attempt from `notFound` and show the resulting system error if registration fails. Nine settings unit tests and the targeted missing-login-item UI test passed using test clients; no real login item was registered by automation.
- The user reported that the diagnostic candidate resolved the login-item issue. The current candidate is `dist/login-fix/Shelf-1.0-preview.3-arm64.zip`, SHA-256 `11221f5f24142a29f4f70046f91e46f04c34559e9e5cce4595fd0fd57f8c659e`; its checksum was rechecked. The report does not establish logout/login behavior, browser-downloaded first launch, or the cause of the earlier system status.

## Active development

The user selected GitHub Releases, an unnotarized test preview first (free Apple account), and Apple Silicon only. See [release preparation](RELEASE.md) for packaging and draft release notes. The AppIcon catalog now uses the user-supplied document-tray image at all ten macOS size/scale entries.

1. Preserve the latest `dist/login-fix/` candidate and checksum. Check launch after logout/login and after disabling login startup using [release preparation](RELEASE.md); the user reported the earlier registration issue resolved.
2. Review usage, privacy, limitations, and source licensing. Plan browser-downloaded first-launch acceptance before promoting a release; cross-machine and preview-upgrade behavior remain unverified.
3. Review and commit the settings/icon/packaging work when authorized. After explicit publication approval, push the chosen commit(s), create a GitHub **Pre-release**, and upload the tested Apple Silicon ZIP and checksum. Developer ID signing/notarization is deferred until a paid account is available.
4. Preserve any unverified edge cases in the acceptance matrix below. VoiceOver speech is deferred by user choice; Intel support is out of scope for the first preview.

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

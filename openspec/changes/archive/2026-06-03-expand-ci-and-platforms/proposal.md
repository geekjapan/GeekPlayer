## Why

v0.2 adds Linux as a supported platform and introduces books and manga. Before adding those features, the CI matrix must cover Linux builds so regressions are caught at PR time. The current matrix covers analyze/test, Android debug, and Windows release — macOS and Linux build smoke tests are absent. Any Linux-specific compilation failure (GTK, libmpv, CMake) would go undetected until a manual release attempt. This change closes that gap and verifies that `app/linux/` is build-ready.

## What Changes

- Add a `build-macos` CI job (macOS runner) that runs `flutter build macos --release --dart-define=GIT_SHA=...`.
- Add a `build-linux` CI job (Ubuntu runner) that installs `libmpv-dev`, `ninja-build`, and `libgtk-3-dev`, then runs `flutter build linux --release --dart-define=GIT_SHA=...`.
- Verify `app/linux/` CMake scaffolding exists and is build-ready (it already exists; confirm it needs no changes for the CI job to succeed).
- Update `docs/release.md` with the Linux manual build command.

## Non-goals

- No iOS/iPadOS CI job (blocked by ADR-0006 and Xcode licensing constraints).
- No release packaging or artifact upload for Linux or macOS in this change (packaging is a separate concern).
- No changes to `app/linux/CMakeLists.txt` beyond what is already present.
- No feature code, ARBs, or pubspec dependency changes.
- No drift schema changes.
- No changes to `app/lib/core/storage/`.

## Capabilities

### New Capabilities

- `ci-build-matrix`: Defines CI job coverage per platform (analyze/test, Android debug, Windows release, macOS release smoke, Linux release smoke) and the system dependencies required for each.
- `linux-platform-support`: Defines the Linux build configuration entry criteria, system package dependencies (libmpv-dev, ninja-build, libgtk-3-dev), and the `app/linux/` CMake scaffolding contract.

### Modified Capabilities

None.

## Impact

- CI: `.github/workflows/ci.yaml` — adds `build-macos` and `build-linux` jobs.
- Docs: `docs/release.md` — adds Linux build command.
- OpenSpec: new `openspec/specs/ci-build-matrix/spec.md` and `openspec/specs/linux-platform-support/spec.md` after archive.
- Verification: `openspec validate expand-ci-and-platforms --strict`, YAML parse, `git diff --check`.

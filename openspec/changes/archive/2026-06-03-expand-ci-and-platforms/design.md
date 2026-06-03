## Context

GeekPlayer CI currently runs three jobs: `analyze-and-test` (Ubuntu), `build-android-debug` (Ubuntu), and `build-windows-release` (Windows). macOS and Linux release smoke tests are absent. v0.2 targets Linux as a first-class platform (alongside macOS and Windows), and the media engine (libmpv via media_kit) has Linux-specific native dependencies that must be satisfied at build time. This change adds the missing CI jobs and documents the Linux manual build flow.

## Goals / Non-Goals

**Goals:**

- Add `build-macos` job using `macos-latest` runner; build smoke confirms the macOS toolchain and entitlements are intact.
- Add `build-linux` job using `ubuntu-latest` runner; job installs `libmpv-dev`, `ninja-build`, `libgtk-3-dev` via apt, then builds a release binary.
- Confirm `app/linux/` CMake scaffolding is already present (it is — generated during initial Linux platform add) and requires no structural change.
- Update `docs/release.md` with the Linux `flutter build linux` command.
- Pass `openspec validate expand-ci-and-platforms --strict`.

**Non-Goals:**

- No iOS/iPadOS CI (ADR-0006 deferred; Xcode license not available on free GitHub runners without additional configuration).
- No Linux artifact packaging or upload in this change.
- No macOS artifact packaging in this change (macOS dmg is already handled by the separate `release-artifacts.yaml` workflow).
- No feature code changes.

## Decisions

### D1. Use `macos-latest` runner for macOS build smoke

`macos-latest` currently maps to `macos-14` (Apple Silicon) on GitHub Actions. Using it gives the same architecture as the target machine for release builds. The build step mirrors the existing Windows pattern: `flutter build macos --release --dart-define=GIT_SHA=${{ github.sha }}`.

### D2. Use `ubuntu-latest` for Linux build, not a custom container

A plain Ubuntu runner is sufficient. The required native libraries (`libmpv-dev`, `ninja-build`, `libgtk-3-dev`) are available in the default apt repositories for Ubuntu 22.04/24.04. A custom container would add maintenance burden without meaningful benefit.

### D3. Install `libmpv-dev` as the primary media_kit Linux dependency

media_kit (ADR-0002) requires libmpv at link time on Linux. The package `libmpv-dev` provides both headers and the shared library. At runtime, the deployed bundle is expected to ship `libmpv.so`; the CI build smoke confirms compilation only, not runtime playback. `libmpv` (runtime) is also available from the same apt source if needed for future integration tests.

### D4. Pass `GIT_SHA` via `${{ github.sha }}` in CI

Consistent with the existing About screen `GIT_SHA` requirement (see `docs/release.md`). Using `${{ github.sha }}` (the full SHA) is safe; the About screen accepts any non-empty string. Manual builds should continue to use `$(git rev-parse --short HEAD)` as documented.

### D5. No artifact upload for macOS or Linux in this change

The build smoke jobs confirm compilation succeeds. Artifact packaging and upload (e.g., macOS dmg, Linux tarball) are deferred to a separate packaging change. Adding artifact steps now would conflate build smoke with distribution concerns.

## Risks / Trade-offs

- [Risk] `macos-latest` runner availability is slower on GitHub-hosted runners -> Mitigation: accepted; macOS build jobs are commonly slower. No SLA requirement here.
- [Risk] `libmpv-dev` version on ubuntu-latest may differ from the target user's installed version -> Mitigation: CI confirms compilation; runtime compatibility is a deployment concern outside this change's scope.
- [Risk] flutter-action cache may not work correctly on macOS runners -> Mitigation: `cache: true` is the same setting used for other jobs; if caching fails, the job will still succeed (just slower).

## Migration Plan

1. Author OpenSpec artifacts (this change).
2. Add `build-macos` and `build-linux` jobs to `.github/workflows/ci.yaml`.
3. Update `docs/release.md` with Linux build command.
4. Run verification (YAML parse, openspec validate, git diff --check).
5. Commit and report.

Rollback is a git revert of `.github/workflows/ci.yaml` and `docs/release.md`; no app data or runtime state is affected.

## Open Questions

None. All decisions are made above.

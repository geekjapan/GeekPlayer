## Context

GeekPlayer v0.2 adds iOS / iPadOS as a distribution platform. The iOS scaffolding under `app/ios/` was created by `flutter create` but not yet configured for this project. ADR-0006 (accepted 2026-06-03) resolved three blocking questions before implementation could begin:

1. **Media engine**: Option A (libmpv/media_kit) as first choice; fallback to Option B (platform-specific engine) only if spike proves libmpv unviable.
2. **Distribution**: Non-App-Store (Ad Hoc / Apple Developer direct signing); App Store explicitly not pursued.
3. **LGPL compliance**: Dynamic link + per-platform re-link instructions in THIRD_PARTY_NOTICES and in-app LGPL notice section.

This change implements the iOS configuration, runs a dependency spike, and extends LGPL notices. The `lgpl-compliance` capability's iOS ADR precondition (see `openspec/specs/lgpl-compliance/spec.md`) is satisfied by ADR-0006.

## Goals / Non-Goals

**Goals:**

- Configure `app/ios/` correctly: bundle ID `dev.geekjapan.geekplayer`, display name "GeekPlayer", deployment target iOS 13.0, device family "1,2" (iPhone + iPad), Podfile `platform :ios, '13.0'`, Info.plist usage descriptions.
- Run a real `flutter build ios --release --no-codesign` spike and document the outcome.
- Extend LGPL per-platform replacement instructions to include iOS (THIRD_PARTY_NOTICES + in-app l10n strings).
- If spike passes: add `build-ios` CI job. If spike fails: document root cause and defer CI job.

**Non-Goals:**

- App Store distribution (ADR-0006 explicitly excludes this).
- AVPlayer / video_player engine replacement (ADR-0006 Option B; deferred unless libmpv fails permanently).
- TestFlight / Enterprise distribution setup.
- iPadOS-specific Stage Manager / multi-window support.
- Media_kit iOS SPM migration (upstream issue; not in scope).

## Decisions

### (a) Media Engine: ADR-0006 Option A — libmpv/media_kit continued

libmpv via `media_kit_libs_ios_video` is the first choice per ADR-0006. The spike confirmed that `media_kit_libs_ios_video` ships a pre-built libmpv XCFramework and is available as a CocoaPods dependency. The build failure (see Spike Result below) is an Xcode / Swift Package Manager resolution issue, not a libmpv binary availability problem. Therefore Option A remains the engine choice; the CI deferral is technical, not a signal to abandon libmpv.

If `media_kit_libs_ios_video` gains Swift Package Manager support in a future release, the CI job can be added at that point without engine changes.

### (b) Distribution Channel: Non-App-Store (Ad Hoc / developer direct)

Per ADR-0006 §Decision 2: App Store distribution is not pursued. iOS builds will be distributed as Ad Hoc or via direct Apple Developer signing (the same OSS/GitHub-Releases-direct model as macOS/Windows). This is reflected in the LGPL notices (re-sign instructions note Ad Hoc / developer signing).

### (c) LGPL Compliance: Dynamic link + iOS re-link instructions

Per ADR-0006 §Decision 3: libmpv is dynamically linked on iOS (XCFramework shipped inside the `.app` bundle under `Frameworks/`). Re-link instructions are added to:
- `THIRD_PARTY_NOTICES.md` — per-platform table now includes iOS row with `Frameworks/` path and re-sign note.
- `app/lib/l10n/app_ja.arb` and `app_en.arb` — `lgplNoticeReplacementBody` extended with iOS entry.
- These propagate to the in-app LGPL notice section via `LgplNoticeSection` (no code change needed; the widget already renders `lgplNoticeReplacementBody`).

### Podfile structure

A CocoaPods Podfile is required for `media_kit_video` and `media_kit_libs_ios_video` because those plugins do not yet support Swift Package Manager. The Podfile uses the standard Flutter template with `platform :ios, '13.0'` and `use_frameworks!` / `use_modular_headers!` as required by media_kit.

### Info.plist usage descriptions

Three keys are added for document picker / local media file access:
- `NSDocumentsFolderUsageDescription` — required by iOS for access to the Documents folder.
- `UIFileSharingEnabled` — enables iTunes/Finder file sharing.
- `LSSupportsOpeningDocumentsInPlace` — allows Files.app to open documents in place.

No `NSPhotoLibraryUsageDescription` or camera/microphone keys are needed (GeekPlayer does not use those APIs on iOS).

## Dependency Spike Result

**Date**: 2026-06-03  
**Command**: `fvm flutter build ios --release --no-codesign --dart-define=GIT_SHA=spike` (from `app/`)  
**Outcome**: FAILED  
**Exit code**: 1

**Root cause**:
```
Xcode failed to resolve Swift Package Manager dependencies
```

**Analysis**: Lines 41–44 of the build output warn:
```
The following plugins do not support Swift Package Manager for ios:
  - media_kit_video
  - media_kit_libs_ios_video
```
Flutter 3.44.0 uses SPM as the default plugin resolution mechanism on Apple platforms. When plugins lack SPM support, Flutter falls back to CocoaPods, but Xcode 16.x attempts SPM resolution before CocoaPods, causing a resolution failure. This is a known upstream issue in the media_kit ecosystem as of 2026-06-03; it is not a libmpv binary problem.

**Consequence**:
- `build-ios` CI job is NOT added (per task instructions: do not add a failing job).
- The deferral reason in `openspec/specs/ci-build-matrix/spec.md` delta is updated from "ADR-0006 not resolved" to "media_kit SPM incompatibility".
- When `media_kit_video` / `media_kit_libs_ios_video` add SPM support (or a CocoaPods-only workaround is confirmed), the CI job can be added without changes to this change's iOS configuration work.

## Risks / Trade-offs

- **[Risk] media_kit SPM support timeline unknown** → Mitigation: monitor upstream `media-kit/media-kit` repository; SPM support is a known roadmap item. CI job can be added as a follow-up change once resolved.
- **[Risk] Xcode version drift on CI** → Mitigation: CI currently uses `macos-latest`; when a `build-ios` job is eventually added, pin `xcode-version` explicitly.
- **[Risk] Ad Hoc distribution reach is limited** → ADR-0006 acknowledged this; mitigation is EU alternative marketplace / sideloading when it matures.
- **[Trade-off] iOS l10n replacement body is longer** → Accepted; the string is prose, not a UI element with layout constraints.

## Open Questions

- When will `media_kit_video` / `media_kit_libs_ios_video` add Swift Package Manager support? Tracked upstream at https://github.com/media-kit/media-kit/issues.
- Should the `build-ios` CI job be added as a separate follow-up change (`fix-ios-ci`) once SPM support lands, or inline in a patch to this change?

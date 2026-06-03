## Why

GeekPlayer v0.2 targets iOS / iPadOS as a new distribution platform. ADR-0006 (accepted 2026-06-03) resolved the three blocking questions — media engine choice, distribution channel, and LGPL compliance — enabling implementation to begin. The `lgpl-compliance` capability's `Requirement: iOS and iPadOS platform work requires a media-engine distribution ADR` is now satisfied.

## What Changes

- `app/ios/` configuration: bundle ID `dev.geekjapan.geekplayer`, display name "GeekPlayer", deployment target iOS 13.0, TARGETED_DEVICE_FAMILY = "1,2" (iPhone + iPad), Info.plist usage description strings for document picker / local media access.
- `app/ios/Podfile`: set `platform :ios, '13.0'` to match media_kit's minimum requirement.
- Dependency spike: `flutter build ios --release --no-codesign` executed to confirm libmpv/media_kit builds on iOS (ADR-0006 Option A first).
- If spike succeeds: `build-ios` CI job added to `.github/workflows/ci.yaml`.
- `THIRD_PARTY_NOTICES.md`: iOS per-platform libmpv replacement instructions added (framework location in `.app` bundle, dynamic-link, re-sign note).
- `app/lib/features/about/presentation/lgpl_notice_section.dart`: iOS replacement path added to per-platform instructions section.
- Delta spec for `lgpl-compliance` (MODIFIED): adds iOS platform replacement path requirement.
- Delta spec for `ci-build-matrix` (MODIFIED): replaces "no iOS CI job until ADR-0006" requirement with the new `build-ios` job requirement (if spike passes) or documents deferral reason (if spike fails).
- New capability spec `ios-platform-support` documenting the iOS configuration requirements.

## Non-goals

- App Store distribution (explicitly excluded by ADR-0006).
- Switching media engine to AVPlayer / video_player for iOS (ADR-0006 Option B; only used as fallback if spike fails).
- iPadOS-specific multi-window or Stage Manager support.
- TestFlight / Enterprise distribution setup.
- Any change to `app/android/`, `app/macos/`, `app/linux/`, `app/windows/`.

## Capabilities

### New Capabilities

- `ios-platform-support`: iOS / iPadOS build configuration — bundle ID, deployment target, device family, Podfile platform pin, Info.plist usage strings, and ADR-0006 compliance evidence.

### Modified Capabilities

- `lgpl-compliance`: adds iOS platform to the per-platform libmpv replacement instructions requirement (currently covers macOS, Windows, Android).
- `ci-build-matrix`: replaces the "no iOS CI job until ADR-0006" deferral with an actual `build-ios` job (or documents spike failure and retains deferral with updated rationale).

## Impact

- `app/ios/Runner/Info.plist` — display name correction, usage description keys added (`NSDocumentsFolderUsageDescription`, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`).
- `app/ios/Podfile` — `platform :ios, '13.0'` line added.
- `app/ios/Runner.xcodeproj/project.pbxproj` — TARGETED_DEVICE_FAMILY and deployment target (already set correctly per grep; confirmed no change needed).
- `THIRD_PARTY_NOTICES.md` — new iOS section under libmpv LGPL notice.
- `app/lib/features/about/presentation/lgpl_notice_section.dart` — iOS path added to replacement body (or via l10n strings).
- `.github/workflows/ci.yaml` — `build-ios` job added if spike succeeds.
- `openspec/specs/lgpl-compliance/spec.md` — NOT modified directly; delta spec in `openspec/changes/add-platform-ios/specs/lgpl-compliance/spec.md`.
- `openspec/specs/ci-build-matrix/spec.md` — NOT modified directly; delta spec in `openspec/changes/add-platform-ios/specs/ci-build-matrix/spec.md`.
- Related ADR: `docs/adr/0006-ios-media-engine-distribution-policy.md` (accepted; no modification).

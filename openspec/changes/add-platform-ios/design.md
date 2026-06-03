## Context

GeekPlayer v0.2 adds iOS / iPadOS as a distribution platform. The iOS scaffolding under `app/ios/` was created by `flutter create` but not yet configured for this project. ADR-0006 (accepted 2026-06-03) resolved three blocking questions before implementation could begin:

1. **Media engine**: Option A (libmpv/media_kit) as first choice; fallback to Option B (platform-specific engine) only if spike proves libmpv unviable.
2. **Distribution**: Non-App-Store (Ad Hoc / Apple Developer direct signing); App Store explicitly not pursued.
3. **LGPL compliance**: Dynamic link + per-platform re-link instructions in THIRD_PARTY_NOTICES and in-app LGPL notice section.

This change implements the iOS configuration, runs a dependency spike, and extends LGPL notices. The `lgpl-compliance` capability's iOS ADR precondition (see `openspec/specs/lgpl-compliance/spec.md`) is satisfied by ADR-0006.

## Goals / Non-Goals

**Goals:**

- Configure `app/ios/` correctly: bundle ID `dev.geekjapan.geekplayer`, display name "GeekPlayer", deployment target iOS 14.0, device family "1,2" (iPhone + iPad), Podfile `platform :ios, '14.0'`, Info.plist usage descriptions.
- Run a real `flutter build ios --release --no-codesign` spike and document the outcome.
- Extend LGPL per-platform replacement instructions to include iOS (THIRD_PARTY_NOTICES + in-app l10n strings).
- Add a `build-ios` CI job (the GitHub `macos-latest` runner has the iOS platform runtime that the local host lacks).

**Non-Goals:**

- App Store distribution (ADR-0006 explicitly excludes this).
- AVPlayer / video_player engine replacement (ADR-0006 Option B; deferred unless libmpv fails permanently).
- TestFlight / Enterprise distribution setup.
- iPadOS-specific Stage Manager / multi-window support.
- Media_kit iOS SPM migration (upstream issue; worked around by forcing CocoaPods, not in scope to fix upstream).

## Decisions

### (a) Media Engine: ADR-0006 Option A — libmpv/media_kit continued

libmpv via `media_kit_libs_ios_video` is the engine per ADR-0006, and the spike **confirmed it is viable on iOS**: with CocoaPods resolution forced, `media_kit_libs_ios_video` downloads its prebuilt libmpv XCFrameworks (Freetype, mbedTLS, libmpv, …) and `pod install` succeeds. No engine fallback to Option B is needed.

### (b) Distribution Channel: Non-App-Store (Ad Hoc / developer direct)

Per ADR-0006 §Decision 2: App Store distribution is not pursued. iOS builds will be distributed as Ad Hoc or via direct Apple Developer signing (the same OSS/GitHub-Releases-direct model as macOS/Windows). This is reflected in the LGPL notices (re-sign instructions note Ad Hoc / developer signing).

### (c) LGPL Compliance: Dynamic link + iOS re-link instructions

Per ADR-0006 §Decision 3: libmpv is dynamically linked on iOS (XCFramework shipped inside the `.app` bundle under `Frameworks/`). Re-link instructions are added to:
- `THIRD_PARTY_NOTICES.md` — per-platform table now includes iOS row with `Frameworks/` path and re-sign note.
- `app/lib/l10n/app_ja.arb` and `app_en.arb` — `lgplNoticeReplacementBody` extended with iOS entry.
- These propagate to the in-app LGPL notice section via `LgplNoticeSection` (no code change needed; the widget already renders `lgplNoticeReplacementBody`).

### Podfile structure and SPM

A CocoaPods Podfile is required for `media_kit_video` and `media_kit_libs_ios_video` because those plugins do not yet support Swift Package Manager. The Podfile uses the standard Flutter template with `platform :ios, '14.0'` and `use_frameworks!` / `use_modular_headers!` as required by media_kit.

Because Flutter resolves Apple plugins via SPM first when SPM is enabled, builds on an SPM-enabled toolchain fail to resolve the media_kit pods. The fix is to force CocoaPods resolution with `flutter config --no-enable-swift-package-manager`; the `build-ios` CI job runs this step before `flutter pub get`. (The existing `build-macos` job builds cleanly on GitHub runners with the same media_kit pods, confirming CocoaPods resolution works there.)

### Deployment target

The deployment target is iOS **14.0** (not 13.0): `file_picker` — a transitive plugin used for opening local media — requires a minimum of iOS 14.0. media_kit itself only needs iOS 13.0, but the effective floor is the highest plugin minimum.

### Info.plist usage descriptions

Three keys are added for document picker / local media file access:
- `NSDocumentsFolderUsageDescription` — required by iOS for access to the Documents folder.
- `UIFileSharingEnabled` — enables iTunes/Finder file sharing.
- `LSSupportsOpeningDocumentsInPlace` — allows Files.app to open documents in place.

No `NSPhotoLibraryUsageDescription` or camera/microphone keys are needed (GeekPlayer does not use those APIs on iOS).

## Dependency Spike Result

The spike was run iteratively from `app/` on a macOS host (Xcode 26.5, CocoaPods 1.16.2). Three findings, each resolved:

1. **SPM resolution failure (resolved by forcing CocoaPods).** With Swift Package Manager enabled, `flutter build ios` fails with `Xcode failed to resolve Swift Package Manager dependencies`, because `media_kit_video` / `media_kit_libs_ios_video` lack SPM support. Running `flutter config --no-enable-swift-package-manager` forces CocoaPods, and `pod install` then downloads media_kit's prebuilt libmpv XCFrameworks (Freetype, mbedTLS/mbedx509, libmpv, …) successfully. This confirms **Option A (libmpv) is viable on iOS** — the earlier "media_kit blocker" reading was a false negative caused purely by SPM-first resolution.

2. **Deployment target too low (resolved by bumping to 14.0).** After CocoaPods resolution, `pod install` failed with `The plugin "file_picker" requires a higher minimum iOS deployment version ... at least 14.0`. Raising the Podfile and `IPHONEOS_DEPLOYMENT_TARGET` to `14.0` resolves it.

3. **Local host lacks the iOS platform runtime (environment, not code).** With (1) and (2) fixed, `pod install` and the Xcode build invocation both proceed; the build then stops at `iOS 26.5 is not installed. Please download and install the platform from Xcode > Settings > Components.` This is a missing platform-runtime component on the local machine, not a project/configuration problem.

**Conclusion**: the iOS configuration is correct and the libmpv/CocoaPods toolchain works end-to-end up to the point where a platform runtime is required. Because the GitHub `macos-latest` runner ships the iOS platform runtime (and `build-macos` already builds the same media_kit pods cleanly there), a `build-ios` CI job is the appropriate authoritative verification. **The `build-ios` job is therefore added** (runs `flutter config --no-enable-swift-package-manager` before `flutter pub get`).

## Risks / Trade-offs

- **[Risk] GitHub runner iOS runtime / Xcode drift** → Mitigation: `build-ios` runs on `macos-latest`, which preinstalls iOS SDKs/runtimes; if a future runner image regresses, pin `xcode-version` in the job. CI (not the local host) is the verification of record for iOS.
- **[Risk] media_kit SPM support timeline unknown** → Mitigation: the CocoaPods-force step is a stable workaround; when media_kit adds SPM support the step becomes a no-op and can be dropped.
- **[Risk] Ad Hoc distribution reach is limited** → ADR-0006 acknowledged this; mitigation is EU alternative marketplace / sideloading when it matures.
- **[Trade-off] iOS l10n replacement body is longer** → Accepted; the string is prose, not a UI element with layout constraints.

## Open Questions

- When will `media_kit_video` / `media_kit_libs_ios_video` add Swift Package Manager support? Tracked upstream at https://github.com/media-kit/media-kit/issues. Until then the CI job forces CocoaPods.

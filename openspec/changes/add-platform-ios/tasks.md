## 1. OpenSpec Scaffolding

- [x] 1.1 Run `openspec new change "add-platform-ios"` and confirm directory created
- [x] 1.2 Author `openspec/changes/add-platform-ios/proposal.md`
- [x] 1.3 Create delta spec `openspec/changes/add-platform-ios/specs/ios-platform-support/spec.md`
- [x] 1.4 Create delta spec `openspec/changes/add-platform-ios/specs/lgpl-compliance/spec.md`
- [x] 1.5 Create delta spec `openspec/changes/add-platform-ios/specs/ci-build-matrix/spec.md` (content depends on spike result)
- [x] 1.6 Author `openspec/changes/add-platform-ios/design.md` (content includes spike outcome)
- [x] 1.7 Validate with `openspec validate add-platform-ios --strict` — PASSED

## 2. iOS Configuration

- [x] 2.1 Create `app/ios/Podfile` with `platform :ios, '13.0'`
- [x] 2.2 Fix `CFBundleDisplayName` in `app/ios/Runner/Info.plist` to `GeekPlayer`
- [x] 2.3 Add `NSDocumentsFolderUsageDescription`, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace` to `app/ios/Runner/Info.plist`
- [x] 2.4 Confirm `PRODUCT_BUNDLE_IDENTIFIER = dev.geekjapan.geekplayer` in `project.pbxproj` (already verified: correct)
- [x] 2.5 Confirm `IPHONEOS_DEPLOYMENT_TARGET = 13.0` in `project.pbxproj` (already verified: correct)
- [x] 2.6 Confirm `TARGETED_DEVICE_FAMILY = "1,2"` in `project.pbxproj` (already verified: correct)

## 3. Dependency Spike

- [x] 3.1 Run `flutter build ios --release --no-codesign` from `app/` and record exact outcome
- [x] 3.2 If SUCCESS: add `build-ios` job to `.github/workflows/ci.yaml` (N/A — spike failed)
- [x] 3.3 If FAIL: document root cause in `design.md`; do NOT add failing CI job (DONE — SPM incompatibility documented)

## 4. LGPL / Notices

- [x] 4.1 Add iOS per-platform libmpv replacement instructions to `THIRD_PARTY_NOTICES.md`
- [x] 4.2 Update l10n string for `lgplNoticeReplacementBody` in `app_ja.arb` and `app_en.arb` to include iOS platform entry

## 5. Verification

- [x] 5.1 Run `dart run build_runner build --delete-conflicting-outputs` from `app/` — 675 outputs built, 0 errors
- [x] 5.2 Run `dart format --output=none --set-exit-if-changed .` from `app/` — 0 changed, 348 files formatted
- [x] 5.3 Run `flutter analyze --fatal-infos` from `app/` — No issues found
- [x] 5.4 Run `flutter test` from `app/` — 526 tests passed

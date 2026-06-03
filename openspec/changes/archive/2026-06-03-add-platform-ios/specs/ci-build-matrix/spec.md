# ci-build-matrix Delta Specification (add-platform-ios)

ADR-0006 is accepted and the iOS dependency spike confirmed libmpv/media_kit builds via CocoaPods, so the prior "no iOS CI job" stance is removed and a `build-ios` smoke job is added.

## REMOVED Requirements

### Requirement: no iOS CI job is defined until ADR-0006 is implemented

## ADDED Requirements

### Requirement: build-ios job performs an iOS release build smoke

A `build-ios` job MUST run on `macos-latest`, force CocoaPods plugin resolution via `flutter config --no-enable-swift-package-manager` (because `media_kit_libs_ios_video` lacks Swift Package Manager support), and execute `flutter build ios --release --no-codesign --dart-define=GIT_SHA=${{ github.sha }}` as a compilation smoke test. The job MUST run `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs` before the build.

#### Scenario: iOS release build smoke passes

- **WHEN** the `build-ios` job disables SPM, resolves CocoaPods, and runs `flutter build ios --release --no-codesign`
- **THEN** the libmpv pods resolve and the build exits with code 0

#### Scenario: SPM is forced off before resolution

- **GIVEN** the `build-ios` job definition
- **WHEN** its steps are read
- **THEN** `flutter config --no-enable-swift-package-manager` runs before `flutter pub get`

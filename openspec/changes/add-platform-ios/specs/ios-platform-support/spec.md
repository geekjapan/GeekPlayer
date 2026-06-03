# ios-platform-support Specification

## Purpose

Establishes the committed `app/ios/` configuration and CocoaPods scaffolding required to build GeekPlayer for iOS / iPadOS via `flutter build ios`, including bundle identifier, display name, deployment target, device family, Info.plist usage description strings, and ADR-0006 compliance evidence.

## ADDED Requirements

### Requirement: app/ios/ configuration is present and complete

The `app/ios/` directory MUST contain a valid Flutter iOS scaffolding (`Runner.xcodeproj/`, `Runner/Info.plist`, `Flutter/`, `Podfile`) such that `flutter build ios --release --no-codesign` succeeds from `app/` on a macOS host with Xcode and the iOS platform runtime installed, when CocoaPods resolution is forced via `flutter config --no-enable-swift-package-manager`.

#### Scenario: flutter build ios succeeds with scaffolding present

- **GIVEN** `app/ios/Podfile`, `app/ios/Runner/Info.plist`, and `app/ios/Runner.xcodeproj/` are committed, and SPM is disabled
- **WHEN** `flutter build ios --release --no-codesign` is executed from `app/` on a macOS host with Xcode and the iOS platform runtime installed
- **THEN** the libmpv CocoaPods resolve and the build completes without errors, producing a `.app` bundle under `app/build/ios/`

### Requirement: Bundle identifier is dev.geekjapan.geekplayer

The `PRODUCT_BUNDLE_IDENTIFIER` in `app/ios/Runner.xcodeproj/project.pbxproj` MUST be `dev.geekjapan.geekplayer` for all Runner build configurations.

#### Scenario: Bundle identifier is correct in all configurations

- **GIVEN** the `app/ios/Runner.xcodeproj/project.pbxproj` file
- **WHEN** all `PRODUCT_BUNDLE_IDENTIFIER` values for the Runner target are read
- **THEN** each value is `dev.geekjapan.geekplayer`

### Requirement: App display name is GeekPlayer

The `CFBundleDisplayName` key in `app/ios/Runner/Info.plist` MUST be `GeekPlayer` (capital G, capital P).

#### Scenario: Display name is correctly cased

- **GIVEN** `app/ios/Runner/Info.plist`
- **WHEN** the `CFBundleDisplayName` value is read
- **THEN** it is exactly `GeekPlayer`

### Requirement: Deployment target is iOS 14.0 or higher

The `IPHONEOS_DEPLOYMENT_TARGET` in `app/ios/Runner.xcodeproj/project.pbxproj` MUST be `14.0` or higher for all build configurations. media_kit's own minimum is iOS 13.0, but the `file_picker` plugin requires iOS 14.0, so the effective floor is 14.0.

#### Scenario: Deployment target is declared

- **GIVEN** the `app/ios/Runner.xcodeproj/project.pbxproj` file
- **WHEN** all `IPHONEOS_DEPLOYMENT_TARGET` values are read
- **THEN** each value is `14.0` or higher

### Requirement: iPhone and iPad are both supported

The `TARGETED_DEVICE_FAMILY` in `app/ios/Runner.xcodeproj/project.pbxproj` MUST be `"1,2"` for all Runner build configurations, enabling both iPhone and iPad.

#### Scenario: Device family covers iPhone and iPad

- **GIVEN** the `app/ios/Runner.xcodeproj/project.pbxproj` file
- **WHEN** all `TARGETED_DEVICE_FAMILY` values for the Runner target are read
- **THEN** each value is `"1,2"`

### Requirement: Podfile declares iOS 14.0 platform

`app/ios/Podfile` MUST declare `platform :ios, '14.0'` (or higher) so CocoaPods enforces the minimum deployment target for all pods.

#### Scenario: Podfile platform declaration is correct

- **GIVEN** `app/ios/Podfile`
- **WHEN** the `platform` declaration is read
- **THEN** the iOS version is `14.0` or higher

### Requirement: Info.plist includes document access usage descriptions

`app/ios/Runner/Info.plist` MUST contain the keys `NSDocumentsFolderUsageDescription`, `UIFileSharingEnabled` (true), and `LSSupportsOpeningDocumentsInPlace` (true) to enable local media file access via the document picker.

#### Scenario: Usage description keys are present

- **GIVEN** `app/ios/Runner/Info.plist`
- **WHEN** the plist is parsed
- **THEN** `NSDocumentsFolderUsageDescription` is a non-empty string, `UIFileSharingEnabled` is true, and `LSSupportsOpeningDocumentsInPlace` is true

### Requirement: iOS plugin resolution uses CocoaPods, not Swift Package Manager

Because `media_kit_video` and `media_kit_libs_ios_video` do not support Swift Package Manager, iOS builds MUST resolve plugins via CocoaPods. When the toolchain has SPM enabled, builds MUST first run `flutter config --no-enable-swift-package-manager` so CocoaPods (which ships the prebuilt libmpv XCFramework) is used.

#### Scenario: CocoaPods resolves the libmpv pods

- **GIVEN** SPM is disabled on the build toolchain
- **WHEN** `flutter build ios` runs `pod install`
- **THEN** `media_kit_libs_ios_video` resolves and the prebuilt libmpv XCFramework is fetched without an SPM resolution error

### Requirement: ADR-0006 compliance is documented in design

The `add-platform-ios` design MUST explicitly resolve the three ADR-0006 requirements: (a) media engine choice, (b) distribution channel, and (c) LGPL compliance method.

#### Scenario: Design documents ADR-0006 resolution

- **GIVEN** `openspec/changes/add-platform-ios/design.md`
- **WHEN** the document is read
- **THEN** it contains explicit statements for engine selection (Option A or B), distribution channel (non-App-Store), and LGPL handling (dynamic link + re-link instructions)

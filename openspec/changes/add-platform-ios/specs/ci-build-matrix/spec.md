# ci-build-matrix Delta Specification (add-platform-ios)

The following requirement REPLACES the existing `Requirement: no iOS CI job is defined until ADR-0006 is implemented` in `openspec/specs/ci-build-matrix/spec.md`.

## MODIFIED Requirements

### Requirement: no iOS CI job is defined until the build spike passes

No iOS/iPadOS CI job SHALL be added to the workflow until `flutter build ios --release --no-codesign` completes successfully in a local spike on the current dependency set. ADR-0006 has been accepted (2026-06-03), satisfying the ADR precondition; however, the `add-platform-ios` dependency spike (2026-06-03) encountered `Xcode failed to resolve Swift Package Manager dependencies` caused by `media_kit_video` and `media_kit_libs_ios_video` lacking Swift Package Manager support for iOS. A CI job that cannot build would produce false negatives and degrade CI signal.

The deferral reason is now technical (SPM incompatibility with media_kit_libs_ios_video) rather than policy (ADR-0006 not resolved). When `media_kit_libs_ios_video` gains SPM support or an equivalent CocoaPods-only workaround is confirmed, the `build-ios` CI job SHALL be added.

#### Scenario: iOS CI is absent from the workflow

- **GIVEN** the current `.github/workflows/ci.yaml`
- **WHEN** the file is parsed for job definitions
- **THEN** no job contains an `xcodebuild` or `flutter build ios` step

#### Scenario: iOS CI deferral reason is documented

- **GIVEN** `openspec/changes/add-platform-ios/design.md`
- **WHEN** the spike result section is read
- **THEN** it states that the failure was `Xcode failed to resolve Swift Package Manager dependencies` from `media_kit_video` / `media_kit_libs_ios_video` and that ADR-0006 is fully accepted

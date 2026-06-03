# ci-build-matrix Specification

## Purpose

Defines the GitHub Actions CI job matrix for GeekPlayer: static analysis and unit tests, plus per-platform release/debug build smoke jobs (Android, Windows, macOS, Linux) with a pinned Flutter version, build_runner codegen, and GIT_SHA embedding. iOS CI is explicitly deferred until ADR-0006.

## Requirements

### Requirement: analyze-and-test job covers static analysis and unit tests

An `analyze-and-test` job MUST run on `ubuntu-latest`, execute `flutter analyze --fatal-infos` with zero warnings, and execute `flutter test` with all tests passing.

#### Scenario: analyze-and-test passes on push to main

- **WHEN** a push to `main` triggers the CI workflow
- **THEN** the `analyze-and-test` job completes with exit code 0, no analyzer warnings, and no test failures

### Requirement: build-android-debug job produces a debug APK

A `build-android-debug` job MUST run on `ubuntu-latest`, build a debug APK, and upload it as a workflow artifact retained for 14 days.

#### Scenario: Android debug APK artifact is uploaded

- **WHEN** the `build-android-debug` job completes successfully
- **THEN** a workflow artifact named `geekplayer-android-debug-<run_number>` containing `app-debug.apk` is available for download

### Requirement: build-windows-release job produces a release bundle

A `build-windows-release` job MUST run on `windows-latest`, build a release `.exe` bundle, package it as a zip, and upload it as a workflow artifact.

#### Scenario: Windows release zip artifact is uploaded

- **WHEN** the `build-windows-release` job completes successfully
- **THEN** a workflow artifact named `geekplayer-windows-release-<run_number>` containing `geekplayer.exe` and its DLLs is available for download

### Requirement: build-macos job performs a macOS release build smoke

A `build-macos` job MUST run on `macos-latest` and execute `flutter build macos --release --dart-define=GIT_SHA=${{ github.sha }}` as a compilation smoke test.

#### Scenario: macOS release build smoke passes

- **WHEN** the `build-macos` job runs `flutter build macos --release`
- **THEN** the build exits with code 0 and no compilation or linker errors are reported

### Requirement: build-linux job performs a Linux release build smoke with native dependencies

A `build-linux` job MUST run on `ubuntu-latest`, install `libmpv-dev`, `ninja-build`, and `libgtk-3-dev` via apt, and then execute `flutter build linux --release --dart-define=GIT_SHA=${{ github.sha }}`.

#### Scenario: Linux release build smoke passes after installing system packages

- **WHEN** the `build-linux` job installs `libmpv-dev ninja-build libgtk-3-dev` and runs `flutter build linux --release`
- **THEN** the CMake/ninja compilation succeeds and the build exits with code 0

#### Scenario: Missing libmpv-dev causes a linker failure

- **GIVEN** a Linux CI job where the apt install step is skipped
- **WHEN** `flutter build linux --release` runs and media_kit attempts to link libmpv
- **THEN** the build fails with a linker error referencing a missing `libmpv` symbol

### Requirement: all jobs pin Flutter version and use build_runner before building

All CI jobs MUST use `subosito/flutter-action@v2` with `channel: stable`, `flutter-version: '3.44.0'`, and `cache: true`, and MUST run `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs` before any build or test step.

#### Scenario: Flutter version is consistently 3.44.0 across all jobs

- **WHEN** any CI job prints `flutter --version`
- **THEN** the reported Flutter version is exactly `3.44.0`

#### Scenario: Missing code generation causes drift compilation failure

- **GIVEN** a job that skips `dart run build_runner build`
- **WHEN** `flutter build` runs against the app
- **THEN** the build fails with missing generated `.g.dart` files

### Requirement: GIT_SHA dart-define is set to the triggering commit SHA in CI

All build smoke jobs MUST pass `--dart-define=GIT_SHA=${{ github.sha }}` so the About screen shows a real commit reference rather than `(dev build)`.

#### Scenario: About screen in CI build shows commit SHA

- **GIVEN** a CI build that passes `--dart-define=GIT_SHA=${{ github.sha }}`
- **WHEN** the resulting binary's About screen is inspected
- **THEN** the commit field displays the full SHA instead of `(dev build)`

### Requirement: no iOS CI job is defined until ADR-0006 is implemented

No iOS/iPadOS CI job SHALL be added to the workflow until the media-engine and distribution decisions from ADR-0006 are implemented and Xcode runner availability on GitHub Actions is confirmed.

#### Scenario: iOS CI is absent from the workflow

- **GIVEN** the current `.github/workflows/ci.yaml`
- **WHEN** the file is parsed for job definitions
- **THEN** no job contains an `xcodebuild` or `flutter build ios` step

## ADDED Requirements

### Requirement: app/linux/ CMake scaffolding is present and complete

The `app/linux/` directory MUST contain a valid Flutter Linux CMake scaffolding (`CMakeLists.txt`, `runner/`, `flutter/`) such that `flutter build linux --release` succeeds from `app/` without any structural changes.

#### Scenario: flutter build linux succeeds with scaffolding present

- **GIVEN** `app/linux/CMakeLists.txt`, `app/linux/runner/`, and `app/linux/flutter/` are committed
- **WHEN** `flutter build linux --release` is executed from `app/` on a host with required system packages installed
- **THEN** the build completes without errors and produces a binary at `app/build/linux/x64/release/bundle/geekplayer`

### Requirement: CMakeLists.txt requires CMake 3.13 or higher

The top-level `app/linux/CMakeLists.txt` MUST declare `cmake_minimum_required(VERSION 3.13)` or higher.

#### Scenario: CMake version requirement is declared

- **GIVEN** the `app/linux/CMakeLists.txt` file
- **WHEN** the first `cmake_minimum_required` call is read
- **THEN** the declared version is 3.13 or greater

### Requirement: GTK+ 3.0 is declared as a required package dependency

The `app/linux/CMakeLists.txt` MUST call `pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)` so that builds on hosts missing `libgtk-3-dev` fail loudly at CMake configure time.

#### Scenario: Missing GTK causes configuration failure

- **GIVEN** a build host without `libgtk-3-dev` installed
- **WHEN** CMake configure runs on `app/linux/`
- **THEN** the configure step fails with an error from `pkg_check_modules` indicating GTK+ 3.0 was not found

### Requirement: three system packages must be installed before flutter build linux

On any Linux build host (CI or developer machine), `libmpv-dev`, `ninja-build`, and `libgtk-3-dev` MUST be installed before invoking `flutter build linux`. These packages satisfy media_kit's libmpv native dependency (ADR-0002), the CMake/ninja build toolchain, and the GTK+ 3.0 Flutter runner requirement respectively.

#### Scenario: All required packages are present in CI and build succeeds

- **GIVEN** the `build-linux` CI job installs `libmpv-dev ninja-build libgtk-3-dev` before the build step
- **WHEN** `flutter build linux --release` runs
- **THEN** the build completes without missing-library or missing-header errors

### Requirement: binary name is geekplayer

The CMakeLists.txt MUST set `BINARY_NAME` to `geekplayer` so the installed bundle is consistently named across platforms.

#### Scenario: Built binary has the correct name

- **WHEN** `flutter build linux --release` completes
- **THEN** a file named `geekplayer` exists at the top level of the build bundle directory

### Requirement: GTK application identifier is dev.geekjapan.geekplayer

The `APPLICATION_ID` variable in `app/linux/CMakeLists.txt` MUST be `dev.geekjapan.geekplayer` to uniquely identify the app on the GNOME/GTK desktop.

#### Scenario: Application ID is correct

- **GIVEN** the `app/linux/CMakeLists.txt` file
- **WHEN** the `APPLICATION_ID` variable is read
- **THEN** its value is `dev.geekjapan.geekplayer`

### Requirement: Linux release build uses flutter build linux with GIT_SHA dart-define

Manual Linux release builds MUST use `flutter build linux --release --dart-define=GIT_SHA=$(git rev-parse --short HEAD)` as documented in `docs/release.md`.

#### Scenario: Release build embeds GIT_SHA

- **GIVEN** a developer runs `flutter build linux --release --dart-define=GIT_SHA=$(git rev-parse --short HEAD)`
- **WHEN** the resulting binary's About screen is inspected
- **THEN** the commit field displays the short SHA rather than `(dev build)`

### Requirement: no changes to app/linux/CMakeLists.txt are required for CI

The committed `app/linux/CMakeLists.txt` MUST be sufficient to produce a successful `flutter build linux --release` in CI with only system package installation as a prerequisite.

#### Scenario: CI build succeeds without CMakeLists.txt modifications

- **GIVEN** the committed `app/linux/CMakeLists.txt` with no local modifications
- **WHEN** the `build-linux` CI job runs after the apt install step
- **THEN** the build succeeds and no CMakeLists.txt edits were required

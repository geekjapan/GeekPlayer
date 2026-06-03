## 1. OpenSpec Artifacts

- [x] 1.1 Author `proposal.md` for `expand-ci-and-platforms`
- [x] 1.2 Author `design.md` for `expand-ci-and-platforms`
- [x] 1.3 Author `specs/ci-build-matrix/spec.md`
- [x] 1.4 Author `specs/linux-platform-support/spec.md`
- [x] 1.5 Run `openspec validate expand-ci-and-platforms --strict` and confirm pass

## 2. Linux Platform Verification

- [x] 2.1 Confirm `app/linux/CMakeLists.txt` exists and contains valid Flutter Linux CMake scaffolding
- [x] 2.2 Confirm `app/linux/runner/` and `app/linux/flutter/` are present
- [x] 2.3 Verify no changes to `app/linux/CMakeLists.txt` are required for CI build

## 3. CI Expansion

- [x] 3.1 Add `build-macos` job to `.github/workflows/ci.yaml` (runner: `macos-latest`, `flutter build macos --release --dart-define=GIT_SHA=${{ github.sha }}`)
- [x] 3.2 Add `build-linux` job to `.github/workflows/ci.yaml` (runner: `ubuntu-latest`, apt install `libmpv-dev ninja-build libgtk-3-dev`, then `flutter build linux --release --dart-define=GIT_SHA=${{ github.sha }}`)
- [x] 3.3 Verify all existing jobs (`analyze-and-test`, `build-android-debug`, `build-windows-release`) are intact and unmodified

## 4. Documentation

- [x] 4.1 Add Linux build command to `docs/release.md` under the "必須ビルドコマンド" section

## 5. Verification

- [x] 5.1 Run `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yaml'))"` (YAML parses cleanly)
- [x] 5.2 Run `cd app && dart format --output=none --set-exit-if-changed .` (no format drift)
- [x] 5.3 Run `cd app && flutter analyze --fatal-infos` (clean)
- [x] 5.4 Run `cd app && flutter test` (all existing tests pass)
- [x] 5.5 Run `openspec validate expand-ci-and-platforms --strict`
- [x] 5.6 Run `git diff --check` (no whitespace errors)

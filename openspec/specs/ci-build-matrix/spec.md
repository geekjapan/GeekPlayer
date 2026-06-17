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

A `build-macos` job MUST run on `macos-latest`, force CocoaPods plugin resolution via `flutter config --no-enable-swift-package-manager`（SPM 経由の PDFium xcframework 解決が artifact キャッシュ破損で失敗するため、`build-ios` と同様に CocoaPods へ寄せる）, and execute `flutter build macos --release --dart-define=GIT_SHA=${{ github.sha }}` as a compilation smoke test. The job MUST run `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs` before the build, and the build step MUST be wrapped in the native-asset retry mechanism.

#### Scenario: macOS release build smoke passes

- **WHEN** the `build-macos` job disables SPM, resolves CocoaPods, and runs `flutter build macos --release`
- **THEN** the build exits with code 0 and no compilation or linker errors are reported

#### Scenario: SPM is forced off before resolution

- **GIVEN** the `build-macos` job definition
- **WHEN** its steps are read
- **THEN** `flutter config --no-enable-swift-package-manager` runs before `flutter pub get`

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

### Requirement: build-ios job performs an iOS release build smoke

A `build-ios` job MUST run on `macos-latest`, force CocoaPods plugin resolution via `flutter config --no-enable-swift-package-manager` (because `media_kit_libs_ios_video` lacks Swift Package Manager support), and execute `flutter build ios --release --no-codesign --dart-define=GIT_SHA=${{ github.sha }}` as a compilation smoke test. The job MUST run `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs` before the build.

#### Scenario: iOS release build smoke passes

- **WHEN** the `build-ios` job disables SPM, resolves CocoaPods, and runs `flutter build ios --release --no-codesign`
- **THEN** the libmpv pods resolve and the build exits with code 0

#### Scenario: SPM is forced off before resolution

- **GIVEN** the `build-ios` job definition
- **WHEN** its steps are read
- **THEN** `flutter config --no-enable-swift-package-manager` runs before `flutter pub get`

### Requirement: build-android-debug job verifies 16 KB ELF alignment

`build-android-debug` ジョブ（`.github/workflows/ci.yaml`）は、APK ビルド後に同梱 `lib/arm64-v8a/*.so` の 16 KB ELF アラインメントを検査するステップを MUST 実行する。`libVkLayer_*.so` を除くいずれかの `.so` の LOAD セグメント最大 `p_align` が `0x4000` 未満の場合、ジョブは fail する。これにより 16 KB 非対応ライブラリの混入を継続的に回帰検出する。

#### Scenario: 全ライブラリが 16 KB アラインメントなら CI は通過する

- **WHEN** `build-android-debug` ジョブがビルド済み APK の `lib/arm64-v8a/*.so` を検査する
- **AND** `libVkLayer_*.so` を除く全 `.so` の LOAD `p_align` が `0x4000` 以上である
- **THEN** 検査ステップは成功し、ジョブは APK アーティファクトをアップロードする

#### Scenario: 16 KB 非対応ライブラリが混入すると CI が fail する

- **WHEN** `lib/arm64-v8a/` のいずれかの `.so`（`libVkLayer_*.so` を除く）の LOAD `p_align` が `0x4000` 未満である
- **THEN** 検査ステップは非ゼロ終了し、`build-android-debug` ジョブは fail する


### Requirement: CI workflow trigger events と concurrency

CI ワークフロー（`.github/workflows/ci.yaml`）は、以下のトリガーイベントで発火しなければならない (MUST): `main` ブランチへの `push`、`main` ブランチを base とする `pull_request`、および手動実行用の `workflow_dispatch`。さらにワークフローは ref 単位の `concurrency` グループ（同一 ref の新しい run が古い run を `cancel-in-progress` で打ち切る）を MUST 設定し、同一ブランチへの連続 push で無駄な並列実行が積み上がらないようにする。`push` は `main` に限定し (MUST)、feature ブランチの検証は main 宛 `pull_request` で行うことで、PR とマージ後の二重実行を避ける。

#### Scenario: main への push で CI が自動発火する

- **WHEN** `main` ブランチへコミットが push される
- **THEN** CI ワークフローが `workflow_dispatch` を待たずに自動でトリガーされ、6 ジョブ matrix が実行される

#### Scenario: main 宛 PR で CI が自動発火する

- **WHEN** `main` を base とする pull request が open / 更新される
- **THEN** CI ワークフローが自動でトリガーされ、6 ジョブ matrix が実行される

#### Scenario: 手動 dispatch が引き続き可能

- **WHEN** ユーザーが GitHub UI / API から workflow を手動実行する
- **THEN** `workflow_dispatch` トリガーにより CI が実行される

#### Scenario: 同一 ref の連続 push で古い run が打ち切られる

- **GIVEN** ある ref の CI run が進行中
- **WHEN** 同じ ref に新しい push が来て新しい run が開始される
- **THEN** concurrency グループにより進行中の古い run が cancel され、最新コミットの run のみが残る

### Requirement: ネイティブ資産取得を含むステップは transient 失敗をリトライする

ネイティブ資産（prebuilt 共有ライブラリ・xcframework 等）を外部から取得するビルド/テストステップ（`analyze-and-test` の `flutter test`、各 `build-*` ジョブの `flutter build`）は、取得層の transient な失敗（HTTP 5xx、ダウンロード integrity/hash 不一致、partial download）に対し、第三者 action に依存しない仕組みで自動リトライしなければならない (MUST)。リトライは上限試行回数を持ち (MUST)、上限到達後も失敗する場合はステップを非ゼロ終了させて CI を fail させなければならない (MUST)。これにより、永続的な失敗（コード回帰・上流の恒久的バイナリ差し替え）に対する検知能力を維持しつつ、transient 失敗による偽陽性を抑制する。

#### Scenario: transient なダウンロード失敗がリトライで吸収される

- **GIVEN** ネイティブ資産取得ステップが 1 回目に HTTP 5xx または integrity 不一致で失敗する
- **WHEN** リトライ機構が上限内で再実行し、その回で取得が成功する
- **THEN** ステップは最終的に exit 0 となり、ジョブは成功する

#### Scenario: 永続的な失敗は上限後に fail する

- **GIVEN** 取得ステップが上限試行回数すべてで失敗する
- **WHEN** リトライ上限に到達する
- **THEN** ステップは非ゼロ終了し、ジョブは fail する（恒久障害の検知能力を維持）

### Requirement: CI ジョブは外部ネイティブ資産の取得をキャッシュする

外部からネイティブ資産（pub-cache 配下の prebuilt 共有ライブラリ、Gradle distribution、CocoaPods tarball 等）を取得する CI ジョブは、それらの取得物を公式 `actions/cache` でキャッシュし、後続 run での再ダウンロードを避けなければならない (MUST)。これは既存のリトライ要件（`ネイティブ資産取得を含むステップは transient 失敗をリトライする`）を置き換えるものではなく、transient ダウンロード失敗への露出を減らす補完として併用しなければならない (MUST)。

キャッシュキーは依存ロックファイル（`pubspec.lock`、Gradle wrapper 定義、`Podfile.lock` 等）のハッシュに紐づけ、依存が変わったときにキャッシュが自然に無効化されるようにしなければならない (MUST)。第三者のキャッシュ用 action や自前ミラーは導入してはならない (MUST NOT)。キャッシュ miss（初回 run やキー変更時）はジョブを失敗させてはならず、フォールバックとして従来どおり外部取得を行わなければならない (MUST)。

#### Scenario: pub-cache のキャッシュ hit で再ダウンロードが省かれる

- **WHEN** `pubspec.lock` を変更しないコミットで CI が再実行される
- **THEN** `~/.pub-cache` のキャッシュが復元され、sqlite3 / media_kit / pdfium 等のネイティブ資産が再ダウンロードされない

#### Scenario: Gradle distribution / caches のキャッシュ hit で 504 を回避する

- **WHEN** `build-android-debug` ジョブが Gradle wrapper 定義を変えずに再実行される
- **THEN** `~/.gradle/caches` と `~/.gradle/wrapper` のキャッシュが復元され、Gradle distribution の再ダウンロードが省かれる

#### Scenario: 依存変更でキャッシュキーが更新される

- **WHEN** `pubspec.lock` または `Podfile.lock` が変更されたコミットで CI が実行される
- **THEN** キャッシュキーが変わり、新しい依存に対して外部取得とキャッシュ再作成が行われる

#### Scenario: キャッシュ miss でもジョブが失敗しない

- **WHEN** 該当キーのキャッシュが存在しない（初回 run またはキー変更直後）状態で CI が実行される
- **THEN** ジョブはキャッシュ miss を許容し、従来どおり外部取得（必要に応じてリトライ）を経てビルド/テストを完了する

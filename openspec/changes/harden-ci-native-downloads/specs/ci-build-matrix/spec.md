## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: build-macos job performs a macOS release build smoke

A `build-macos` job MUST run on `macos-latest`, force CocoaPods plugin resolution via `flutter config --no-enable-swift-package-manager`（SPM 経由の PDFium xcframework 解決が artifact キャッシュ破損で失敗するため、`build-ios` と同様に CocoaPods へ寄せる）, and execute `flutter build macos --release --dart-define=GIT_SHA=${{ github.sha }}` as a compilation smoke test. The job MUST run `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs` before the build, and the build step MUST be wrapped in the native-asset retry mechanism.

#### Scenario: macOS release build smoke passes

- **WHEN** the `build-macos` job disables SPM, resolves CocoaPods, and runs `flutter build macos --release`
- **THEN** the build exits with code 0 and no compilation or linker errors are reported

#### Scenario: SPM is forced off before resolution

- **GIVEN** the `build-macos` job definition
- **WHEN** its steps are read
- **THEN** `flutter config --no-enable-swift-package-manager` runs before `flutter pub get`

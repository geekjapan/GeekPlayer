## Why

`enable-ci-auto-triggers`（#26）で CI を自動実行化した初日、全ジョブが**外部 CDN からのネイティブ資産取得で非決定的に失敗**した。`flutter analyze` / `dart format` / OSS license ゲート・unit test ロジックはすべて健全で、失敗はネイティブ資産の取得層に集中している。実際に同一 commit の rerun で `analyze-and-test` が green になり transient（flaky）であることを確認済み。自動 CI が「赤」のままだと回帰検知のシグナルが信用されなくなるため、取得層を堅牢化する。

観測された失敗（2026-06-08, runs 27119749469 / 27120096846 / 27120485266 / 27120760110）:
- `analyze-and-test` の `flutter test`: `package:sqlite3` の build hook が `libsqlite3.x64.linux.so` を DL しハッシュ不一致（rerun で成功 = transient）
- `build-android-debug`: `media-kit/libmpv-android-video-build` の jar に `HTTP 504`
- `build-linux`: `mimalloc-2.1.2.tar.gz` Integrity check failed（別 run では成功）
- `build-windows-release`: `media_kit_libs_windows_video` の Integrity check failed（"try to re-build project again"）
- `build-ios`: CocoaPods 経由 libmpv/pdfium tar.gz download FAILED
- `build-macos`: **SPM** 経由 PDFium xcframework の解決失敗（`already exists in file system` = SPM artifact キャッシュ破損）。macOS ジョブだけ `flutter config --no-enable-swift-package-manager` が無い

## What Changes

- **リトライ**: ネイティブ資産を取得する各ジョブの主要ステップ（`flutter test` / `flutter build apk|windows|macos|linux|ios`）を、第三者 action に依存しない **bash リトライループ**（最大 3 試行・固定バックオフ）でラップする。transient な 504 / integrity / partial-download を吸収する。
- **build-macos の SPM 無効化**: `build-ios` と同様に `flutter config --no-enable-swift-package-manager` を `flutter pub get` の前に追加し、SPM PDFium artifact 破損を回避して CocoaPods 経路へ寄せる（リトライ対象に揃える）。
- ジョブの runner・成果物・ビルドコマンド本体・Flutter pin・16KB ゲート等は不変。リトライラッパと macOS の 1 ステップ追加のみ。

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `ci-build-matrix`: ① ネイティブ資産取得を含むビルド/テストステップは transient な取得失敗に対しリトライしなければならない、という新規要件を追加（ADDED）。② `build-macos` 要件を、SPM を無効化し CocoaPods 経路でビルドする形に更新（MODIFIED）。

## Impact

- 変更ファイル: `.github/workflows/ci.yaml`（各ジョブのビルド/テストステップをリトライ化、build-macos に SPM 無効化ステップ追加）。
- spec: `openspec/specs/ci-build-matrix/spec.md`（delta 経由）。
- 挙動: transient なネットワーク/integrity 失敗が自動リトライで吸収され、CI の偽陽性が減る。永続的な障害（コード回帰・上流の恒久的バイナリ差し替え）はリトライ後も fail するため検知能力は維持。
- アプリ実行コード・依存・スキーマへの影響なし。

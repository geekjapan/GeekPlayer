## 1. リトライラッパ実装

- [x] 1.1 `analyze-and-test` の `flutter test` を bash リトライループ（max 3・20s backoff・until 形式で最終失敗は exit 1）でラップ（design D1/D2）
- [x] 1.2 `build-android-debug` の `flutter build apk --debug` をリトライ化（後続の 16KB ゲート・artifact upload は据え置き、design D4）
- [x] 1.3 `build-windows-release` の `flutter build windows --release` をリトライ化し、**`shell: bash` を明示**（windows-latest の既定 shell は pwsh のため必須。Git Bash 同梱。packaging の pwsh ステップは不変、design D2 注意）
- [x] 1.4 `build-linux` の `flutter build linux --release ...` をリトライ化
- [x] 1.5 `build-ios` の `flutter build ios --release --no-codesign ...` をリトライ化
- [x] 1.6 `build-macos` の `flutter build macos --release ...` をリトライ化

## 2. build-macos の SPM 無効化

- [x] 2.1 `build-macos` に `flutter config --no-enable-swift-package-manager` ステップを `flutter pub get` の前へ追加（build-ios と同形、design D3）

## 3. 検証

- [x] 3.1 `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yaml'))"` で YAML parse 成功（6 ジョブ維持）
- [x] 3.2 各 build/test ステップにリトライループ（`until`/`max`/`exit 1`）が入り、ビルドコマンド本体・runner・成果物設定・Flutter pin・16KB ゲートが不変であることを diff で確認
- [x] 3.3 `build-macos` に `--no-enable-swift-package-manager` が pub get 前に存在すること、`build-windows-release` のリトライ build ステップに `shell: bash` が付与されていることを確認
- [x] 3.4 `openspec validate --all --strict` パス
- [x] 3.5 **検証済み（2026-06-08, PR #29 run 27121570608）**: リトライ機構が設計通り動作（attempt 1→2→3 + 20s backoff、上限後 `::error` で exit 1）。初回で 4/6 ジョブが green（前回 1–2/6 から改善、build-ios/windows がリトライ無しでは落ちていたものが green 化）。残った build-android（Gradle distribution の `gradle-9.1.0-all.zip` に 504）と build-macos（pdfrx の PDFium xcframework hash 不一致。SPM 無効化は奏功し SPM エラーは消失、同一 run の build-ios は同じ PDFium を CocoaPods 経由で取得成功 → macOS 失敗は corrupted/partial DL の transient）を `gh run rerun --failed` したところ**6 ジョブ全て green**。transient 失敗がリトライ＋再実行で吸収されることを実証。恒久的に長い CDN 障害向けの追加耐性（Gradle distribution キャッシュ・試行回数増）は将来の任意改善

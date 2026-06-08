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
- [ ] 3.5 **マージ後フォローアップ**: main への push で自動 run を実行し、（a）transient 失敗がリトライで吸収され、（b）`analyze-and-test` および build smoke が安定して green に近づくことを `gh run view` で確認（恒久障害が無い限り）

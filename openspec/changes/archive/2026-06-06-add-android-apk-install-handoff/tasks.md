## 1. 設計確定（grill ゲート）

- [x] 1.1 grill-changes-before-apply で D2 を確定: install intent 機構（`open_filex` 採用 / platform channel）と FileProvider 所有（パッケージ同梱 / 自前宣言 `${applicationId}.fileprovider`）。ライセンス（非 GPL/LGPL）と非 Android ビルド非影響を確認
- [x] 1.2 `UpdateDownloader` の保存先が `getTemporaryDirectory()`（Android では cache dir）であることを確認し、自前 provider 採用時の `file_paths.xml` スコープ（`<cache-path>`）を確定（self-grill 解決済み、design 参照）

## 2. プラットフォーム分岐（capability: auto-update）— TDD

注: `LaunchUrlUpdateInstaller` に注入シーム（`platform` 述語 / `launchFileUrl` / `androidInstall`、いずれも本番関数を既定値）を追加し、両分岐を device 非依存でテストする（design D1/D4）。

- [x] 2.1 [test] `platform: () => false`（非 Android）で注入 `launchFileUrl` が `Uri.file(path)` で呼ばれることを検証（red→green）
- [x] 2.2 [test] `platform: () => true`（Android）で注入 `androidInstall` が呼ばれ、`file://` URI を OS に渡さないことを検証（実機 intent 非依存）
- [x] 2.3 `LaunchUrlUpdateInstaller` に注入シームを追加し `openForInstall` を分岐実装: Android は `androidInstall`（D2 確定機構で content URI install intent）、それ以外は `launchFileUrl(Uri.file(path))`。失敗時は throw して banner が idle/error に戻れるようにする
- [x] 2.4 [test] handoff 失敗（`launchFileUrl` が false / `androidInstall` が throw）で `openForInstall` が throw することを検証

## 3. Android マニフェスト/リソース

- [x] 3.1 `android/app/src/main/AndroidManifest.xml` に `REQUEST_INSTALL_PACKAGES` `uses-permission` を追加
- [x] 3.2 `<queries>` に install 用 `ACTION_VIEW` + apk mime（`application/vnd.android.package-archive`）を追加し、Android 11+ の package visibility を満たす
- [x] 3.3 自前 `<provider>` は宣言しない（`open_filex` 同梱の FileProvider authority `${applicationId}.fileProvider.com.crazecoder.openfile` を利用、`res/xml/file_paths.xml` も追加しない）。authority 衝突回避のため二重宣言しないことを確認
- [x] 3.4 `pubspec.yaml` に `open_filex` を追加し `flutter pub get`。ライセンス（BSD-3）と非 Android ビルド非影響を確認

## 4. 検証

- [x] 4.1 `dart format lib test`
- [x] 4.2 `flutter analyze --fatal-infos` がクリーン
- [x] 4.3 `flutter test` 全緑（update flow / installer routing。実機 install intent は非依存）
- [x] 4.4 `openspec validate add-android-apk-install-handoff --strict` が通る
- [x] 4.5 `git diff --check` で空白エラーなし
- [x] 4.6a `docs/HANDOFF.md` §7 の残課題を「解決済み」に更新（file-provider 対応完了・実機検証手順を明記）
- [ ] 4.6b [manual / 環境制約で未実施] 実 Android 端末/エミュレータで DL→install intent 起動を 1 度確認。**この環境に Android デバイス/SDK がないため未実施。ユーザー側で実機確認が必要**（routing はホストで注入 fake により単体テスト済み・CI 非依存）

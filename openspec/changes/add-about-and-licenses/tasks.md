> **Conventions**: [docs/CONVENTIONS.md](../../../docs/CONVENTIONS.md) と
> [ADR-0004 (HomeScreen registry)](../../../docs/adr/0004-home-screen-section-registry.md)
> を着手前に読むこと。About 画面の AppBar エントリ（info アイコン）は
> `homeAppBarActionsProvider` にサブプロバイダとして登録する（`HomeScreen` 直接編集禁止）。

## 1. 依存追加とビルド構成

- [x] 1.1 `app/pubspec.yaml` に `package_info_plus` と `url_launcher` を **冪等に**（既に存在すれば skip、CONVENTIONS.md §2 参照）`flutter pub add` で追加し、`flutter pub get` がクリーン
- [x] 1.2 `app/pubspec.yaml` の `dev_dependencies` に `flutter_oss_licenses` を追加
- [x] 1.3 `app/android/app/src/main/AndroidManifest.xml` に `<queries>` ブロックを追加し、`https` スキームを宣言（Android 11+ で `url_launcher` が必須）
- [x] 1.4 リリース手順書（`docs/release.md` 新規 or 既存 README） に `flutter build <target> --dart-define=GIT_SHA=$(git rev-parse --short HEAD)` を必須コマンドとして明文化
- [x] 1.5 `flutter analyze` / `flutter test` が依存追加後にクリーン

## 2. ライセンスデータ生成とアセット

- [x] 2.1 `dart run flutter_oss_licenses:generate -o lib/oss_licenses.dart` を実行し、生成物を VCS にコミット
- [x] 2.2 `app/assets/legal/LICENSE` に Apache-2.0 全文 (`/LICENSE` のコピー) を配置し、`app/pubspec.yaml` の `flutter.assets` に追加
- [x] 2.3 `app/assets/legal/LGPL-2.1.txt` に FSF 公式の LGPL-2.1 本文を配置し、`flutter.assets` に追加
- [x] 2.4 `app/assets/legal/checksums.txt` に `LGPL-2.1.txt` の SHA-256 を記録
- [x] 2.5 主要依存 (`media_kit`, `just_audio`, `drift`, `dio`, `riverpod`, `html`, `webfeed`) が `lib/oss_licenses.dart` に含まれることをスナップショットテスト (`app/test/features/about/oss_licenses_snapshot_test.dart`) で検証

## 3. ドメイン / データ層 (`features/about`)

- [x] 3.1 `app/lib/features/about/domain/license_entry.dart` に `LicenseEntry` 値オブジェクト（`name`, `version`, `licenseText`, `homepageUrl?`）を実装
- [x] 3.2 `app/lib/features/about/data/oss_license_repository.dart` に `OssLicenseRepository.fetchEntries()` を実装し、`lib/oss_licenses.dart` を読み出して `LicenseEntry` のソート済みリストを返す
- [x] 3.3 `app/lib/features/about/data/app_info_provider.dart` に `package_info_plus` の `PackageInfo.fromPlatform()` をラップした Riverpod provider を実装
- [x] 3.4 `app/lib/features/about/data/build_info.dart` に `const String kGitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'unknown');` と、UI 用の `String formattedGitSha()`（`unknown` → `(dev build)`）を実装
- [x] 3.5 `OssLicenseRepository` の単体テストを `app/test/features/about/oss_license_repository_test.dart` に追加（ソート / 重複排除 / 空文字 license のフィルタ）

## 4. About 画面実装

- [x] 4.1 `app/lib/features/about/presentation/about_screen.dart` に AppBar + ヘッダー（アプリ名 / バージョン / ビルド番号 / コミット SHA）を実装
- [x] 4.2 About 画面に Apache-2.0 NOTICE 行 (`Copyright 2026 GeekPlayer Contributors`) を表示
- [x] 4.3 About 画面に GitHub リポジトリ / Roadmap / Full License の 3 リンクボタンを実装し、`url_launcher` の `launchUrl(uri, mode: LaunchMode.externalApplication)` で開く
- [x] 4.4 `url_launcher` 失敗時に SnackBar で「リンクを開けませんでした」を表示
- [x] 4.5 「OSS ライセンス」ボタンから `LicenseListScreen` に遷移
- [x] 4.6 ADR-0004 準拠: `home_screen.dart` 直接編集ではなく `aboutAppBarActionsProvider` 経由で info アイコンを `homeAppBarActionsProvider` に登録（HomeScreen / main.dart は無編集）。`add-app-settings` の `about_section.dart` の placeholder も `AboutScreen` への `Navigator.push` に置き換え

## 5. OSS Licenses 画面実装

- [x] 5.1 `app/lib/features/about/presentation/license_screen.dart` に `LicenseListScreen` を実装し、最上部に LGPL Notice Section、その下に Apache-2.0 NOTICE Section、その下に依存パッケージ ListView を配置
- [x] 5.2 ListView は `OssLicenseRepository.fetchEntries()` の結果を表示、各エントリ (`name`, `version`) をタップで詳細画面に遷移
- [x] 5.3 `app/lib/features/about/presentation/license_detail_screen.dart` に `LicenseDetailScreen` を実装し、`SelectableText` でライセンス本文を表示
- [x] 5.4 「ライセンス全文」リンクから `assets/legal/LICENSE` を `rootBundle.loadString` で読み出して `LicenseDetailScreen` 風に表示

## 6. LGPL 通知セクション実装

- [x] 6.1 `app/lib/features/about/presentation/lgpl_notice_section.dart` を実装し、libmpv が LGPL-2.1+ で動的リンクされていること、利用者の権利、上流ソース URL (`https://github.com/mpv-player/mpv`) を `SelectableText` で表示
- [x] 6.2 OS 別差し替え手順（macOS: `Contents/Frameworks/`、Windows: `mpv-2.dll`、Android: `lib/<abi>/libmpv.so` + APK 再署名）を箇条書きで表示
- [x] 6.3 「詳細は THIRD_PARTY_NOTICES を参照」リンクを `https://github.com/geekjapan/GeekPlayer/blob/main/THIRD_PARTY_NOTICES.md` へ `url_launcher` で開く
- [x] 6.4 「LGPL-2.1 全文」リンクから `assets/legal/LGPL-2.1.txt` を `rootBundle.loadString` で読み出して詳細画面に遷移
- [ ] 6.5 `LgplNoticeSection` のウィジェットテストを `app/test/features/about/lgpl_notice_section_test.dart` に追加（URL / "LGPL-2.1+" / "動的リンク" / "差し替える権利" / OS 別パス文字列が描画されること）

## 7. ウィジェットテストと CI 整備

- [ ] 7.1 `AboutScreen` のウィジェットテストを `app/test/features/about/about_screen_test.dart` に追加（モック `PackageInfo` で version/build/SHA 表示、`unknown` → `(dev build)` 挙動）
- [ ] 7.2 `LicenseListScreen` のウィジェットテストを `app/test/features/about/license_screen_test.dart` に追加（最上部 LGPL セクション、Apache-2.0 NOTICE、依存リストの順序）
- [ ] 7.3 CI ワークフローに `dart run flutter_oss_licenses:generate -o lib/oss_licenses.dart --source` を実行して `lib/oss_licenses.dart` に diff が出ないことを検証する step を追加
- [ ] 7.4 CI に `assets/legal/LGPL-2.1.txt` の SHA-256 検証 step を追加（`checksums.txt` と突合）

## 8. ドキュメントと締め

- [ ] 8.1 `THIRD_PARTY_NOTICES.md` を更新（必要なら）: アプリ内 LGPL 通知の存在に言及
- [ ] 8.2 `flutter analyze` / `flutter test` / `dart format --set-exit-if-changed .` が CI でも green
- [ ] 8.3 すべての task の `- [ ]` を `- [x]` に更新し、`/opsx:archive` で本 change をアーカイブ

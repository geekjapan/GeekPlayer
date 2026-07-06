## 1. 調査・フィージビリティ検証

- [ ] 1.1 既存の Dart/Flutter 向け `libarchive` FFI パッケージの有無を調査し、自作バインディングと比較する。
- [ ] 1.2 macOS/Windows/Android 向け `libarchive` プリビルドバイナリの入手・同梱方法を検証する（Homebrew/vcpkg/NDK 経由 or ソースからビルド）。
- [ ] 1.3 代表的な 7z/CB7 コミックアーカイブでベンチマーク（展開時間・メモリ使用量）を取り、既存 ZIP/CBZ の体感と比較する。
- [ ] 1.4 `libarchive` の RAR5 対応状況を調査し、フォローアップ change 起票時の判断材料としてメモを残す（本 change では実装しない）。

## 2. 安全性レイヤーの共通化

- [ ] 2.1 `ArchiveInspector`（`app/lib/core/manga/archive_inspector.dart`）から、パストラバーサル判定・隠しファイル除外・画像拡張子フィルタ・自然順ソートを形式非依存の共通関数として抽出する。
- [ ] 2.2 エントリ数/サイズ上限チェックを「宣言サイズでの事前チェック」と「実展開中の累積チェック」の二段防御に対応できるインターフェースに拡張する。
- [ ] 2.3 フォーマット判定・解凍処理をバックエンドごとに切り替えられるように抽象化し、既存 ZIP 経路（`archive` パッケージ）を新インターフェースに適合させる（挙動・パフォーマンスは変えない）。

## 3. 7z/CB7 バックエンド実装

- [ ] 3.1 `libarchive` FFI バインディングを追加し、`app/pubspec.yaml` に依存関係を登録する。
- [ ] 3.2 7z バックエンドで、宣言サイズ + 実展開中の累積サイズの両方を検証しながらエントリ一覧を取得する処理を実装する。
- [ ] 3.3 `MangaRepositoryImpl.openArchive()`（`app/lib/features/manga/data/manga_repository_impl.dart:64-100`）が `.7z`/`.cb7` 拡張子を `format` 列に保存できるようにする。
- [ ] 3.4 ファイルピッカーの `allowedExtensions`（`app/lib/features/manga/presentation/manga_home_section.dart:43`）に `7z`/`cb7` を追加する。
- [ ] 3.5 `app/lib/oss_licenses.dart` に `libarchive`（BSD-3-Clause）のライセンス通知を追加する。

## 4. RAR/CBR 未対応メッセージの改善

- [ ] 4.1 `.rar`/`.cbr` 拡張子を検出した際に、汎用 `UnsupportedFormatError` ではなく「現時点で未対応（Issue #52 参照）」であることが分かる専用メッセージ/エラーコードを追加する。
- [ ] 4.2 `app/lib/l10n/app_ja.arb` / `app/lib/l10n/app_en.arb` に新しいエラーメッセージの文言を追加する。

## 5. テスト

- [ ] 5.1 `app/test/core/manga/archive_inspector_test.dart` に 7z 固定フィクスチャ（正常系、パストラバーサル、隠しファイル、サイズ超過、破損アーカイブ）を追加する。
- [ ] 5.2 `app/test/features/manga/manga_home_section_test.dart` を更新し、7z がピッカーで選択可能、RAR/CBR が選択不可のままであることを検証する。
- [ ] 5.3 `app/test/features/manga/manga_repository_test.dart` を更新し、`.7z` オープン時の `format` 列保存と、`.rar` オープン時の新しいエラーメッセージを検証する。

## 6. 仕様・ドキュメント

- [ ] 6.1 `openspec/specs/local-manga-zip-viewer/spec.md` の MODIFIED delta を確定する（本 change の `specs/local-manga-zip-viewer/spec.md`）。
- [ ] 6.2 `openspec/specs/manga-archive-safety/spec.md` の MODIFIED delta を確定する（本 change の `specs/manga-archive-safety/spec.md`）。
- [ ] 6.3 RAR/CBR 完全対応のフォローアップ GitHub Issue を起票し、本 Issue #52 からリンクする。

## 7. 検証コマンド

- [ ] 7.1 ローカルで Flutter/Dart ツールチェーンが利用可能な場合: `cd app && dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test`
- [ ] 7.2 ローカルで Flutter/Dart が利用不可の場合: GitHub Actions のフォーマット/analyze/test ワークフローの実行結果を PR に記録する。
- [ ] 7.3 `openspec validate --all --strict`
- [ ] 7.4 `git diff --check`

## Why

現在の漫画/コミックアーカイブ機能は ZIP/CBZ のみをサポートしている（`app/lib/core/manga/archive_inspector.dart:84`、`app/lib/features/manga/presentation/manga_home_section.dart:43`）。しかし利用者は RAR/CBR や 7z/CB7 形式のコミックアーカイブも所有していることが多く、GitHub Issue #52（Milestone #6「Reader and archive format support」）でこれらの形式への対応が要望されている。GeekPlayer は Apache-2.0 の OSS 配布（GitHub Releases のみ、ストア配布なし）のため、追加する解凍ライブラリのライセンス互換性を事前に検討する必要があり、実装前に本 OpenSpec change でスコープと採用ライブラリを確定する。

## What Changes

- 7z/CB7 形式のフルサポートを追加する。解凍バックエンドには `libarchive`（BSD-3-Clause、寛容ライセンス）を FFI 経由で採用し、既存の `ArchiveInspector`（`app/lib/core/manga/archive_inspector.dart`）が担う安全性チェック（パストラバーサル拒否、隠しファイル除外、対応画像拡張子フィルタ、エントリ数/展開後バイト数上限、自然順ソート）を新形式でも同一に適用できるよう、フォーマット判定と解凍処理を抽象化する（バックエンドをフォーマットごとに切り替えるインターフェースを導入し、ZIP は既存の `archive` パッケージ実装のまま温存）。
- RAR/CBR の**完全な解凍サポートは本 change では見送り、ライセンス互換性と実装可能性の評価だけを行ったうえで、フォローアップ GitHub Issue に委ねる**。ただし本 change では `.rar`/`.cbr` 拡張子を明示的に検出し、汎用の `UnsupportedFormatError` ではなく「RAR/CBR は現時点で未対応（Issue #52 からリンクするフォローアップ Issue で実装を検討中）」であることが分かるメッセージ・ラベルに更新する（Issue #52 のチェックリスト「Update user-facing labels/errors so unsupported archive formats are explained clearly」に対応）。
- ファイルピッカーの `allowedExtensions`（`app/lib/features/manga/presentation/manga_home_section.dart:43`）に `7z`/`cb7` を追加する（`rar`/`cbr` は追加しない＝ピッカーでは選択不可のままとし、既存の明示的拒否シナリオを維持）。
- `manga_metadata` テーブルの `format` 列（`app/lib/core/storage/tables/manga_metadata.dart:16`）と `MangaArchive.format`（`app/lib/features/manga/domain/manga_archive.dart:28`）が保持しうる値に `'7z'`/`'cb7'` を追加する（マイグレーション不要、文字列列の許容値追加のみ）。
- `manga-archive-safety` capability に、7z バックエンドでも同一の安全性不変条件（パストラバーサル拒否・隠しメタデータ除外・対応画像拡張子・エントリ数/サイズ上限・宣言サイズと実サイズの両方を検証する解凍爆弾対策）が適用されることを明記する。
- `local-manga-zip-viewer` capability に、7z/CB7 アーカイブを開けることを追加する。

## Capabilities

### New Capabilities
（なし。既存 capability の拡張のみ）

### Modified Capabilities
- `local-manga-zip-viewer`: ZIP/CBZ に加えて 7z/CB7 アーカイブを開けるようにする。RAR/CBR は明示的に未対応のまま、エラーメッセージのみ改善する。
- `manga-archive-safety`: 安全性検査（パストラバーサル拒否、隠しファイル除外、対応画像拡張子、エントリ数/サイズ上限、決定的な順序付け）が ZIP 以外のバックエンド（7z）にも同一に適用されることを明記する。解凍爆弾対策として「宣言サイズだけでなく実際の展開バイト数も上限と照合する」要件を追加する。

## Non-goals

- RAR/CBR アーカイブの完全な解凍サポート（本 change では評価のみ。ライセンス互換の実装方針が確定次第、Issue #52 からリンクするフォローアップ Issue で対応）。
- 7z/RAR 以外の追加アーカイブ形式（tar.gz、ACE、LHA 等）への対応。
- 既存 ZIP/CBZ 経路（`archive` パッケージ利用）の置き換えやリファクタリング。
- Manga Viewer の UI/UX（ページ送り、ズーム、しおり等）の変更。
- Android/iOS 向け `libarchive` ネイティブバイナリ配布パイプラインの実装（本 change はデスクトップ（macOS/Windows）を優先し、モバイル配布の実現可否は設計フェーズのフィージビリティ検討事項として扱う）。

## Impact

- 影響コード: `app/lib/core/manga/archive_inspector.dart`（フォーマット判定・解凍バックエンド抽象化）、`app/lib/features/manga/data/manga_repository_impl.dart:66-100`（`format` 拡張子の許容値）、`app/lib/features/manga/presentation/manga_home_section.dart:43`（ファイルピッカーの許可拡張子）、`app/lib/core/storage/tables/manga_metadata.dart:16`、`app/lib/features/manga/domain/manga_archive.dart:28`、`app/lib/features/manga/domain/manga_metadata.dart:22`。
- 新規依存関係: `libarchive`（BSD-3-Clause）への FFI バインディング（既存の Dart/Flutter パッケージで要件を満たすものがなければ、プラットフォームごとにネイティブライブラリを同梱する新規パッケージ/プラグインの追加を検討）。`app/pubspec.yaml` にエントリを追加し、`app/lib/oss_licenses.dart` のライセンス一覧を更新する。
- テスト影響: `app/test/core/manga/archive_inspector_test.dart` に 7z 固定フィクスチャ（正常系、パストラバーサル、隠しファイル、サイズ超過、破損アーカイブ）を追加。`app/test/features/manga/manga_home_section_test.dart`、`app/test/features/manga/manga_repository_test.dart` の拡張子許容値も更新。
- ドキュメント影響: `app/lib/oss_licenses.dart`（OSS ライセンス通知）、ユーザー向けエラーメッセージの ARB ローカライズファイル（`app/lib/l10n/app_ja.arb`、`app/lib/l10n/app_en.arb`）。
- GitHub Issue: #52（Milestone #6: Reader and archive format support）

## Why

UI Phase 2 バッチ3では、プレゼンテーション層がエラーを `$e` / `$err` のまま生文字列でユーザーに表示していること（例: `'追加に失敗しました: $e'`）、および ISO-8601 日付文字列（`toIso8601String()`）をそのまま表示していることが、ユーザー体験の正確性・一貫性上の問題として残っている。`ErrorMessages.localize` と `AppLocalizations` による既存インフラがあるにもかかわらず、複数の call site で使われていない。これらを修正し、エラー表示と日付表示の品質を揃える。

## What Changes

- **エラー表示の修正**: 以下の call site で生例外文字列を `ErrorMessages.localize` ／ `AppError` ラップに置換する。
  - `app/lib/features/video/presentation/home_section.dart:47` — `'読み込みに失敗しました: $e'`
  - `app/lib/features/audio/presentation/home_section.dart:58` — `'読み込みに失敗しました: $e'`
  - `app/lib/features/novel_narou/presentation/work_detail_screen.dart:168` — `'追加に失敗しました: $e'`
  - `app/lib/features/novel_kakuyomu/presentation/work_detail_screen.dart:92` — `'追加に失敗: $e'`
  - `app/lib/features/novel_kakuyomu/presentation/work_detail_screen.dart:129` — `Text('エラー: $err')`
  - `app/lib/features/novel_kakuyomu/presentation/reader_screen.dart:94` — `Text('エラー: $err')`
  - `app/lib/features/novel_kakuyomu/presentation/search_screen.dart:145` — `'エラーが発生しました: $err'`
- **日付フォーマッターの新設**: `app/lib/core/novel/utils/novel_date_formatter.dart` に `formatNovelDate(DateTime? date, BuildContext context)` を実装し、`AppLocalizations` による日本語フォーマット（例: `2024年3月15日`）を返す。
  - `app/lib/features/novel_kakuyomu/presentation/work_detail_screen.dart:201-203` — `publishedAt!.toIso8601String()` を置換
  - `app/lib/features/novel_kakuyomu/presentation/latest_feed_screen.dart:96-97` — `publishedAt!.toLocal().toIso8601String()` を置換
- **ARB 文字列追加**: `app/lib/l10n/app_ja.arb` と `app/lib/l10n/app_en.arb` に日付フォーマット用のロケール文字列を追加（必要な場合）。
- **ユニットテスト追加**: `formatNovelDate` の動作テストを追加。`ErrorMessages.localize` のラップが正しく機能することの確認テスト（既存テストの補完）。

## Capabilities

### New Capabilities

- `novel-date-formatter`: `DateTime?` 値を AppLocalizations 経由で人間が読める日本語（+英語）表示文字列へ変換するユーティリティ。カクヨム作品詳細・最新フィード画面で使用する。

### Modified Capabilities

- `error-domain`: プレゼンテーション層がユーザー向けエラー文字列を表示する際、`ErrorMessages.localize` を必ず経由すること（生例外の `.toString()` や `$e`/`$err` 展開を直接 UI に表示してはならない）という requirement を追加。

## Non-goals

- ⑦（永久無効プレースホルダボタン・`policyVersion` デバッグ文言除去）はバッチ4でスコープ外。
- ⑨⑩⑪（破壊的操作ボタンの `colorScheme.error` 適用、タッチターゲット 48dp 化、設定セクションヘッダスタイル）はバッチ2でスコープ外。
- `intl` パッケージの `DateFormat` 導入や完全なタイムゾーン処理は行わない。シンプルな年月日表示に留める。
- 動画プレイヤー画面内の `$error` 展開（`app/lib/features/video/presentation/player_screen.dart:401`）はプレイヤーが独自の中間 UI を持つため今回スコープ外。

## Impact

- **変更ファイル（実装）**:
  - `app/lib/core/novel/utils/novel_date_formatter.dart`（新規）
  - `app/lib/features/video/presentation/home_section.dart`
  - `app/lib/features/audio/presentation/home_section.dart`
  - `app/lib/features/novel_narou/presentation/work_detail_screen.dart`
  - `app/lib/features/novel_kakuyomu/presentation/work_detail_screen.dart`
  - `app/lib/features/novel_kakuyomu/presentation/reader_screen.dart`
  - `app/lib/features/novel_kakuyomu/presentation/search_screen.dart`
  - `app/lib/features/novel_kakuyomu/presentation/latest_feed_screen.dart`
- **変更ファイル（l10n）**:
  - `app/lib/l10n/app_ja.arb`
  - `app/lib/l10n/app_en.arb`
  - `app/lib/l10n/app_localizations_ja.dart`（自動生成）
  - `app/lib/l10n/app_localizations_en.dart`（自動生成）
- **変更ファイル（テスト）**:
  - `app/test/core/novel/utils/novel_date_formatter_test.dart`（新規）
- **依存関係追加なし**: `intl` は既に依存済み。新規パッケージ不要。
- **破壊的変更なし**: 既存 API シグネチャを変えない。

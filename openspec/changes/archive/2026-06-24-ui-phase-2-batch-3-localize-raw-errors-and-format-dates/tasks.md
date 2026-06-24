## 1. ARB ローカライズ文字列の追加

- [x] 1.1 `app/lib/l10n/app_ja.arb` に `novelDateUnknown: "不明"` キーを追加する
- [x] 1.2 `app/lib/l10n/app_en.arb` に `novelDateUnknown: "Unknown"` キーを追加する

## 2. novel-date-formatter ユーティリティの実装

- [x] 2.1 `app/lib/core/novel/utils/novel_date_formatter.dart` を新規作成し、`formatNovelDate(DateTime? date, BuildContext context)` を実装する（`intl.DateFormat.yMMMd(locale)` + `novelDateUnknown` フォールバック）
- [x] 2.2 `app/test/core/novel/utils/novel_date_formatter_test.dart` を新規作成し、ja/en ロケールでの出力と null 入力のテストを追加する

## 3. カクヨム UI の日付表示修正

- [x] 3.1 `app/lib/features/novel_kakuyomu/presentation/work_detail_screen.dart:201-203` のエピソードリスト subtitle で `publishedAt!.toIso8601String()` を `formatNovelDate(publishedAt, context)` に置換する
- [x] 3.2 `app/lib/features/novel_kakuyomu/presentation/latest_feed_screen.dart:96-97` の最新フィード subtitle で `publishedAt!.toLocal().toIso8601String()` を `formatNovelDate(publishedAt, context)` に置換する

## 4. エラー表示 call site の修正（ErrorMessages.localize + UnknownError ラップ）

- [x] 4.1 `app/lib/features/video/presentation/home_section.dart:47` の `'読み込みに失敗しました: $e'` を `ErrorMessages.localize(UnknownError(e), context)` に置換する
- [x] 4.2 `app/lib/features/audio/presentation/home_section.dart:58` の `'読み込みに失敗しました: $e'` を `ErrorMessages.localize(UnknownError(e), context)` に置換する
- [x] 4.3 `app/lib/features/novel_narou/presentation/work_detail_screen.dart:168` の `'追加に失敗しました: $e'`（SnackBar）を `ErrorMessages.localize(UnknownError(e), context)` に置換する
- [x] 4.4 `app/lib/features/novel_kakuyomu/presentation/work_detail_screen.dart:92` の `'追加に失敗: $e'`（SnackBar）を `ErrorMessages.localize(UnknownError(e), context)` に置換する
- [x] 4.5 `app/lib/features/novel_kakuyomu/presentation/work_detail_screen.dart:129` の `Text('エラー: $err')` を `Text(ErrorMessages.localize(UnknownError(err), context))` に置換する
- [x] 4.6 `app/lib/features/novel_kakuyomu/presentation/reader_screen.dart:94` の `Text('エラー: $err')` を `Text(ErrorMessages.localize(UnknownError(err), context))` に置換する
- [x] 4.7 `app/lib/features/novel_kakuyomu/presentation/search_screen.dart:145` の `'エラーが発生しました: $err'` を `ErrorMessages.localize(UnknownError(err), context)` に置換する

## 5. CI 検証

- [x] 5.1 PR を作成して GitHub Actions の `analyze-and-test` ジョブが green になることを確認する（`dart format`・`flutter analyze --fatal-infos`・`flutter test` の全パス）— PR #54 で実施、`analyze-and-test` green、2026-06-20 に main へマージ済み（commit 2bbea2e）

# novel-date-formatter Specification

## Purpose
TBD - created by archiving change ui-phase-2-batch-3-localize-raw-errors-and-format-dates. Update Purpose after archive.
## Requirements
### Requirement: formatNovelDate がロケールに応じた日付文字列を返す

The system SHALL provide a top-level function `String formatNovelDate(DateTime? date, BuildContext context)` at `app/lib/core/novel/utils/novel_date_formatter.dart`. When `date` is non-null, the function MUST return a human-readable date string formatted with `intl.DateFormat.yMMMd(locale)` where `locale` is the string representation of `Localizations.localeOf(context)`. The formatted date MUST be in the local timezone (`date.toLocal()`). When `date` is null, the function MUST return the value of `AppLocalizations.of(context)?.novelDateUnknown`, falling back to the hard-coded string `'不明'` when `AppLocalizations.of(context)` returns null.

#### Scenario: 日本語ロケールで DateTime を整形する

- **WHEN** `formatNovelDate(DateTime(2024, 3, 15, 12, 0, 0), context)` が ja ロケールの `BuildContext` で呼ばれる
- **THEN** 戻り値は `'2024年3月15日'` である

#### Scenario: 英語ロケールで DateTime を整形する

- **WHEN** `formatNovelDate(DateTime(2024, 3, 15, 12, 0, 0), context)` が en ロケールの `BuildContext` で呼ばれる
- **THEN** 戻り値は `'Mar 15, 2024'` である

#### Scenario: null の場合はローカライズされた未知文字列を返す

- **GIVEN** `AppLocalizations.of(context)?.novelDateUnknown` が `'不明'` を返す ja ロケール環境
- **WHEN** `formatNovelDate(null, context)` が呼ばれる
- **THEN** 戻り値は `'不明'` である

#### Scenario: AppLocalizations が利用不可の場合にハードコードフォールバックを返す

- **GIVEN** `AppLocalizations.of(context)` が null を返す detached コンテキスト
- **WHEN** `formatNovelDate(null, context)` が呼ばれる
- **THEN** 戻り値は `'不明'` であり例外を投げない

### Requirement: novelDateUnknown ARB キーが ja・en の両ファイルに存在する

The system SHALL declare a `novelDateUnknown` key in `app/lib/l10n/app_ja.arb` with the Japanese value `'不明'` and in `app/lib/l10n/app_en.arb` with the English value `'Unknown'`. The generated `AppLocalizations` SHALL expose a getter `String get novelDateUnknown`.

#### Scenario: ARB ファイルに novelDateUnknown が存在する

- **WHEN** `app/lib/l10n/app_ja.arb` を JSON として読み込む
- **THEN** キー `"novelDateUnknown"` が存在し、値は `"不明"` である

#### Scenario: 生成された AppLocalizations が novelDateUnknown ゲッターを持つ

- **WHEN** `flutter gen-l10n`（相当）が ARB を処理する
- **THEN** 生成された `AppLocalizations` クラスは `String get novelDateUnknown` ゲッターを持ち、ja で `'不明'`、en で `'Unknown'` を返す

### Requirement: カクヨム UI が formatNovelDate を使用して日付を表示する

The system SHALL replace all direct `.toIso8601String()` calls used for UI date display in the Kakuyomu presentation layer with `formatNovelDate`. Specifically, `app/lib/features/novel_kakuyomu/presentation/work_detail_screen.dart` episode list subtitle and `app/lib/features/novel_kakuyomu/presentation/latest_feed_screen.dart` feed item subtitle SHALL use `formatNovelDate`.

#### Scenario: エピソード一覧でpublishedAtが人間可読形式で表示される

- **GIVEN** `KakuyomuEpisode.publishedAt` が `DateTime(2024, 3, 15)` である
- **WHEN** work_detail_screen のエピソード一覧が ja ロケールでレンダリングされる
- **THEN** エピソードの subtitle に `'2024年3月15日'` が表示され、ISO-8601 文字列は表示されない

#### Scenario: 最新フィードでpublishedAtが人間可読形式で表示される

- **GIVEN** `KakuyomuFeedItem.publishedAt` が `DateTime(2024, 3, 15)` である
- **WHEN** latest_feed_screen のフィードアイテムが ja ロケールでレンダリングされる
- **THEN** アイテムの日付表示に `'2024年3月15日'` が表示され、`.toIso8601String()` 相当の文字列は表示されない


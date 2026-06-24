## Context

GeekPlayer の UI Phase 2 バッチ3。`add-error-ux-infra` change で `AppError` 階層・`ErrorMessages.localize`・`showErrorToast`・`ErrorBanner` が整備されたが、以下のプレゼンテーション層 call site がそのインフラを使っておらず、生例外文字列 `$e`/`$err` をユーザーに直接表示している:

- `features/video/presentation/home_section.dart:47`
- `features/audio/presentation/home_section.dart:58`
- `features/novel_narou/presentation/work_detail_screen.dart:168`
- `features/novel_kakuyomu/presentation/work_detail_screen.dart:92,129`
- `features/novel_kakuyomu/presentation/reader_screen.dart:94`
- `features/novel_kakuyomu/presentation/search_screen.dart:145`

また、`KakuyomuEpisode.publishedAt`・`KakuyomuWork.lastUpdatedAt` は `DateTime?` として保持されているが、UI 上では `.toIso8601String()` をそのまま表示しており、ユーザーには非友好的な文字列が見える。

制約: ローカルに Flutter/Dart 環境がなく、CI（GitHub Actions `analyze-and-test`）が唯一のチェッカー。ARB を追加した場合は `flutter gen-l10n` の再生成が CI で行われる。

## Goals / Non-Goals

**Goals:**

1. 7 か所の生エラー call site を `ErrorMessages.localize` ＋ `UnknownError` ラップに置換する。
2. `app/lib/core/novel/utils/novel_date_formatter.dart` に `formatNovelDate(DateTime? date, BuildContext context)` を実装し、カクヨムの 2 call site で使用する。
3. ARB に `novelDateUnknown` キーを追加し、null 日付の表示文字列をローカライズする。
4. `formatNovelDate` のユニットテストを追加する。

**Non-Goals:**

- 新しい `AppError` サブクラスの追加（既存の `UnknownError` ラップで十分）。
- `intl` パッケージのタイムゾーン DB 完全サポートや相対時刻（「3 分前」など）。
- 動画プレイヤー画面内の `$error` 展開（`player_screen.dart:401`）—プレイヤー固有 UI を持つため別スコープ。
- バッチ4 対象の ⑦（プレースホルダボタン・`policyVersion` 文言除去）。

## Decisions

### D1: エラー call site の対処 — `UnknownError` ラップ

**選択**: 非 `AppError` な例外（`Object e`）を catch した call site では `UnknownError(e)` でラップして `ErrorMessages.localize` に渡す。新たな `AppError` サブクラスは追加しない。

**理由**: call site ごとに細粒度エラー型を起こすと、presentation → domain の依存が増え、既存スペックのインベントリとの乖離が大きくなる。`UnknownError` はその意図を明示しており、`AppErrorLogger` が `error` severity でログに残す。将来詳細化する際に呼び出し側だけ変えれば済む。

**代替案**: 各 call site に専用エラー型を定義 → 今のバッチでは過剰。 `ErrorMessages.localize` を呼ばず `l10n.errorUnknown` を直接使用 → `ErrorMessages` の契約を迂回するため却下。

### D2: 日付フォーマット — `intl.DateFormat.yMMMd(locale)` を直接使用

**選択**: `formatNovelDate` 内で `Localizations.localeOf(context).toString()` からロケール文字列を取得し、`intl` の `DateFormat.yMMMd(locale).format(date.toLocal())` を使用する。ARB にフォーマットパターン自体は持たせない。

**理由**: ARB はテキスト文字列のローカライズに適しているが、`DateFormat` パターン（`yMMMd` など）は `intl` ライブラリが ICU データに基づいて処理するため ARB 経由で冗長管理する必要がない。`intl: ^0.20.2` は既に依存済みであり、追加依存なし。出力例: ja → `2024年3月15日`、en → `Mar 15, 2024`。

**代替案**: ARB に `novelDateFormat: "{year}年{month}月{day}日"` のようなテンプレートを置く → 翻訳者が日付フォーマットを管理する必要が生じ保守性が低い。`DateTime.toLocal().toString().substring(0, 10)` → ロケール非対応のため却下。

### D3: null 日付の表示 — `novelDateUnknown` ARB キーを追加

**選択**: `date == null` の場合、`AppLocalizations.of(context)?.novelDateUnknown ?? '不明'` を返す。`novelDateUnknown` を `app_ja.arb` / `app_en.arb` に追加する。

**理由**: null 日付は稀だが、RSS に `pubDate` がないエントリなどで発生しうる。ハードコードは避けたいが、`fallback` として `'不明'` の日本語文字列を維持しておくことで、`AppLocalizations` が利用できない degraded コンテキストでも壊れない。

## Risks / Trade-offs

- **[Risk] ARB 追加による CI gen-l10n の失敗** → `app_en.arb` への `novelDateUnknown` 追加を忘れると `en` ロケールのビルドが失敗する。両ファイルへの追加を tasks でペアチェックする。
- **[Risk] `intl` の ICU ロケールデータが意図した形式を返さない** → `DateFormat.yMMMd('ja')` は `2024年3月15日` を返すことが Flutter の intl 実装で確認されている（ICU 標準）。テストでアサートして保護する。
- **[Risk] `Localizations.localeOf(context)` が test 環境で例外を投げる** → テストでは `MockBuildContext` または `MaterialApp` ウィジェット内でラップする。`formatNovelDate` が `BuildContext` を受け取る設計はテスト可能性に影響するが、既存の `ErrorMessages.localize` と同一パターンであり一貫性を優先する。
- **[Trade-off] `formatNovelDate` が `BuildContext` を要求する** → `context` なしで使いたい場面（例: provider 内）では使えない。ただしバッチ3 の用途（Widget ツリー内の presentation 層）には問題ない。

## Migration Plan

1. `app/lib/l10n/app_ja.arb` と `app/lib/l10n/app_en.arb` に `novelDateUnknown` を追加。
2. `app/lib/core/novel/utils/novel_date_formatter.dart` を新規作成。
3. `app/test/core/novel/utils/novel_date_formatter_test.dart` を新規作成。
4. カクヨム presentation の 2 call site（`work_detail_screen.dart`、`latest_feed_screen.dart`）を `formatNovelDate` に置換。
5. 7 か所のエラー call site を `ErrorMessages.localize` ＋ `UnknownError` ラップに置換。
6. CI で `dart format`・`flutter analyze`・`flutter test` を確認（`analyze-and-test` ジョブ）。

ロールバック: 通常の git revert で完結する（DB schema 変更・依存追加なし）。

## Open Questions

なし。スコープは issue #42 の ④⑥ に限定されており、既存インフラで実装可能。

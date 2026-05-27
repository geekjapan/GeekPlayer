## Why

v0.1 の 7 既存 change（[`add-local-video-playback`](../add-local-video-playback/proposal.md)、
[`add-local-audio-playback`](../add-local-audio-playback/proposal.md)、
[`add-online-novel-library`](../add-online-novel-library/proposal.md)、
[`add-narou-novel-reader`](../add-narou-novel-reader/proposal.md)、
[`add-kakuyomu-novel-reader`](../add-kakuyomu-novel-reader/proposal.md)、
[`add-app-settings`](../add-app-settings/proposal.md)、
[`add-about-and-licenses`](../add-about-and-licenses/proposal.md)）
が個別にエラー型・文言・トースト・例外処理を書き散らしている。具体例:

- ネットワーク系 sealed `NetworkError` を [`add-online-novel-library/tasks.md:14`](../add-online-novel-library/tasks.md) で `app/lib/core/network/errors.dart` に置くが、
  カクヨムは `KakuyomuUpstreamUnavailableException` / `KakuyomuParseException` / `KakuyomuEpisodeNotFoundException` を
  [`add-kakuyomu-novel-reader/tasks.md:15`](../add-kakuyomu-novel-reader/tasks.md) で `domain/exceptions.dart` に独自実装。
- なろうは `NarouResponseError` を [`add-narou-novel-reader/specs/narou-novel-source/spec.md:141`](../add-narou-novel-reader/specs/narou-novel-source/spec.md)
  で定義し、R18 リポジトリの consent 違反は `StateError` で代用（[`add-narou-novel-reader/tasks.md:32`](../add-narou-novel-reader/tasks.md)）。
- 動画/音楽は再生不能を「このファイルは再生できません」というハードコード文字列で表示するのみで
  ([`add-local-video-playback/specs/local-video-playback/spec.md:20`](../add-local-video-playback/specs/local-video-playback/spec.md),
   [`add-local-audio-playback/specs/local-audio-playback/spec.md:25`](../add-local-audio-playback/specs/local-audio-playback/spec.md))、型は持たない。
- app-settings は drift 読み取りで `AsyncError` を `Notifier` に流すと書くが
  ([`add-app-settings/specs/settings-persistence/spec.md:197`](../add-app-settings/specs/settings-persistence/spec.md))、
  どう表示するかは未定。
- トースト/バナー UI が全 change で未定義のため、apply 段階で各 change が `SnackBar` を直接組み立てる重複が確定している。

[`docs/GRILL-REPORT.md`](../../../docs/GRILL-REPORT.md) Q-GAP-001 で「共通 `AppError` 型 / トースト UI / 再試行 UX を別 change として
`add-error-ux-infra` で立てる」がユーザー判断として確定済み。本 change はその受け皿として、apply 着手前に
共通基盤を据える（=後続 7 change の apply で型・文言・UI を流用できる状態にする）。

## What Changes

- **新規**: `sealed class AppError` を [`app/lib/core/errors/app_error.dart`](../../../app/lib/core/errors/app_error.dart)
  に定義し、既存 7 change のエラー文脈を網羅する 10 variant
  （`NetworkUnreachableError` / `RateLimitError` / `SiteConsentRequiredError` / `RobotsDisallowedError` /
  `HtmlParseError` / `FileNotFoundError` / `UnsupportedFormatError` / `UpstreamUnavailableError` /
  `StorageQuotaError` / `UnknownError`）を提供する。各 variant は `String message` を持ち、
  optional に `Object? cause` / `StackTrace? stackTrace` を保持する。
- **新規**: ja-first 文言マッピング `ErrorMessages.localize(AppError, BuildContext)` を
  [`app/lib/core/errors/error_messages.dart`](../../../app/lib/core/errors/error_messages.dart) に提供。
  v0.1 は `app_ja.arb` 直結、`intl` 骨組みのみ用意（en は v0.2 の `add-english-localization` で書く）。
- **新規**: `ErrorToast` / `ErrorBanner` ウィジェットを
  [`app/lib/core/errors/error_toast.dart`](../../../app/lib/core/errors/error_toast.dart) /
  [`app/lib/core/errors/error_banner.dart`](../../../app/lib/core/errors/error_banner.dart) に実装。
  Material 3 の `SnackBar` ベース、severity (`info` / `warning` / `error`) で配色を切り替える。
  `showErrorToast(BuildContext, AppError)` のグローバル便利関数を提供。
- **新規**: `ErrorBoundary` ウィジェットを
  [`app/lib/core/errors/error_boundary.dart`](../../../app/lib/core/errors/error_boundary.dart) に実装し、
  Flutter の `ErrorWidget.builder` をオーバーライドしてリリースビルドでも赤いクラッシュ画面の代わりに
  `ErrorBanner` を表示する。debug build では既定の `ErrorWidget` を尊重する（開発体験を保つ）。
- **新規**: リトライ戦略抽象 `RetryStrategy` を
  [`app/lib/core/errors/retry_strategy.dart`](../../../app/lib/core/errors/retry_strategy.dart) に定義
  （`indefinite` / `bounded(maxAttempts)` / `none`）し、便利関数 `withRetry<T>(future, strategy)` で
  指数バックオフ (1s/2s/4s/...、上限 5min、±20% jitter、`Retry-After` 優先) を実装。
  既存 [`responsible-fetching/spec.md`](../add-online-novel-library/specs/responsible-fetching/spec.md)
  と整合する数値を採用する。
- **新規**: ロガー連携。`logger` パッケージ経由で `AppError` を構造化ログ出力するヘルパ
  `AppErrorLogger.log(AppError)` を
  [`app/lib/core/errors/app_error_logger.dart`](../../../app/lib/core/errors/app_error_logger.dart) に置く。
- **後続 change への注記** (本 change では他 change のファイルを編集しない): apply 順序の最後に、
  各 change の design.md / tasks.md が定義している `*Exception` / `*Error` を `AppError` の対応 variant に
  詰め替えるリファクタリングを後続 change として起案する（例: `KakuyomuUpstreamUnavailableException` →
  `UpstreamUnavailableError`、`RobotsDisallowedException` → `RobotsDisallowedError`、`SiteConsentDeniedException` →
  `SiteConsentRequiredError`）。本 change の design.md にこの「後続再配線計画」を記載する。

## Capabilities

### New Capabilities

- `error-domain`: 共通 `sealed class AppError` 階層と全 variant、`cause` / `stackTrace` の保持、equality /
  hashCode、ロガー連携を定義する。`core/errors/` 配下の型システムの中心。
- `error-ux-widgets`: `ErrorToast` / `ErrorBanner` / `ErrorBoundary` ウィジェットと表示挙動を定義する。
  severity 別配色、自動 dismiss、`SnackBar` queue 管理、リリースビルドでのクラッシュフォールバックを含む。
- `retry-strategy`: `RetryStrategy` sealed 階層と `withRetry<T>` 便利関数を定義する。指数バックオフのデフォルト、
  429 / 503 ハンドリング、`Retry-After` 優先、jitter を含む。

### Modified Capabilities

（なし — 本 change は新規 capability のみ追加し、既存 7 change の spec を書き換えない）

## Impact

**新規ディレクトリ / ファイル:**

- `app/lib/core/errors/app_error.dart` — sealed `AppError` 階層と 10 variant
- `app/lib/core/errors/error_messages.dart` — `ErrorMessages.localize(AppError, BuildContext)` と ja マッピング
- `app/lib/core/errors/error_toast.dart` — `ErrorToast` / `showErrorToast(...)`
- `app/lib/core/errors/error_banner.dart` — `ErrorBanner` (severity 別配色)
- `app/lib/core/errors/error_boundary.dart` — `ErrorBoundary` ウィジェット + `ErrorWidget.builder` 差し替え
- `app/lib/core/errors/retry_strategy.dart` — `RetryStrategy` sealed + `withRetry<T>` + jitter
- `app/lib/core/errors/app_error_logger.dart` — `logger` パッケージ連携のヘルパ
- `app/lib/l10n/app_ja.arb` — `error.*` キー群（`error.networkUnreachable`、`error.rateLimit` 等）
- `app/lib/l10n/l10n.yaml` — `intl` 骨組み（v0.1 では ja のみ）
- `app/test/core/errors/` — 各ファイルに対応するユニット/ウィジェットテスト

**変更:**

- `app/pubspec.yaml` — `logger ^2.5.0` を追加（既に追加済みでなければ）、`intl` (Flutter SDK 経由) と `flutter_localizations` を追加、
  `riverpod_generator` の利用は本 change の範囲外（[GRILL-REPORT Q-GAP-002](../../../docs/GRILL-REPORT.md) は別途）

**プラットフォーム影響:**

- なし。本 change は drift スキーマに触らない（schema v3 のまま）。AndroidManifest / Info.plist / entitlements
  も触らない。
- 状態管理は Riverpod v3 (`@Riverpod` codegen)。`ErrorBoundary` 周辺の Provider は codegen `*.g.dart` を生成する。

**Non-goals:**

- **クラッシュレポート送信**: Sentry / Firebase Crashlytics 連携は v0.2 以降。本 change は構造化ログを
  `logger` パッケージのコンソール出力に流すまでで、サーバ送信はしない。
- **ネットワーク状態の自動再接続検知**: OS の `Connectivity` API（`connectivity_plus` 等）連携は v0.2 で別 change。
  本 change の `NetworkUnreachableError` はリトライ戦略の発火点としてのみ機能し、自動再試行の仕組みは持たない。
- **ユーザー向けエラー報告フォーム**: アプリ内から「このエラーを報告」する UI は v1.0 以降。
- **英語ローカライゼーション**: v0.1 は ja のみ。`intl` の `app_ja.arb` 骨組みだけ用意し、`app_en.arb` は
  v0.2 の `add-english-localization` change で書く。
- **既存 7 change の再配線**: 本 change は新規 ファイルを置くだけで、既存 change の design.md / tasks.md /
  spec.md を編集しない。再配線は本 change の apply 完了後、別の `refactor-route-errors-through-app-error` 等の
  change で行う（design.md の「後続再配線計画」セクション参照）。
- **drift スキーマ変更**: 本 change は DB に触らない。
- **Riverpod v2 互換**: pubspec が既に v3 で固定されているため、v2 API への戻し対応は提供しない。

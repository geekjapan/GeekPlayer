## Context

GeekPlayer v0.1 の 7 既存 change がエラー文脈を個別に書いている。代表的な参照:

- ネットワーク系: `RobotsDisallowedError` / `RateLimitExceededError` / `NetworkUnreachableError`
  ([`add-online-novel-library/tasks.md:14`](../add-online-novel-library/tasks.md))
- 小説リポジトリ系: `SiteConsentRequiredError` / `HtmlParseError` / `WorkNotFoundError` / `EpisodeNotFoundError`
  ([`add-online-novel-library/tasks.md:26`](../add-online-novel-library/tasks.md))
- カクヨム固有: `KakuyomuUpstreamUnavailableException` / `KakuyomuParseException` /
  `KakuyomuEpisodeNotFoundException` / `RobotsDisallowedException` / `SiteConsentDeniedException`
  ([`add-kakuyomu-novel-reader/tasks.md:15`](../add-kakuyomu-novel-reader/tasks.md))
- なろう固有: `NarouResponseError`、R18 consent 違反は `StateError` で代用
  ([`add-narou-novel-reader/specs/narou-novel-source/spec.md:141`](../add-narou-novel-reader/specs/narou-novel-source/spec.md))
- 動画/音楽: 型を持たず「このファイルは再生できません」というハードコード文字列のみ
  ([`add-local-video-playback/specs/local-video-playback/spec.md:20`](../add-local-video-playback/specs/local-video-playback/spec.md),
   [`add-local-audio-playback/specs/local-audio-playback/spec.md:25`](../add-local-audio-playback/specs/local-audio-playback/spec.md))
- 設定永続化: `FormatException` を投げ、`AsyncError` を `Notifier` に流す
  ([`add-app-settings/specs/settings-persistence/spec.md:100`](../add-app-settings/specs/settings-persistence/spec.md))

問題:

1. 同じ意味の例外型（カクヨム `RobotsDisallowedException` と novel-library `RobotsDisallowedError`）が
   別ファイル/別命名で重複する。
2. UI 側がエラー表示を共通化していないため、各 change で `SnackBar` 直書きが発生する。
3. リリースビルドで `ErrorWidget.builder` の差し替えが無く、ウィジェット build エラーが赤画面で出る。
4. リトライ戦略が責任分散しており、`add-online-novel-library/specs/responsible-fetching/spec.md` の
   指数バックオフを各 change が独自実装する恐れがある。

採用済みの前提:

- 状態管理は **Riverpod v3 (`@Riverpod` codegen)** ([HANDOFF.md §2](../../../docs/HANDOFF.md))
- データ永続化は単一 drift DB、本 change は schema v3 を**触らない**
- UI 言語は ja-first、`intl` 骨組みのみ用意（en は v0.2）
- ログは `logger` パッケージ（pubspec 既存 / 未追加なら本 change で追加）

## Goals / Non-Goals

**Goals:**

- 既存 7 change が触れているエラー文脈を網羅する `sealed class AppError` を提供し、
  後続 change がそれぞれの `*Exception` / `*Error` を `AppError` の variant に詰め替えられる状態にする。
- `ErrorToast` / `ErrorBanner` / `ErrorBoundary` を Material 3 で統一実装し、severity 別配色で一貫した UX を提供する。
- リリースビルドでウィジェット build エラーが起きた時、赤い `ErrorWidget` の代わりに `ErrorBanner` にフォールバックする
  （debug ビルドでは既定の挙動を維持して開発体験を保つ）。
- リトライ戦略 `RetryStrategy` を共通抽象化し、`responsible-fetching` の指数バックオフ実装の重複を防ぐ。
- `intl` 骨組みを `app/lib/l10n/` に置き、ja-first の文言を `app_ja.arb` 経由で localize する。
- 構造化ログ出力で `AppError` の `cause` / `stackTrace` を `logger` パッケージに流す。

**Non-Goals:**

- クラッシュレポート送信 (Sentry / Crashlytics) — v0.2 以降
- ネットワーク状態の自動再接続検知 (`connectivity_plus`) — v0.2 以降
- ユーザー向けエラー報告フォーム — v1.0
- 英語ローカライゼーション — v0.2 の `add-english-localization`
- 既存 7 change の `*Exception` / `*Error` を実際に `AppError` に詰め替えるリファクタリング — 本 change は
  受け皿を置くだけ。詰め替えは後続 change（仮称 `refactor-route-errors-through-app-error`）で実施
- drift スキーマ変更
- Riverpod v2 への後方互換 API

## Decisions

### D1. `AppError` を sealed class、10 variant を `core/errors/app_error.dart` に集約

Dart 3 の `sealed class` で `exhaustive switch` を効かせる。同一ライブラリ内に全 variant を置く方針
（[GRILL-REPORT Q-CROSS-011](../../../docs/GRILL-REPORT.md) で `MediaSession` に対して同じ結論済み）。
ただし `AppError` は variant 数が 10 と少なく、また各 variant がプロパティを 1〜2 個しか持たないため、
`MediaSession` のような `part of` 分割はせず **1 ファイルに同居** させる。

```dart
sealed class AppError implements Exception {
  const AppError(this.message, {this.cause, this.stackTrace});
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
}

final class NetworkUnreachableError extends AppError { ... }
final class RateLimitError extends AppError {
  const RateLimitError({required String message, this.retryAfter, ...}) : super(...);
  final Duration? retryAfter;
}
final class SiteConsentRequiredError extends AppError {
  const SiteConsentRequiredError({required this.site, ...}) : super(...);
  final String site; // 'narou' | 'noc' | 'kakuyomu' 等。enum 化は novel-library に依存しすぎるので String
}
final class RobotsDisallowedError extends AppError { final String path; ... }
final class HtmlParseError extends AppError { final String? sourceUrl; ... }
final class FileNotFoundError extends AppError { final Uri uri; ... }
final class UnsupportedFormatError extends AppError { final String? extension; ... }
final class UpstreamUnavailableError extends AppError { final int? statusCode; ... }
final class StorageQuotaError extends AppError { final int? requestedBytes; ... }
final class UnknownError extends AppError {
  const UnknownError(Object original, {StackTrace? stackTrace})
    : super(original.toString(), cause: original, stackTrace: stackTrace);
}
```

**equality / hashCode**: 値オブジェクト的に振る舞わせるため、`message` + variant-specific プロパティの
タプルで `==` / `hashCode` を実装する。`cause` / `stackTrace` は equality 対象外（実体が変わる）。

**代替案 A: `Failure` / `Result<T, E>` 型を導入**
→ Dart の `try` / `catch` イディオムと相性が悪く、既存 7 change が `throw` 前提で書かれているため
コスト高。`AppError implements Exception` で素直に `throw` できる路線を採る。

**代替案 B: variant ごとにファイル分割**
→ `part of` を強制するか、`abstract base` にして別ライブラリに置く必要があり、後者は
exhaustive switch を失う。variant 数 10 程度なら 1 ファイルで管理可能。

### D2. ja-first 文言は `intl` の ARB 経由、フォールバックは `AppError.message`

`app/lib/l10n/app_ja.arb` に `error.networkUnreachable` 等のキーを置き、
`AppLocalizations.of(context)!.errorNetworkUnreachable` で参照する。`ErrorMessages.localize(AppError, BuildContext)`
は switch で variant ごとに対応する getter を呼ぶ:

```dart
String localize(AppError error, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return switch (error) {
    NetworkUnreachableError() => l10n.errorNetworkUnreachable,
    RateLimitError(:final retryAfter) => l10n.errorRateLimit(retryAfter?.inSeconds ?? 0),
    SiteConsentRequiredError(:final site) => l10n.errorSiteConsentRequired(site),
    RobotsDisallowedError() => l10n.errorRobotsDisallowed,
    HtmlParseError() => l10n.errorHtmlParse,
    FileNotFoundError() => l10n.errorFileNotFound,
    UnsupportedFormatError() => l10n.errorUnsupportedFormat,
    UpstreamUnavailableError() => l10n.errorUpstreamUnavailable,
    StorageQuotaError() => l10n.errorStorageQuota,
    UnknownError() => l10n.errorUnknown,
  };
}
```

**フォールバック**: `BuildContext` が `Element` から外れる場面（`ErrorBoundary` の `ErrorWidget.builder`
内など）で `AppLocalizations.of(context)` が null になる可能性があるため、null の時は
`error.message` を直接表示する。

**v0.2 で en を足す時の負債**: `app_en.arb` を追加して `MaterialApp.supportedLocales` を更新するだけで
良いように、ハードコード文字列を `AppLocalizations` 経由に統一する。

### D3. `ErrorToast` と `ErrorBanner` は Material 3 `SnackBar` ベース、severity 別配色

```dart
enum ErrorSeverity { info, warning, error }

ErrorSeverity severityOf(AppError error) => switch (error) {
  RateLimitError() => ErrorSeverity.warning,
  SiteConsentRequiredError() => ErrorSeverity.warning,
  RobotsDisallowedError() => ErrorSeverity.error,
  HtmlParseError() => ErrorSeverity.warning,
  NetworkUnreachableError() => ErrorSeverity.warning,
  UpstreamUnavailableError() => ErrorSeverity.warning,
  FileNotFoundError() => ErrorSeverity.error,
  UnsupportedFormatError() => ErrorSeverity.error,
  StorageQuotaError() => ErrorSeverity.error,
  UnknownError() => ErrorSeverity.error,
};
```

配色は `ColorScheme.errorContainer` / `ColorScheme.tertiaryContainer` を warning に使う Material 3 慣用。
`ErrorToast` は短文・自動 dismiss (4s) で `ScaffoldMessenger.showSnackBar`、`ErrorBanner` は永続表示
（`MaterialBanner` または top-of-screen 永続 UI）で「リトライ」「閉じる」アクションを持つ。

**便利関数**: グローバルに `void showErrorToast(BuildContext context, AppError error, {VoidCallback? onRetry})`
を提供。Riverpod の `ProviderObserver` から呼べるよう、`ScaffoldMessengerKey` を `core/errors/scaffold_messenger_key.dart`
で global Provider 化する。

**代替案: トースト専用パッケージ (`fluttertoast` 等)**
→ Material 3 と統一感のある SnackBar をベースにしたい、依存追加を抑えたい、という理由で
標準 `ScaffoldMessenger` を選択。

### D4. `ErrorBoundary` は `ErrorWidget.builder` を差し替え、リリースビルドのみ作動

```dart
class ErrorBoundary extends StatelessWidget {
  const ErrorBoundary({required this.child, super.key});
  final Widget child;

  static void install() {
    final defaultBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (FlutterErrorDetails details) {
      if (kReleaseMode) {
        return _ReleaseErrorFallback(details: details);
      }
      return defaultBuilder(details);
    };
  }
  ...
}
```

`main.dart` の `runApp` 直前に `ErrorBoundary.install()` を呼ぶ。`_ReleaseErrorFallback` は
`ErrorBanner` と類似の見た目で「アプリを再起動してください」相当のメッセージを表示。

**Risk** ([Risks](#risks--trade-offs) 参照): リリースビルドで Flutter フレームワーク内部のエラーを握りつぶす
副作用がある。クラッシュ自体は止まらず、その範囲だけ赤画面が出ない、という挙動になる。

**代替案: `runZonedGuarded` で全例外を catch**
→ ウィジェット build エラーは `runZonedGuarded` では捕まらない（Flutter の `FlutterError.onError` 経由）
ため目的が違う。`runZonedGuarded` は `main.dart` 側の async 例外捕捉用に **併用** する
（tasks に明示）。

### D5. `RetryStrategy` は sealed、`withRetry<T>` は Dio に依存しない

```dart
sealed class RetryStrategy {
  const RetryStrategy();
  const factory RetryStrategy.indefinite() = _Indefinite;
  const factory RetryStrategy.bounded(int maxAttempts) = _Bounded;
  const factory RetryStrategy.none() = _None;
}

Future<T> withRetry<T>(
  Future<T> Function() task,
  RetryStrategy strategy, {
  Duration initialDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(minutes: 5),
  double jitter = 0.2,
  bool Function(Object error)? shouldRetry,
}) async { ... }
```

`shouldRetry` のデフォルトは「`RateLimitError` / `UpstreamUnavailableError` / `NetworkUnreachableError`
なら true、それ以外は false」。`RateLimitError.retryAfter` が設定されていれば指数バックオフを上書きする
（[`responsible-fetching/spec.md` Retry-After 仕様](../add-online-novel-library/specs/responsible-fetching/spec.md) と整合）。

**Dio 非依存**: `withRetry` は `Future<T> Function()` を受けるだけで、Dio interceptor とは独立。
カクヨムの Dio interceptor ([`add-kakuyomu-novel-reader/tasks.md:22`](../add-kakuyomu-novel-reader/tasks.md))
は本 change の `withRetry` を使う側に書き換える方が望ましいが、その再配線は後続 change のスコープ。

### D6. Riverpod v3 codegen 整合

`*.g.dart` 生成を伴うのは `scaffoldMessengerKeyProvider` と `errorObserverProvider` の 2 つ。
[GRILL-REPORT Q-CROSS-014](../../../docs/GRILL-REPORT.md) で確定済みの `@Riverpod` 注釈で書き、
`flutter pub run build_runner build --delete-conflicting-outputs` を tasks に含める。

```dart
@Riverpod(keepAlive: true)
GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey(Ref ref) =>
    GlobalKey<ScaffoldMessengerState>();
```

`AppErrorLogger` は Riverpod に乗せず純粋なヘルパクラスにする（DI の必要が薄い、`logger` パッケージは
シングルトンで十分）。

### D7. ロガー連携の構造化フォーマット

`AppErrorLogger.log(AppError error)` は次の JSON-like フォーマットで `logger` パッケージに流す:

```
{
  "type": "RobotsDisallowedError",
  "message": "robots.txt disallows /private/",
  "path": "/private/page",
  "cause": "DioException: ...",
  "stackTrace": "..."
}
```

`logger` の `Logger.e(...)` / `Logger.w(...)` を severity に応じて呼び分け、`PrettyPrinter` の出力で
開発時の可読性を保つ。リリースビルドでは `SimplePrinter` に切り替える（不要な装飾を削減）。

### D8. ファイル配置と依存方向

```
app/lib/core/errors/
├── app_error.dart            # sealed AppError + 10 variants
├── app_error_logger.dart     # logger パッケージ連携
├── error_messages.dart       # localize(AppError, BuildContext)
├── error_toast.dart          # showErrorToast(...) と ErrorToast widget
├── error_banner.dart         # ErrorBanner widget
├── error_boundary.dart       # ErrorBoundary widget + ErrorWidget.builder install
├── retry_strategy.dart       # sealed RetryStrategy + withRetry<T>
└── scaffold_messenger_key.dart  # Riverpod provider + GlobalKey
```

依存方向: `core/errors/` は何にも依存しない（Flutter SDK / `logger` / `intl` / `flutter_riverpod` のみ）。
`features/*/` と他の `core/*/` はすべて `core/errors/` に依存できる。
逆方向の依存は禁止（特に `core/network/`, `core/storage/`, `features/*/` から `core/errors/` への一方通行）。

## Risks / Trade-offs

- **[過剰抽象化リスク]** 既存 7 change が各々の error を `AppError` に詰める時、site-specific な情報
  （カクヨムの `parse failure location`、なろうの `ncode`、ファイルの `MIME type` 等）が痩せる可能性。
  → **Mitigation**: variant ごとに optional `Map<String, Object?>? extras` フィールドを追加することは
  **しない**（型安全を捨てるため）。代わりに、よく使われる site-specific 情報は variant の named
  parameter として明示的に追加する（例: `HtmlParseError.sourceUrl`、`RateLimitError.retryAfter`）。
  詰め替え時に表現できない情報は `cause` フィールドに元の Exception を保持して救う。
- **[ja-first 文言マッピングの保守性]** ARB ファイルと variant の対応がずれると気付きにくい。
  → **Mitigation**: `error_messages_test.dart` で「全 variant について `localize` が空文字列でないこと」を
  検証するテストを書く。`AppError` のサブタイプ追加時はテストが必ず落ちる。
- **[Riverpod v3 codegen との相性]** `@Riverpod` 注釈は build_runner 実行が必要で、本 change を apply する
  CI が `build_runner build --delete-conflicting-outputs` を走らせる必要がある。
  → **Mitigation**: tasks に `flutter pub run build_runner build --delete-conflicting-outputs` を明示。
  既存 7 change と同じ build_runner ワークフローに乗る。
- **[`ErrorBoundary` が release build で意図せず crash を握りつぶす可能性]** `ErrorWidget.builder` の
  差し替えは「赤い画面を出さない」だけで、Flutter framework 内部のエラー（例: `Element.activate` 内の
  RangeError）は依然発生する。状態的にアプリは壊れているが見た目だけ普通になる、というワーストパターンがある。
  → **Mitigation**:
  - リリースビルドで `_ReleaseErrorFallback` を表示した時、`AppErrorLogger.log` で `UnknownError` として
    必ず構造化ログに残す。
  - `_ReleaseErrorFallback` には「アプリを再起動」ボタンを常設し、ユーザーが立て直せるパスを提供。
  - 単体テストで「`ErrorWidget.builder` 差し替えが debug 時に作動しない」「release 時のみ作動する」を
    `kReleaseMode` モックで検証。
  - `runZonedGuarded` で `main` を包み、ウィジェット build 以外の async 例外も拾って `AppErrorLogger` に流す。
- **[Material 3 SnackBar の queue 挙動]** 連続して `showErrorToast` を呼ぶと `SnackBar` が queue されて
  順番に表示されるが、同じエラーが連発した時はユーザーが鬱陶しい。
  → **Mitigation**: `showErrorToast` 内で「直近 1 秒以内に同一 `AppError` 型 + `message` のトーストが
  出ていれば次は出さない」 deduplication ロジックを `scaffoldMessengerKeyProvider` を介して入れる。
- **[`RateLimitError.retryAfter` と `withRetry` の二重制御]** `withRetry` が指数バックオフを計算するが、
  実際に `Retry-After` を尊重するのは Dio interceptor 側で済んでいる可能性があり、二重に待つリスク。
  → **Mitigation**: `withRetry` のドキュメントに「Dio interceptor 層で `Retry-After` を既に処理している
  場合、`shouldRetry` で `RateLimitError` を false にして再試行を抑止せよ」と明記。後続再配線 change で
  カクヨム interceptor の挙動を整合させる。
- **[`UnknownError(original)` の濫用]** 全 catch 節が `UnknownError(e)` を投げてしまうと型情報が失われる。
  → **Mitigation**: lint ルールではなく、design の「変換は最も近い variant を選ぶ。`UnknownError` は
  `UnknownError` 以外に該当しない場合のみ」と明記し、後続再配線 change のレビューで担保する。

## Migration Plan

- **本 change のロールフォワード**: 新規ファイルを追加するのみで、既存 7 change の出力ファイルには触らない。
  apply 中に `flutter analyze` / `flutter test` がクリーンであることのみ確認する。
- **本 change のロールバック**: `app/lib/core/errors/` ディレクトリと `app/lib/l10n/` の新規ファイル、
  `pubspec.yaml` の `logger` / `flutter_localizations` 追加分をリバートすれば元に戻る。既存 change の
  ファイルは変更していないため安全。
- **後続再配線計画**: 本 change の apply 完了後、別途 `refactor-route-errors-through-app-error` change を
  起案し、以下の詰め替えを行う:
  - `RobotsDisallowedError` (novel-library) と `RobotsDisallowedException` (kakuyomu) を `AppError.RobotsDisallowedError` に統合
  - `RateLimitExceededError` (novel-library) を `AppError.RateLimitError` に統合
  - `KakuyomuUpstreamUnavailableException` を `AppError.UpstreamUnavailableError` に詰め替え
  - `KakuyomuParseException` / `HtmlParseError` を `AppError.HtmlParseError` に統合
  - `KakuyomuEpisodeNotFoundException` / `EpisodeNotFoundError` を `AppError.FileNotFoundError` または新規 variant
    （`ResourceNotFoundError`）に統合 — 詳細は後続 change で議論
  - `SiteConsentDeniedException` (kakuyomu) / `SiteConsentRequiredError` (novel-library) を統合
  - 動画/音楽の「このファイルは再生できません」を `UnsupportedFormatError` の throw → `showErrorToast` 表示に置換
  - 各 site / feature の UI 層が `try { ... } on AppError catch (e) { showErrorToast(context, e); }` のパターンに統一

## Open Questions

- **Q-D1**: `EpisodeNotFoundError` / `WorkNotFoundError` (novel-library 由来) を `AppError` の `FileNotFoundError`
  variant に統合するか、別 variant (`ResourceNotFoundError`) を切るか? 後続再配線 change の論点なので、
  本 change では `FileNotFoundError` のみ提供し、後続 change で再評価する。
- **Q-D2**: `StorageQuotaError` は v0.1 で発火するシナリオがあるか? drift DB はディスク容量に依存するが
  v0.1 範囲では検出しない。variant としては定義するが、初期は誰も throw しない（後続のキャッシュ管理 change で使う）。
- **Q-D3**: `ErrorBanner` の「リトライ」ボタンが押された時、Notifier 側の再実行をどうトリガーするか?
  `onRetry: VoidCallback?` を受け取る素直な設計でいくが、各 feature の Notifier が再実行ロジックを持つ必要がある。
  これは後続 change の責務とし、本 change では callback の受け渡しだけ提供する。
- **Q-D4**: `app_ja.arb` の key naming は `error.networkUnreachable` のドット区切りか
  `errorNetworkUnreachable` のキャメルケースか? Flutter `intl` の慣用に従い **キャメルケース** を採用
  （生成された Dart getter 名と一致するため）。

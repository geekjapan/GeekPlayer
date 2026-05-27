> **Conventions**: [docs/CONVENTIONS.md](../../../docs/CONVENTIONS.md) を着手前に読むこと。
> 本 change は HomeScreen には触らず、`app/lib/core/errors/` のみを成立させる。

## 1. 依存と l10n 骨組み

- [x] 1.1 `app/pubspec.yaml` に `logger ^2.5.0` を `flutter pub add` で追加（冪等: 既に存在すればバージョンだけ揃える）
- [x] 1.2 `app/pubspec.yaml` に `flutter_localizations: { sdk: flutter }` と `intl ^0.20.0` を追加し、`flutter.generate: true` を有効化
- [x] 1.3 `app/lib/l10n/l10n.yaml` を作成（`arb-dir: lib/l10n`, `template-arb-file: app_ja.arb`, `output-localization-file: app_localizations.dart`, `output-class: AppLocalizations`） — 実際の配置は `app/l10n.yaml`（Flutter `gen-l10n` の規約により project root 必須）
- [x] 1.4 `app/lib/l10n/app_ja.arb` に 10 個の `error*` キー（`errorNetworkUnreachable`, `errorRateLimit`, `errorSiteConsentRequired`, `errorRobotsDisallowed`, `errorHtmlParse`, `errorFileNotFound`, `errorUnsupportedFormat`, `errorUpstreamUnavailable`, `errorStorageQuota`, `errorUnknown`）と「再試行」「アプリを再起動してください」を ja 文言で追加。`errorRateLimit` と `errorSiteConsentRequired` はプレースホルダ付き
- [x] 1.5 `flutter pub get` を実行し `AppLocalizations` の生成物が `app/lib/l10n/app_localizations.dart` に出力されることを確認
- [x] 1.6 `flutter analyze` がクリーン

## 2. AppError ドメイン (`core/errors/app_error.dart`)

- [x] 2.1 `app/lib/core/errors/app_error.dart` に `sealed class AppError implements Exception` を定義（`message` / `cause` / `stackTrace` フィールド + `const` constructor + `toString()`）
- [x] 2.2 同ファイルに 10 個の `final class` variant を追加（`NetworkUnreachableError`, `RateLimitError`（`Duration? retryAfter`）, `SiteConsentRequiredError`（`String site`）, `RobotsDisallowedError`（`String path`）, `HtmlParseError`（`String? sourceUrl`）, `FileNotFoundError`（`Uri uri`）, `UnsupportedFormatError`（`String? extension`）, `UpstreamUnavailableError`（`int? statusCode`）, `StorageQuotaError`（`int? requestedBytes`）, `UnknownError`）
- [x] 2.3 各 variant に `==` / `hashCode` を実装（`runtimeType` + `message` + variant 固有フィールド、`cause` / `stackTrace` は除外）
- [x] 2.4 `UnknownError(Object original, {StackTrace? stackTrace})` ファクトリで `super(original.toString(), cause: original, stackTrace: stackTrace)` を呼ぶ
- [x] 2.5 `app/test/core/errors/app_error_test.dart` に各 variant の構築・equality・hashCode・`toString()` のユニットテストを追加
- [x] 2.6 `app/test/core/errors/app_error_exhaustive_switch_test.dart` で `switch (error)` over `AppError` が 10 variant 全網羅でコンパイルすることをコンパイル時に保証する関数を書く（実行時には trivial に true を返すだけで OK）
- [x] 2.7 `app/test/core/errors/dependency_direction_test.dart` を追加: `app/lib/core/errors/` 配下の全 `.dart` ファイルの import 文を `Process.run('grep', ...)` 等で走査し、禁止プレフィックス（`package:geekplayer/core/network/`, `core/storage/`, `core/media/`, `core/novel/`, `features/`）が現れたら fail

## 3. AppErrorLogger と severity マッピング

- [x] 3.1 `app/lib/core/errors/app_error_logger.dart` に `class AppErrorLogger { static void log(AppError error) { ... } }` を実装。内部で `Logger` シングルトンを保持し、severity に応じて `Logger.e` / `Logger.w` / `Logger.i` を呼び分け
- [x] 3.2 構造化ログのフォーマット（`type` / `message` / 各 variant 固有フィールド / `cause` / `stackTrace`）を `Map<String, Object?>` に組み立てるヘルパ関数を内部実装
- [x] 3.3 リリースビルドでは `SimplePrinter`、デバッグでは `PrettyPrinter` を使い分ける（`kReleaseMode` で判定）
- [x] 3.4 `app/lib/core/errors/error_banner.dart` （まだファイルが無ければ作成）に `enum ErrorSeverity { info, warning, error }` と top-level `ErrorSeverity severityOf(AppError error)` を実装（exhaustive switch、design.md D3 のマッピング）
- [x] 3.5 `app/test/core/errors/app_error_logger_test.dart` で `Logger` をモック（`mocktail` の `Mock` で `Logger` をフェイク）し、`UnknownError` が `Level.error` で / `RateLimitError` が `Level.warning` で logged されることを検証
- [x] 3.6 `app/test/core/errors/severity_of_test.dart` で 10 variant それぞれの `severityOf` 戻り値を assert

## 4. ErrorMessages ローカライザ

- [x] 4.1 `app/lib/core/errors/error_messages.dart` に `class ErrorMessages { static String localize(AppError error, BuildContext context) { ... } }` を実装。`AppLocalizations.of(context)` が null の時は `error.message` を返す fallback を実装
- [x] 4.2 全 10 variant について `localize` の exhaustive switch を実装し、`RateLimitError.retryAfter` などのプレースホルダ展開を l10n 経由で行う
- [x] 4.3 `app/test/core/errors/error_messages_test.dart` で全 10 variant に対する `localize` 結果が non-empty であることを `MaterialApp` を pump して確認
- [x] 4.4 `RateLimitError(retryAfter: Duration(seconds: 30))` をローカライズした時に文字列に `'30秒'` が含まれることをテスト
- [x] 4.5 detached context で `localize` を呼んだ時に `error.message` が返ることをテスト

## 5. ErrorToast / ErrorBanner ウィジェット

- [ ] 5.1 `app/lib/core/errors/scaffold_messenger_key.dart` に `@Riverpod(keepAlive: true) GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey(Ref ref)` を実装
- [ ] 5.2 `flutter pub run build_runner build --delete-conflicting-outputs` を実行して `scaffold_messenger_key.g.dart` を生成
- [ ] 5.3 `app/lib/core/errors/error_toast.dart` に `void showErrorToast(BuildContext context, AppError error, {VoidCallback? onRetry})` を実装。severity に応じた `ColorScheme` 色選択、4秒 auto-dismiss、`SnackBarAction("再試行")`、deduplication（直近 1 秒以内の同一 `runtimeType + message` を suppress）を含める
- [ ] 5.4 `app/lib/core/errors/error_banner.dart` に `class ErrorBanner extends StatelessWidget` を実装。severity 別アイコン (`error_outline` / `warning_amber` / `info_outline`) + 配色、`onRetry` / `onDismiss` ハンドリング、auto-dismiss しない持続表示
- [ ] 5.5 `app/test/core/errors/error_toast_test.dart` で全 10 variant について `showErrorToast` が `SnackBar` を enqueue することを `pumpWidget` で確認
- [ ] 5.6 `app/test/core/errors/error_toast_dedup_test.dart` で 200ms 連射が 1 件に、1.5秒空けて 2 件になることを `FakeAsync` で検証
- [ ] 5.7 `app/test/core/errors/error_banner_test.dart` で全 10 variant について `ErrorBanner` が build エラーなく描画され、severity 別アイコンが正しく入ることを検証

## 6. ErrorBoundary と runZonedGuarded

- [ ] 6.1 `app/lib/core/errors/error_boundary.dart` に `class ErrorBoundary` と `static void install()` を実装。`kReleaseMode` 判定で `ErrorWidget.builder` を `_ReleaseErrorFallback` 生成側に差し替え、debug 時は元の builder に委譲。冪等化のため `_isInstalled` フラグで多重呼び出しを no-op に
- [ ] 6.2 `_ReleaseErrorFallback` を `StatefulWidget` で実装し、初回 build 時に 1 度だけ `AppErrorLogger.log(UnknownError(details.exception, stackTrace: details.stack))` を呼ぶ。見た目は `ErrorBanner` の `error` severity 相当 + 「アプリを再起動してください」+ 再起動ボタン（`Restart.restartApp` 等は使わず、文言だけ。再起動ロジックは v0.2 で）
- [ ] 6.3 `app/lib/core/errors/error_boundary.dart` に `Future<void> runAppWithErrorBoundary(Widget app)` を実装。内部で `runZonedGuarded` + `FlutterError.onError` を設定し、両方とも `AppErrorLogger.log(UnknownError(...))` を呼んでから元のハンドラに委譲
- [ ] 6.4 `app/test/core/errors/error_boundary_release_mode_test.dart` で `debugDefaultTargetPlatformOverride` 等のテクニックではなく、`ErrorBoundary.install()` 後に `ErrorWidget.builder(FlutterErrorDetails(...))` を直接呼んで返るウィジェットを assert（release / debug の挙動差は `kReleaseMode` を使う関数に切り出して inject 可能にすることで検証可能にする）
- [ ] 6.5 `app/test/core/errors/error_boundary_idempotent_test.dart` で `install()` を 2 回呼んでも build 結果が 1 層の `_ReleaseErrorFallback` であることを確認
- [ ] 6.6 `app/test/core/errors/run_zoned_guarded_test.dart` で `runZonedGuarded` ハンドラに到達した uncaught error が `AppErrorLogger.log` を呼ぶことを mock で確認

## 7. RetryStrategy と withRetry

- [ ] 7.1 `app/lib/core/errors/retry_strategy.dart` に `sealed class RetryStrategy` と `_Indefinite` / `_Bounded` / `_None` を実装。`bounded(maxAttempts)` で `< 1` に `ArgumentError` を投げる
- [ ] 7.2 同ファイルに `Future<T> withRetry<T>(Future<T> Function() task, RetryStrategy strategy, { Duration initialDelay, Duration maxDelay, double jitter, bool Function(Object error)? shouldRetry })` を実装
- [ ] 7.3 デフォルト `shouldRetry` predicate を実装（`RateLimitError` / `UpstreamUnavailableError` / `NetworkUnreachableError` のみ true）
- [ ] 7.4 指数バックオフ計算（`initialDelay * 2^(attempt - 1)` を `maxDelay` で clamp、`±jitter` を `Random` で適用）を実装。`RateLimitError.retryAfter` が non-null の時は `retryAfter` を verbatim 使い jitter を適用しない
- [ ] 7.5 `app/test/core/errors/retry_strategy_test.dart` を `FakeAsync` を使って実装し、(a) `bounded(N)` で N 回試行 (b) `none` で 1 回 (c) `indefinite` が 12 回失敗を耐える (d) デフォルト predicate が `RobotsDisallowedError` / `SiteConsentRequiredError` / `HtmlParseError` / `FileNotFoundError` / `UnsupportedFormatError` / `StorageQuotaError` / `UnknownError` / `FormatException` を retry しないこと、を検証
- [ ] 7.6 `withRetry` の jitter=0 で 1s / 2s / 4s の正確な wait をテスト
- [ ] 7.7 `RateLimitError.retryAfter=30s` で次 wait が 30s ジャストになることをテスト
- [ ] 7.8 `maxDelay=5min` clamp が 2^9=512s を 300s に丸めることをテスト

## 8. ドキュメントと締め

- [ ] 8.1 `app/lib/core/errors/README.md` を作成（しない方針 — `core/errors/` への新規ドキュメント追加はスキップし、design.md を参照させる。**この task は no-op、checkbox はそのまま [x] にしない**）
- [ ] 8.2 `app/lib/main.dart` の `runApp(...)` を `runAppWithErrorBoundary(MyApp())` + `ErrorBoundary.install()` を入れるパターンに置き換える。`MaterialApp` の `scaffoldMessengerKey` に `ref.read(scaffoldMessengerKeyProvider)` を注入、`localizationsDelegates` と `supportedLocales` に `AppLocalizations` 系を追加
- [ ] 8.3 `flutter analyze` / `flutter test` / `dart format --set-exit-if-changed .` が CI でクリーン
- [ ] 8.4 後続再配線 change の起案チェック: design.md 「後続再配線計画」セクションを参照し、`refactor-route-errors-through-app-error` を `/opsx:propose` で別途立てる準備が整っていることを確認（実際の propose は本 change の archive 後）
- [ ] 8.5 全 task の `- [ ]` を `- [x]` に更新し（8.1 は除く / `- [ ]` のまま放置せず明示的に削除するか、`- [-] 8.1 (no-op、design.md を参照)` に書き換えるかは apply 時の裁量）、`/opsx:archive add-error-ux-infra` で本 change をアーカイブ

# error-domain Specification

## Purpose
TBD - created by archiving change add-error-ux-infra. Update Purpose after archive.
## Requirements
### Requirement: AppError sealed hierarchy in core/errors

The system SHALL define `sealed class AppError implements Exception` at `app/lib/core/errors/app_error.dart`. Every error surfaced to the UI or to the structured logger by `core/*` or `features/*` modules MUST be either an `AppError` subtype, or be wrapped in `UnknownError` before crossing the layer boundary. The `AppError` base class MUST expose `String message`, optional `Object? cause`, and optional `StackTrace? stackTrace` fields, and MUST implement value equality on `(runtimeType, message)` plus variant-specific identifying fields (excluding `cause` and `stackTrace`).

#### Scenario: AppError is sealed at the Dart compiler level

- **WHEN** a developer declares `final class FooError extends AppError {}` outside the `app/lib/core/errors/app_error.dart` library
- **THEN** the Dart analyzer reports a `subtype_of_sealed_class` error and the project fails to compile

#### Scenario: Equality ignores cause and stackTrace

- **GIVEN** two `RobotsDisallowedError` instances constructed with the same `message` and `path` but different `cause` values
- **WHEN** they are compared with `==`
- **THEN** the comparison returns `true` and their `hashCode` values are equal

#### Scenario: Exhaustive switch is enforced

- **WHEN** a developer writes a `switch (error)` statement over `AppError` that omits one of the 10 declared variants
- **THEN** the Dart analyzer reports a `non_exhaustive_switch_statement` error

### Requirement: Ten AppError variants cover the existing 7 changes' error contexts

The system SHALL declare exactly the following final subclasses of `AppError` in `app/lib/core/errors/app_error.dart`: `NetworkUnreachableError`, `RateLimitError`, `SiteConsentRequiredError`, `RobotsDisallowedError`, `HtmlParseError`, `FileNotFoundError`, `UnsupportedFormatError`, `UpstreamUnavailableError`, `StorageQuotaError`, `UnknownError`. `RateLimitError` MUST carry an optional `Duration? retryAfter`. `SiteConsentRequiredError` MUST carry a non-null `String site`. `RobotsDisallowedError` MUST carry a non-null `String path`. `HtmlParseError` MUST carry an optional `String? sourceUrl`. `FileNotFoundError` MUST carry a non-null `Uri uri`. `UnsupportedFormatError` MUST carry an optional `String? extension`. `UpstreamUnavailableError` MUST carry an optional `int? statusCode`. `StorageQuotaError` MUST carry an optional `int? requestedBytes`. `UnknownError` MUST be constructible from a single `Object original` argument and MUST set its `message` from `original.toString()` and its `cause` from `original`.

#### Scenario: RateLimitError preserves retryAfter

- **WHEN** a caller constructs `RateLimitError(message: 'too many requests', retryAfter: Duration(seconds: 30))`
- **THEN** `error.retryAfter` is exactly `Duration(seconds: 30)` and `error.message` is `'too many requests'`

#### Scenario: UnknownError wraps an arbitrary exception

- **GIVEN** a `FormatException('bad json')` thrown by an upstream call
- **WHEN** the caller wraps it as `UnknownError(originalException)`
- **THEN** the resulting `UnknownError.message` equals `originalException.toString()`, `UnknownError.cause` is the original `FormatException` instance, and `UnknownError.runtimeType` is `UnknownError`

#### Scenario: SiteConsentRequiredError identifies the site

- **WHEN** kakuyomu code path constructs `SiteConsentRequiredError(site: 'kakuyomu', message: '...')`
- **THEN** `error.site` equals `'kakuyomu'` and the value is preserved through equality and serialization

#### Scenario: RobotsDisallowedError preserves the offending path

- **WHEN** an interceptor constructs `RobotsDisallowedError(path: '/private/page', message: '...')`
- **THEN** `error.path` equals `'/private/page'`

### Requirement: AppError variants implement structured logging via AppErrorLogger

The system SHALL provide `AppErrorLogger` at `app/lib/core/errors/app_error_logger.dart` exposing a static `void log(AppError error)` method. The method MUST route to the `logger` package's `Logger.e` for variants whose severity is `error`, to `Logger.w` for variants whose severity is `warning`, and to `Logger.i` for variants whose severity is `info`. Severity mapping MUST follow design.md D3. The log payload MUST include `type` (runtimeType.toString()), `message`, every variant-specific identifying field, and the string representations of `cause` and `stackTrace` when present.

#### Scenario: RateLimitError logs at warning severity

- **WHEN** `AppErrorLogger.log(RateLimitError(message: 'x', retryAfter: Duration(seconds: 5)))` is called
- **THEN** the `logger` package receives a `Level.warning` record whose payload includes `type=RateLimitError`, `message=x`, and `retryAfter=PT5S` (or equivalent ISO-8601 / seconds encoding)

#### Scenario: UnknownError logs at error severity with stack trace

- **GIVEN** an `UnknownError(originalException, stackTrace: trace)` where `trace` is non-null
- **WHEN** `AppErrorLogger.log(error)` is called
- **THEN** the `logger` package receives a `Level.error` record whose payload includes the `stackTrace` field as a string of `trace.toString()`

#### Scenario: RobotsDisallowedError logs the path

- **WHEN** `AppErrorLogger.log(RobotsDisallowedError(message: 'denied', path: '/admin/'))` is called
- **THEN** the structured log payload contains a field `path` with value `'/admin/'`

### Requirement: AppError variants are localized via ErrorMessages.localize

The system SHALL provide `ErrorMessages.localize(AppError error, BuildContext context)` at `app/lib/core/errors/error_messages.dart`. The function MUST return a non-empty Japanese string for every declared `AppError` variant when `AppLocalizations.of(context)` is non-null. When `AppLocalizations.of(context)` returns null (e.g., the context is detached from the `Element` tree), the function MUST fall back to `error.message` directly. The function MUST consume the variant-specific fields (e.g., `RateLimitError.retryAfter`) when interpolating localized strings that reference them.

#### Scenario: All ten variants return a non-empty Japanese string

- **GIVEN** a `BuildContext` with a valid `AppLocalizations` ja delegate
- **WHEN** `ErrorMessages.localize(...)` is called for each of the ten declared `AppError` variants
- **THEN** every call returns a non-empty string and no call throws

#### Scenario: RateLimitError interpolates retryAfter

- **GIVEN** `AppLocalizations` provides `errorRateLimit(int seconds)` = `'リクエストが多すぎます。{seconds}秒後に再試行してください。'`
- **WHEN** `ErrorMessages.localize(RateLimitError(message: 'x', retryAfter: Duration(seconds: 30)), context)` is called
- **THEN** the returned string contains the substring `'30秒後'`

#### Scenario: Detached context falls back to error.message

- **GIVEN** a `BuildContext` whose `AppLocalizations.of(context)` returns null
- **WHEN** `ErrorMessages.localize(NetworkUnreachableError(message: 'fallback message'), context)` is called
- **THEN** the returned string equals `'fallback message'` and no `NoSuchMethodError` is thrown

### Requirement: ja-first ARB skeleton at app/lib/l10n/app_ja.arb

The system SHALL place an `app_ja.arb` file at `app/lib/l10n/app_ja.arb` containing at minimum one localized message per declared `AppError` variant (10 entries, keys named `errorNetworkUnreachable`, `errorRateLimit`, `errorSiteConsentRequired`, `errorRobotsDisallowed`, `errorHtmlParse`, `errorFileNotFound`, `errorUnsupportedFormat`, `errorUpstreamUnavailable`, `errorStorageQuota`, `errorUnknown`). The system SHALL add `flutter_localizations` to `pubspec.yaml` and SHALL configure `app/lib/l10n/l10n.yaml` to generate `AppLocalizations` accessible via `AppLocalizations.of(context)`. The project SHALL include the generated `app/lib/l10n/app_localizations.dart` (or equivalent) in source control or generate it as part of the build.

#### Scenario: ARB file declares all ten error keys

- **WHEN** `app/lib/l10n/app_ja.arb` is loaded as JSON
- **THEN** the resulting map contains all ten keys listed above with non-empty Japanese string values

#### Scenario: AppLocalizations exposes typed getters

- **WHEN** Flutter's gen-l10n step processes `app_ja.arb`
- **THEN** the generated `AppLocalizations` class exposes a getter or method for every `error*` key (e.g., `errorNetworkUnreachable`, `errorRateLimit(int seconds)`)

### Requirement: AppError dependency direction is strictly one-way

The system SHALL place `app/lib/core/errors/` as a leaf module that depends only on Flutter SDK packages, `logger`, `intl`, and `flutter_riverpod` plus generated localizations. No file in `app/lib/core/errors/` SHALL import from `app/lib/core/network/`, `app/lib/core/storage/`, `app/lib/core/media/`, `app/lib/core/novel/`, or any `app/lib/features/`. Tests SHALL enforce this via a dependency-direction check.

#### Scenario: Forbidden import is rejected

- **WHEN** a developer adds `import 'package:geekplayer/core/network/dio_client.dart';` to any file under `app/lib/core/errors/`
- **THEN** the dependency-direction test (`app/test/core/errors/dependency_direction_test.dart`) fails with a message naming the offending file

#### Scenario: Allowed imports compile

- **WHEN** files under `app/lib/core/errors/` import from `package:flutter/widgets.dart`, `package:logger/logger.dart`, `package:flutter_riverpod/flutter_riverpod.dart`, or the generated `AppLocalizations`
- **THEN** the project analyzes and tests cleanly

### Requirement: Errors have English localized messages

Every `AppError` variant that has Japanese localization SHALL also have English localization. Error localization MUST continue to fall back to the raw error message when no localization context is available.

#### Scenario: Error localizes in English

- **WHEN** `ErrorMessages.localize` is called for each declared `AppError` variant under `Locale('en')`
- **THEN** every call returns a non-empty English string and no call throws

### Requirement: Book reader maps failures to AppError

The book reader SHALL surface file-not-found, unsupported-format, parse/render, and storage failures as `AppError` variants before crossing into presentation code.

#### Scenario: Corrupt EPUB is surfaced as a parse error

- **WHEN** the user opens a corrupt EPUB file
- **THEN** the reader shows a localized parse/render error and no raw parser exception reaches the widget tree

#### Scenario: Missing PDF is surfaced as file-not-found

- **WHEN** the user opens a stored PDF entry whose file no longer exists
- **THEN** the app surfaces `FileNotFoundError` with the missing URI

### Requirement: Manga viewer maps failures to AppError

The manga viewer SHALL surface missing files, unsupported archive formats, corrupt archives, unsafe archive entries, oversized archives, unsupported image formats, image decode failures, and storage failures as `AppError` variants before crossing into presentation code.

#### Scenario: Corrupt archive is surfaced as localized error

- **WHEN** the user opens a corrupt ZIP archive
- **THEN** the viewer shows a localized archive error and no raw archive exception reaches the widget tree

#### Scenario: Missing manga file is surfaced as file-not-found

- **WHEN** the user opens a stored manga entry whose archive no longer exists
- **THEN** the app surfaces `FileNotFoundError` with the missing URI

### Requirement: プレゼンテーション層はユーザー向けエラー文字列を必ず ErrorMessages.localize 経由で表示する

The system SHALL ensure that no widget in `app/lib/features/*/presentation/` displays an error to the user by directly interpolating a caught exception into a string literal (e.g., `'エラー: $e'`, `'失敗しました: $err'`). Every user-facing error string MUST be produced via `ErrorMessages.localize(AppError, BuildContext)`. When the caught value is not already an `AppError`, it MUST be wrapped in `UnknownError(e)` before passing to `ErrorMessages.localize`.

#### Scenario: video home_section がエラーを ErrorMessages.localize 経由で表示する

- **GIVEN** `localVideoProvider` がエラーを投げた場合
- **WHEN** `app/lib/features/video/presentation/home_section.dart` がエラー状態をレンダリングする
- **THEN** 表示文字列は `ErrorMessages.localize(UnknownError(e), context)` の戻り値であり、`'読み込みに失敗しました: $e'` のような生文字列展開は含まれない

#### Scenario: audio home_section がエラーを ErrorMessages.localize 経由で表示する

- **GIVEN** `localAudioProvider` がエラーを投げた場合
- **WHEN** `app/lib/features/audio/presentation/home_section.dart` がエラー状態をレンダリングする
- **THEN** 表示文字列は `ErrorMessages.localize(UnknownError(e), context)` の戻り値であり、`'読み込みに失敗しました: $e'` のような生文字列展開は含まれない

#### Scenario: narou work_detail_screen がエラーを SnackBar で正しく表示する

- **GIVEN** なろうライブラリへの追加操作が例外を投げた場合
- **WHEN** `app/lib/features/novel_narou/presentation/work_detail_screen.dart` のエラーハンドラが実行される
- **THEN** SnackBar のテキストは `ErrorMessages.localize(UnknownError(e), context)` の戻り値であり、`'追加に失敗しました: $e'` のような生文字列展開は含まれない

#### Scenario: kakuyomu work_detail_screen がエラーを ErrorMessages.localize 経由で表示する

- **GIVEN** カクヨムライブラリへの追加またはエピソード取得が例外を投げた場合
- **WHEN** `app/lib/features/novel_kakuyomu/presentation/work_detail_screen.dart` がエラー状態を表示する
- **THEN** 表示文字列は `ErrorMessages.localize` を経由しており、`'追加に失敗: $e'` や `'エラー: $err'` のような生文字列展開は含まれない

#### Scenario: kakuyomu reader_screen がエラーを ErrorMessages.localize 経由で表示する

- **GIVEN** カクヨムエピソード取得が例外を投げた場合
- **WHEN** `app/lib/features/novel_kakuyomu/presentation/reader_screen.dart` がエラー状態をレンダリングする
- **THEN** 表示文字列は `ErrorMessages.localize` を経由しており、`'エラー: $err'` のような生文字列展開は含まれない

#### Scenario: kakuyomu search_screen がエラーを ErrorMessages.localize 経由で表示する

- **GIVEN** カクヨム検索が例外を投げた場合
- **WHEN** `app/lib/features/novel_kakuyomu/presentation/search_screen.dart` がエラー状態をレンダリングする
- **THEN** 表示文字列は `ErrorMessages.localize` を経由しており、`'エラーが発生しました: $err'` のような生文字列展開は含まれない


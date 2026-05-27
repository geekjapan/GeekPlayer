## ADDED Requirements

### Requirement: ErrorSeverity classification

The system SHALL define `enum ErrorSeverity { info, warning, error }` at `app/lib/core/errors/error_banner.dart` and a top-level function `ErrorSeverity severityOf(AppError error)` that classifies each `AppError` variant. The mapping MUST be: `info` for none of the 10 variants (reserved for future use), `warning` for `RateLimitError`, `SiteConsentRequiredError`, `HtmlParseError`, `NetworkUnreachableError`, `UpstreamUnavailableError`, and `error` for `RobotsDisallowedError`, `FileNotFoundError`, `UnsupportedFormatError`, `StorageQuotaError`, `UnknownError`.

#### Scenario: severityOf classifies every variant deterministically

- **WHEN** `severityOf(error)` is called for an instance of each of the 10 `AppError` variants
- **THEN** the returned value is exactly the severity listed in the mapping above and no call throws

#### Scenario: severityOf is exhaustive

- **WHEN** the Dart analyzer evaluates the `severityOf` function body
- **THEN** the function uses an exhaustive switch over `AppError` and produces no `non_exhaustive_switch` warning

### Requirement: showErrorToast global helper displays a SnackBar

The system SHALL provide a top-level function `void showErrorToast(BuildContext context, AppError error, {VoidCallback? onRetry})` at `app/lib/core/errors/error_toast.dart`. The function MUST use the `ScaffoldMessenger` obtained via the `scaffoldMessengerKeyProvider` (Riverpod) to enqueue a `SnackBar`. The displayed text MUST be the result of `ErrorMessages.localize(error, context)`. The SnackBar's `backgroundColor` MUST come from the active `ColorScheme`: `colorScheme.errorContainer` for `error` severity, `colorScheme.tertiaryContainer` for `warning` severity, `colorScheme.surfaceContainerHighest` for `info` severity. The SnackBar MUST auto-dismiss after exactly 4 seconds. When `onRetry` is non-null, the SnackBar MUST include a `SnackBarAction` whose label is the localized string for "再試行" and whose callback invokes `onRetry`.

#### Scenario: Error severity uses errorContainer color

- **GIVEN** an active `ColorScheme` with a known `errorContainer` color
- **WHEN** `showErrorToast(context, RobotsDisallowedError(path: '/x', message: 'm'))` is called
- **THEN** the dispatched SnackBar's `backgroundColor` equals the active `colorScheme.errorContainer`

#### Scenario: Warning severity uses tertiaryContainer color

- **WHEN** `showErrorToast(context, RateLimitError(message: 'm'))` is called
- **THEN** the dispatched SnackBar's `backgroundColor` equals the active `colorScheme.tertiaryContainer`

#### Scenario: SnackBar auto-dismisses after 4 seconds

- **WHEN** `showErrorToast(context, NetworkUnreachableError(message: 'm'))` is called
- **THEN** the dispatched SnackBar's `duration` is exactly `Duration(seconds: 4)`

#### Scenario: onRetry creates a retry action

- **GIVEN** a non-null `onRetry` callback
- **WHEN** `showErrorToast(context, UpstreamUnavailableError(message: 'm'), onRetry: callback)` is called and the user taps the action button
- **THEN** the callback is invoked exactly once

### Requirement: showErrorToast deduplicates rapid repeats

The system SHALL suppress identical `showErrorToast` calls issued within 1 second of a previous identical call. Two calls are "identical" when their `AppError` runtimeType and `message` are equal. The deduplication state SHALL be held by the `scaffoldMessengerKeyProvider`'s notifier and SHALL be cleared 1 second after the last suppressed call.

#### Scenario: Duplicate within 1 second is suppressed

- **WHEN** `showErrorToast(context, NetworkUnreachableError(message: 'x'))` is called twice within 200ms
- **THEN** the `ScaffoldMessenger` enqueues exactly one SnackBar

#### Scenario: Same error after 1 second is not suppressed

- **WHEN** `showErrorToast(context, NetworkUnreachableError(message: 'x'))` is called, then called again 1.5 seconds later
- **THEN** the `ScaffoldMessenger` enqueues two SnackBars

#### Scenario: Different message is not suppressed

- **WHEN** `showErrorToast(context, NetworkUnreachableError(message: 'a'))` is called, then `showErrorToast(context, NetworkUnreachableError(message: 'b'))` is called within 100ms
- **THEN** the `ScaffoldMessenger` enqueues two SnackBars

### Requirement: ErrorBanner displays persistent error UI with severity styling

The system SHALL provide an `ErrorBanner` `StatelessWidget` at `app/lib/core/errors/error_banner.dart` that accepts a required `AppError error`, an optional `VoidCallback? onRetry`, and an optional `VoidCallback? onDismiss`. The banner MUST render the localized message via `ErrorMessages.localize`. The banner MUST display a leading icon: `Icons.error_outline` for `error` severity, `Icons.warning_amber` for `warning` severity, `Icons.info_outline` for `info` severity. The banner background MUST follow the same severity-to-`ColorScheme` mapping as `showErrorToast`. The banner MUST NOT auto-dismiss; it persists until `onDismiss` is invoked or its parent removes it from the tree.

#### Scenario: Error severity shows error icon

- **WHEN** an `ErrorBanner(error: FileNotFoundError(uri: Uri.parse('file:///x'), message: 'm'))` is rendered
- **THEN** a child `Icon` with `icon == Icons.error_outline` is present in the widget tree

#### Scenario: Warning severity shows warning icon

- **WHEN** an `ErrorBanner(error: RateLimitError(message: 'm'))` is rendered
- **THEN** a child `Icon` with `icon == Icons.warning_amber` is present in the widget tree

#### Scenario: onRetry presents a retry button

- **GIVEN** a non-null `onRetry` callback
- **WHEN** the user taps the retry button inside `ErrorBanner`
- **THEN** the callback is invoked exactly once

#### Scenario: Banner does not auto-dismiss

- **WHEN** an `ErrorBanner` is rendered and the test waits 5 seconds
- **THEN** the banner is still present in the widget tree

### Requirement: ErrorBoundary overrides ErrorWidget.builder in release builds only

The system SHALL provide `ErrorBoundary` at `app/lib/core/errors/error_boundary.dart` exposing a static `void install()` method that replaces `ErrorWidget.builder` with a builder that returns a `_ReleaseErrorFallback` widget when `kReleaseMode` is true, and that delegates to the previously installed builder otherwise. The `_ReleaseErrorFallback` MUST visually match `ErrorBanner` with `error` severity, MUST display a localized "アプリを再起動してください" message, and MUST invoke `AppErrorLogger.log(UnknownError(details.exception, stackTrace: details.stack))` exactly once per `_ReleaseErrorFallback` instance lifetime. The `install()` method MUST be idempotent: calling it multiple times MUST NOT chain multiple overrides.

#### Scenario: Release mode shows the fallback

- **GIVEN** the app is running with `kReleaseMode == true` and `ErrorBoundary.install()` has been called
- **WHEN** a widget throws inside `build` and `ErrorWidget.builder` is invoked
- **THEN** the resulting widget is a `_ReleaseErrorFallback` displaying the localized "アプリを再起動してください" message

#### Scenario: Debug mode preserves the default builder

- **GIVEN** the app is running with `kReleaseMode == false` and `ErrorBoundary.install()` has been called
- **WHEN** a widget throws inside `build` and `ErrorWidget.builder` is invoked
- **THEN** the resulting widget is the default Flutter red `ErrorWidget` produced by the original builder

#### Scenario: Fallback logs once via AppErrorLogger

- **GIVEN** the release fallback is rendered for a thrown `RangeError`
- **WHEN** `_ReleaseErrorFallback` runs its first frame
- **THEN** `AppErrorLogger.log` is invoked exactly once with an `UnknownError` whose `cause` is the `RangeError` instance

#### Scenario: install() is idempotent

- **GIVEN** `ErrorBoundary.install()` has been called once
- **WHEN** `ErrorBoundary.install()` is called a second time
- **THEN** invoking `ErrorWidget.builder(details)` still produces a single `_ReleaseErrorFallback` widget (not nested fallbacks)

### Requirement: runZonedGuarded captures async errors and routes through AppErrorLogger

The system SHALL document, and provide a top-level helper `Future<void> runAppWithErrorBoundary(Widget app)` at `app/lib/core/errors/error_boundary.dart`, that wraps `runApp` in `runZonedGuarded` and routes any uncaught zone error to `AppErrorLogger.log(UnknownError(error, stackTrace: stack))`. `FlutterError.onError` MUST also be set to invoke `AppErrorLogger.log` before delegating to the previously installed handler.

#### Scenario: Uncaught async error is logged

- **GIVEN** `runAppWithErrorBoundary(MyApp())` has been called
- **WHEN** an unawaited `Future.error(FormatException('x'))` is thrown
- **THEN** `AppErrorLogger.log` is invoked with an `UnknownError` whose `cause` is the `FormatException`

#### Scenario: FlutterError.onError still delegates

- **GIVEN** a previously installed `FlutterError.onError` handler
- **WHEN** `runAppWithErrorBoundary` is invoked and a `FlutterError` is reported
- **THEN** the previously installed handler is invoked after `AppErrorLogger.log`

### Requirement: scaffoldMessengerKeyProvider exposes a Riverpod-managed GlobalKey

The system SHALL provide a Riverpod `keepAlive` provider named `scaffoldMessengerKeyProvider` (generated via `@Riverpod(keepAlive: true)` codegen) at `app/lib/core/errors/scaffold_messenger_key.dart` that returns a single `GlobalKey<ScaffoldMessengerState>`. The `MaterialApp` SHALL pass this key to its `scaffoldMessengerKey` parameter. `showErrorToast` SHALL read the current `ScaffoldMessengerState` through this key, independent of the `BuildContext` argument.

#### Scenario: Provider returns a stable GlobalKey

- **WHEN** `ref.read(scaffoldMessengerKeyProvider)` is invoked twice within the same Riverpod container
- **THEN** the two reads return the same `GlobalKey<ScaffoldMessengerState>` instance

#### Scenario: showErrorToast uses the provider key

- **GIVEN** a `MaterialApp` whose `scaffoldMessengerKey` is the value of `scaffoldMessengerKeyProvider`
- **WHEN** `showErrorToast` is called with a `BuildContext` whose ancestor is the same `MaterialApp`
- **THEN** the SnackBar appears in the `ScaffoldMessenger` rooted at that key

### Requirement: Widget tests cover toast and banner rendering for every variant

The system SHALL include widget tests at `app/test/core/errors/` that render an `ErrorBanner` and dispatch a `showErrorToast` for each of the 10 `AppError` variants. Every test MUST assert that the resulting widget tree contains a non-empty text node and that no exception is thrown during build.

#### Scenario: All ten variants render in ErrorBanner

- **WHEN** the parameterized widget test runs for each `AppError` variant
- **THEN** each test passes, the rendered banner contains at least one non-empty `Text` widget, and no `Element.build` exception is reported

#### Scenario: All ten variants render in showErrorToast

- **WHEN** the parameterized widget test calls `showErrorToast` for each variant and pumps a frame
- **THEN** each test pumps without throwing and the `ScaffoldMessenger` contains at least one `SnackBar`

## Context

GeekPlayer is GitHub-Releases-only with no OS-managed update channel. `package_info_plus` (already in `pubspec.yaml`) provides the running version. `url_launcher` (already in `pubspec.yaml`) can open the release page on all target platforms. No new dependencies are required.

## Goals / Non-Goals

**Goals:**

- Provide an injectable `UpdateChecker` interface for testability.
- Implement `GithubUpdateChecker` using plain `http.Client` (from the `http` package, already transitively present via `dio`; we will use `dart:io` + `HttpClient` directly to avoid adding a new top-level dependency — see D3).
- Compare semantic versions and surface a banner when a newer release is available.
- Open the GitHub release page via `url_launcher` on "Download" tap.
- Map failures to `NetworkUnreachableError` / `UpstreamUnavailableError`.

**Non-Goals:**

- Silent download, automatic install, forced update.
- Per-platform asset selection.
- Update-check scheduling or periodic polling.
- Linux platform changes.

## Decisions

### D1. Single interface, one concrete + one fake implementation

`UpdateChecker` is an abstract class with a single `checkForUpdate()` method returning `Future<UpdateResult>`. `GithubUpdateChecker` is the live implementation; `FakeUpdateChecker` is provided in test helpers. This mirrors the repository pattern used elsewhere in the codebase (`NovelRepository`, `BookRepository`).

### D2. UpdateResult sealed type

`UpdateResult` is a sealed class with two variants: `UpdateAvailable(latestVersion, releaseUrl)` and `UpToDate`. Using a sealed return type keeps call sites exhaustive and avoids nullable returns or boolean+data pairs.

### D3. Use dart:io HttpClient directly — no new dependency

`dart:io`'s `HttpClient` is available on all Flutter target platforms (macOS, Windows, Android) and in tests via `HttpOverrides`. This avoids adding `http` as a top-level dep. The fake path overrides `HttpClient` via `HttpOverrides.global` in tests.

Alternative considered: wrap `dio` (already present). Rejected because `dio` Interceptors and `Dio` instances are deeply tied to the site-scraping infrastructure (robots.txt, rate limiting, backoff). Mixing the update checker into that graph would add undesired coupling. A thin `dart:io` client is cleaner for an isolated one-shot check.

### D4. Semantic version comparison without a semver package

`package_info_plus` returns version strings like `"0.1.0"`. GitHub tag names use `"v0.1.0"` or `"0.1.0"`. We strip a leading `"v"` and split on `"."` to compare major.minor.patch as integers. This is sufficient for the app's versioning scheme and requires no additional dependency.

### D5. Banner in Settings About section — not a home-screen snackbar

The update check is triggered when the Settings screen loads. The banner appears inside the About section using the same `MaterialBanner` approach used by `settingsCacheOverBanner`. This keeps the check non-intrusive (only visible when the user opens Settings) and avoids polluting the home screen state.

### D6. UpdateCheckerProvider via Riverpod

`updateCheckerProvider` is a `@Riverpod(keepAlive: true)` provider returning an `UpdateChecker`. Tests override it with a `FakeUpdateChecker` using `ProviderScope(overrides: [...])`.

## Risks / Trade-offs

- [Risk] GitHub API rate limit (60 req/hour unauthenticated) → Mitigation: check is triggered at most once per Settings screen open, not on a timer. In practice one check per session is well within limits.
- [Risk] Tag name format drift (e.g., `"release/0.2.0"` instead of `"v0.2.0"`) → Mitigation: the checker strips a leading `"v"` and validates the three-part format; malformed tags produce `UpToDate` (safe no-op) and log a debug warning.
- [Risk] `dart:io` not available on web → Non-issue: GeekPlayer does not target web.

## Package Selection

No new dependencies required. `url_launcher ^6.3.2` and `package_info_plus ^10.1.0` are already declared in `app/pubspec.yaml:61,57`.

## API Shape

```dart
// app/lib/features/update/update_checker.dart
abstract class UpdateChecker {
  Future<UpdateResult> checkForUpdate(String currentVersion);
}

sealed class UpdateResult {}
final class UpToDate extends UpdateResult { const UpToDate(); }
final class UpdateAvailable extends UpdateResult {
  const UpdateAvailable({required this.latestVersion, required this.releaseUrl});
  final String latestVersion;
  final String releaseUrl;
}

// app/lib/features/update/github_update_checker.dart
final class GithubUpdateChecker implements UpdateChecker { ... }

// app/lib/features/update/update_checker_provider.dart
@Riverpod(keepAlive: true)
UpdateChecker updateChecker(Ref ref) => GithubUpdateChecker();

// app/lib/features/update/update_banner.dart
class UpdateBanner extends ConsumerStatefulWidget { ... }
```

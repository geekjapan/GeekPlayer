## 1. Domain and Data Layer

- [x] 1.1 Create `UpdateChecker` abstract interface and `UpdateResult` sealed type in `app/lib/features/update/update_checker.dart`
- [x] 1.2 Implement `GithubUpdateChecker` in `app/lib/features/update/github_update_checker.dart` using `dart:io` `HttpClient`, parsing `tag_name` from GitHub Releases API response, mapping failures to `NetworkUnreachableError` / `UpstreamUnavailableError`
- [x] 1.3 Add `updateCheckerProvider` Riverpod provider in `app/lib/features/update/update_checker_provider.dart`

## 2. Presentation

- [x] 2.1 Add `UpdateBanner` widget in `app/lib/features/update/update_banner.dart` — checks for update on first build, shows a `MaterialBanner` when `UpdateAvailable`, opens release URL via `url_launcher` on "Download" tap
- [x] 2.2 Add `UpdateBanner` to the About section of the Settings screen in `app/lib/features/settings/presentation/sections/about_section.dart`

## 3. Localization

- [x] 3.1 Add update-related keys to `app/lib/l10n/app_ja.arb`: `updateAvailableBannerTitle`, `updateAvailableBannerBody`, `updateAvailableDownload`, `updateAvailableDismiss`
- [x] 3.2 Add matching keys to `app/lib/l10n/app_en.arb` with English translations (parity with ja)
- [x] 3.3 Run `cd app && flutter gen-l10n`

## 4. Tests

- [x] 4.1 Add unit tests for `GithubUpdateChecker` in `app/test/features/update/github_update_checker_test.dart` — cover: update available, up to date, network error, upstream error, malformed tag, HTTP 404
- [x] 4.2 Add widget test for `UpdateBanner` in `app/test/features/update/update_banner_test.dart` — cover: shows banner when update available, shows nothing when up to date, dismiss hides banner, download calls url_launcher

## 5. Verification

- [x] 5.1 Run `cd app && dart run build_runner build --delete-conflicting-outputs`
- [x] 5.2 Run `cd app && flutter gen-l10n`
- [x] 5.3 Run `cd app && dart format --output=none --set-exit-if-changed .`
- [x] 5.4 Run `cd app && flutter analyze --fatal-infos`
- [x] 5.5 Run `cd app && flutter test`
- [x] 5.6 Run `openspec validate add-auto-update --strict`
- [x] 5.7 Run `git diff --check`

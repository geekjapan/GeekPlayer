## Why

GeekPlayer distributes exclusively via GitHub Releases (no App Store / Play Store). Users have no OS-managed update path. Without an in-app check, running a stale build is the silent default. A lightweight version-check against the GitHub Releases API surfaces the current release and lets the user choose to download it — maintaining the opt-in, non-silent update philosophy compatible with a side-loaded distribution model.

## What Changes

- Add an injectable `UpdateChecker` interface backed by a `GithubUpdateChecker` that polls `https://api.github.com/repos/geekjapan/GeekPlayer/releases/latest`.
- Compare the fetched `tag_name` against the running version from `package_info_plus` using semantic version comparison.
- Surface an `UpdateBanner` in the Settings screen when a newer release is available, with a single "Download" action that opens the release page via `url_launcher`.
- Map network/HTTP failures to existing `NetworkUnreachableError` and `UpstreamUnavailableError` variants.
- Provide a fake HTTP client implementation so the checker is unit-testable without live network access.

## Non-goals

- No silent background download or automatic installation.
- No forced-update blocking: the user can always dismiss the banner.
- No per-platform asset discrimination (macOS pkg vs. Windows installer vs. APK) — all platforms open the same release page URL.
- No push notification or OS-level badge for updates.
- No update-check scheduling / periodic polling; check is triggered on Settings screen open.
- No rollback mechanism.
- No Linux platform changes (constrained by sibling stream).

## Capabilities

### New Capabilities

- `auto-update`: Defines GitHub Releases version check, semantic version comparison, opt-in download delivery, error mapping, and injectable interface contract.

### Modified Capabilities

- `error-domain`: Reuses `NetworkUnreachableError` and `UpstreamUnavailableError` without adding new variants.
- `app-settings`: Adds the `UpdateBanner` widget to the Settings screen About section.

## Impact

- New feature: `app/lib/features/update/`.
- Settings About section: `app/lib/features/settings/presentation/sections/about_section.dart:17`.
- Localization: `app/lib/l10n/app_ja.arb` and `app/lib/l10n/app_en.arb`.
- Tests: `app/test/features/update/`.
- No drift schema changes.
- No CI workflow changes.
- No changes to `app/linux/`.

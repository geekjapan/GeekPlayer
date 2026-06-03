# Proposal: expand-auto-update-delivery

## Problem

The existing `UpdateBanner` "Download" action only opens the GitHub release **web page** in an external browser. Users must then manually find the correct asset for their platform, download it, and launch the installer. This is friction-heavy and error-prone.

## Proposed Solution

Extend the update flow so the "Download" button:

1. Selects the correct GitHub release asset for the running platform (macOS → `.dmg`/`.zip`, Windows → `.exe`/`.zip`, Android → `.apk`, Linux → `.AppImage`/`.tar.gz`).
2. Downloads the asset to the OS temp directory using `dio` with progress reporting.
3. Hands the downloaded file to the OS installer/opener via `url_launcher` (`launchUrl` with a `file://` URI).

If no compatible asset is found, the original browser-launch fallback is used.

## Constraints

- No new `pubspec.yaml` dependencies — use existing `dio ^5.9`, `path_provider ^2.1`, `url_launcher ^6.3`.
- No native (Swift / Kotlin / C++) code.
- All new Riverpod providers are overridable in tests via `@Riverpod` codegen.
- Platform detection via `TargetPlatform` (not `dart:io` directly).
- All string literals in widgets are `AppLocalizations` getters.

## Scope

- `app/lib/features/update/` — new files: `release_asset.dart`, `update_downloader.dart`, `update_installer.dart`, updated `update_checker.dart`, `update_banner.dart`.
- `app/lib/l10n/app_ja.arb` and `app_en.arb` — new keys for download progress, error, install/open, no compatible asset.
- `app/test/features/update/` — new test files.

## Out of Scope

- Auto-installing without user confirmation.
- Delta/incremental updates.
- iOS (App Store distribution only).

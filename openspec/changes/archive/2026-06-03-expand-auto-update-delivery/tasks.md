# Tasks: expand-auto-update-delivery

- [x] T1: Create `app/lib/features/update/release_asset.dart` — `ReleaseAsset` value type + `selectAssetForPlatform` pure function
- [x] T2: Extend `UpdateAvailable` in `update_checker.dart` with `assets` field
- [x] T3: Update `GithubUpdateChecker` to parse assets array and populate `UpdateAvailable.assets`
- [x] T4: Create `app/lib/features/update/update_downloader.dart` — `UpdateDownloader` abstract + `DioUpdateDownloader` + Riverpod provider (codegen)
- [x] T5: Create `app/lib/features/update/update_installer.dart` — `UpdateInstaller` abstract + `LaunchUrlUpdateInstaller` + Riverpod provider (codegen)
- [x] T6: Run `dart run build_runner build --delete-conflicting-outputs`
- [x] T7: Add ARB keys to `app_ja.arb` and `app_en.arb`; run `flutter gen-l10n`
- [x] T8: Rewrite `UpdateBanner` download flow with progress UI and error handling
- [x] T9: Write `app/test/features/update/select_asset_test.dart`
- [x] T10: Write `app/test/features/update/update_banner_download_test.dart`
- [x] T11: Run `flutter analyze --fatal-infos` — verify "No issues found"
- [x] T12: Run `flutter test` — verify all tests pass

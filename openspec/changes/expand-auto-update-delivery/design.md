# Design: expand-auto-update-delivery

## Architecture

### D1 — Asset selection (pure function)

`selectAssetForPlatform(List<ReleaseAsset> assets, TargetPlatform platform) → ReleaseAsset?`

Pure function, no I/O. Matches asset `name` against platform-specific patterns:

| Platform        | Priority patterns                      |
|-----------------|----------------------------------------|
| macOS           | `.dmg` first, then `.zip`             |
| Windows         | `.exe` first, then `.zip`             |
| Android         | `.apk`                                 |
| Linux           | `.AppImage` first, then `.tar.gz`     |

Returns `null` when no matching asset is found (triggers browser fallback).

### D2 — `ReleaseAsset` value type

```dart
final class ReleaseAsset {
  final String name;         // asset filename
  final String downloadUrl;  // browser_download_url
  final int sizeBytes;       // size field from GitHub API
}
```

### D3 — `UpdateAvailable` extension

Extend `UpdateAvailable` with `List<ReleaseAsset> assets` field so the banner can call `selectAssetForPlatform`. Existing constructor gains an optional `assets` parameter (defaults to `const []`) to keep the API non-breaking.

### D4 — `GithubUpdateChecker` change

Parse the `assets` JSON array into `List<ReleaseAsset>` and populate `UpdateAvailable.assets`.

### D5 — `UpdateDownloader` abstract interface + `DioUpdateDownloader`

```dart
abstract class UpdateDownloader {
  Future<String> download(
    ReleaseAsset asset, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  });
}
```

Returns path of the downloaded file. `DioUpdateDownloader` uses `dio` with `onReceiveProgress`. Stored in `path_provider.getTemporaryDirectory()`.

Provider: `@Riverpod(keepAlive: true) UpdateDownloader updateDownloader(Ref ref)` → returns `DioUpdateDownloader`.

### D6 — `UpdateInstaller` abstract interface + `LaunchUrlUpdateInstaller`

```dart
abstract class UpdateInstaller {
  Future<void> openForInstall(String filePath);
}
```

`LaunchUrlUpdateInstaller.openForInstall` builds a `file://` URI and calls `launchUrl`.

Provider: `@Riverpod(keepAlive: true) UpdateInstaller updateInstaller(Ref ref)` → returns `LaunchUrlUpdateInstaller`.

### D7 — `UpdateBanner` download flow

State machine in `_UpdateBannerState`:

```
idle → downloading(progress 0..1) → readyToInstall → [done/error]
```

- Download button tap: calls `_startDownload()`.
- Shows `LinearProgressIndicator` during download.
- On completion: shows "インストール / 開く" button.
- On error: shows `SnackBar` with localized error message; reverts to idle.
- Cancel: exposed via `DioUpdateDownloader` `CancelToken` (not surfaced in UI v0.2).

### D8 — Localization keys (new)

| Key | ja | en |
|-----|----|----|
| `updateDownloading` | `ダウンロード中… {percent}%` | `Downloading… {percent}%` |
| `updateDownloadFailed` | `ダウンロードに失敗しました` | `Download failed` |
| `updateInstall` | `インストール / 開く` | `Install / Open` |
| `updateNoCompatibleAsset` | `対応アセットが見つかりません` | `No compatible asset found` |

### D9 — Test strategy

- `select_asset_test.dart` — pure function, no Flutter.
- `update_downloader_test.dart` — fake `DioUpdateDownloader` via interface.
- `update_banner_download_test.dart` — widget test with fake downloader / installer injected.

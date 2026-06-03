# auto-update Delta Spec — expand-auto-update-delivery

## ADDED Requirements

### Requirement: Platform-specific asset selection

SHALL select the correct GitHub release asset for the running platform using a pure function `selectAssetForPlatform(List<ReleaseAsset> assets, TargetPlatform platform)`.

Priority per platform:
- macOS: `.dmg` first, `.zip` fallback
- Windows: `.exe` first, `.zip` fallback
- Android: `.apk`
- Linux: `.AppImage` first, `.tar.gz` fallback

When no compatible asset is found, the function MUST return `null`.

#### Scenario: macOS prefers dmg over zip

Given assets `["GeekPlayer-0.2.0.dmg", "GeekPlayer-0.2.0.zip"]`,
when `selectAssetForPlatform(assets, TargetPlatform.macOS)` is called,
then it returns the `.dmg` asset.

#### Scenario: no compatible asset returns null

Given assets `["GeekPlayer-0.2.0.apk"]`,
when `selectAssetForPlatform(assets, TargetPlatform.macOS)` is called,
then it returns `null`.

### Requirement: In-app download with progress

When the user taps "Download" and a compatible asset is available, the app SHALL download the asset to the OS temporary directory using `dio` and display download progress as a percentage.

MUST show a `LinearProgressIndicator` during download.

#### Scenario: download completes successfully

Given a compatible asset is available and the downloader returns a valid file path,
when the user taps "Download",
then the progress indicator is shown and eventually replaced by an install/open button.

#### Scenario: download fails

Given the downloader throws an error,
when the user taps "Download",
then a SnackBar is shown with a localized error message and the banner reverts to idle state.

### Requirement: OS handoff for installation

After a successful download, the app SHALL call `launchUrl` with a `file://` URI pointing to the downloaded file, handing off to the OS installer/file manager.

#### Scenario: install button launches file URI

Given a file has been downloaded to a temp path,
when the user taps the install/open button,
then `launchUrl(Uri.file(path))` is called.

### Requirement: Browser fallback when no compatible asset

When `selectAssetForPlatform` returns `null`, the "Download" button MUST fall back to the existing behaviour of opening the GitHub release page in an external browser.

#### Scenario: fallback to browser when no asset matches

Given no compatible asset exists for the running platform,
when the user taps "Download",
then `launchUrl` opens the `releaseUrl` in an external browser.

### Requirement: UpdateDownloader is injectable for testing

`UpdateDownloader` SHALL be an abstract interface overridable via Riverpod so tests can inject a fake implementation.

### Requirement: UpdateInstaller is injectable for testing

`UpdateInstaller` SHALL be an abstract interface overridable via Riverpod so tests can inject a fake implementation.

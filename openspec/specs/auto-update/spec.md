# auto-update Specification

## Purpose

Defines how GeekPlayer checks GitHub Releases for a newer version and delivers an opt-in, dismissible update banner in the Settings About section. Check errors are suppressed from the UI, and the checker is injectable for deterministic testing.
## Requirements
### Requirement: App checks GitHub Releases for a newer version

The app SHALL query `https://api.github.com/repos/geekjapan/GeekPlayer/releases/latest` when the Settings screen loads, compare `tag_name` against the running version from `package_info_plus`, and return an `UpdateAvailable` or `UpToDate` result.

#### Scenario: update available

Given the running version is `0.1.0` and GitHub Releases returns `tag_name: "v0.2.0"`,
when `checkForUpdate("0.1.0")` is called,
then it returns `UpdateAvailable(latestVersion: "0.2.0", releaseUrl: <html_url>)`.

#### Scenario: up to date

Given the running version is `0.2.0` and GitHub Releases returns `tag_name: "v0.2.0"`,
when `checkForUpdate("0.2.0")` is called,
then it returns `UpToDate`.

#### Scenario: malformed tag name treated as up to date

Given GitHub Releases returns `tag_name: "release/0.2.0"` (non-semver),
when `checkForUpdate("0.1.0")` is called,
then it returns `UpToDate` (silent no-op).

### Requirement: App shows an update banner in the Settings About section

When an update is available, the app MUST render an `UpdateBanner` in the Settings About section with the available version, a "Download" action, and a "Dismiss" action.

#### Scenario: banner shown on update available

Given `UpdateAvailable(latestVersion: "0.2.0", releaseUrl: "https://github.com/...")` is returned,
when the Settings screen loads and the About section renders,
then an `UpdateBanner` is visible showing the available version and "Download" / "Dismiss" actions.

#### Scenario: banner dismissed by user

Given the update banner is visible,
when the user taps "Dismiss",
then the banner is hidden for the current session.

#### Scenario: download opens release page

Given the update banner is visible,
when the user taps "Download",
then `url_launcher` opens the `releaseUrl` in an external browser.

### Requirement: Update check errors are silently suppressed in the UI

Network and HTTP errors MUST be mapped to existing `AppError` variants, logged, and SHALL NOT show a banner.

#### Scenario: network unreachable — no banner shown

Given the device is offline or DNS fails,
when `checkForUpdate` is called,
then it throws `NetworkUnreachableError` and no banner is shown.

#### Scenario: upstream server error — no banner shown

Given GitHub Releases returns HTTP 500,
when `checkForUpdate` is called,
then it throws `UpstreamUnavailableError(statusCode: 500)` and no banner is shown.

### Requirement: UpdateChecker is injectable for testing

`UpdateChecker` SHALL be an abstract interface overridable via Riverpod so tests can inject deterministic fake implementations.

#### Scenario: fake checker configured with update available

Given a `FakeUpdateChecker` configured to return `UpdateAvailable`,
when it is injected via `ProviderScope(overrides: [...])`,
then the `UpdateBanner` widget renders.

#### Scenario: fake checker configured as up to date

Given a `FakeUpdateChecker` configured to return `UpToDate`,
when it is injected via `ProviderScope(overrides: [...])`,
then no `UpdateBanner` is rendered.

### Requirement: Platform-specific asset selection

The app SHALL select the correct GitHub release asset for the running platform using a pure function `selectAssetForPlatform(List<ReleaseAsset> assets, TargetPlatform platform)`.

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

When the user taps "Download" and a compatible asset is available, the app SHALL download the asset to the OS temporary directory using `dio` and display download progress as a percentage. The app MUST show a `LinearProgressIndicator` during download.

#### Scenario: download completes successfully

Given a compatible asset is available and the downloader returns a valid file path,
when the user taps "Download",
then the progress indicator is shown and eventually replaced by an install/open button.

#### Scenario: download fails

Given the downloader throws an error,
when the user taps "Download",
then a SnackBar is shown with a localized error message and the banner reverts to idle state.

### Requirement: OS handoff for installation

After a successful download, the app SHALL hand the downloaded file off to the OS for installation in a platform-appropriate way:

- On **Android**, the app SHALL launch the system package-installer intent for the downloaded `.apk` using a `FileProvider` `content://` URI (authority `${applicationId}.fileprovider`) with mime type `application/vnd.android.package-archive`, declaring the `REQUEST_INSTALL_PACKAGES` permission. The app SHALL NOT pass a `file://` URI to the installer on Android (it raises `FileUriExposedException` on Android 7+).
- On **macOS, Windows, and Linux**, the app SHALL retain the existing behavior of calling `launchUrl` with a `file://` URI pointing to the downloaded file, handing off to the OS installer/file manager.

When the OS handoff cannot be performed (no installer, permission denied, or launch failure), the installer SHALL surface the failure to the caller so the banner can revert to its idle/error state.

#### Scenario: Android routes through a content URI install intent

- **WHEN** a `.apk` has been downloaded on Android and the user taps the install/open button
- **THEN** the app launches the package-installer intent with a `FileProvider` `content://` URI (mime `application/vnd.android.package-archive`), not a `file://` URI

#### Scenario: desktop and Linux keep the file URI handoff

- **WHEN** a file has been downloaded on macOS, Windows, or Linux and the user taps the install/open button
- **THEN** `launchUrl(Uri.file(path))` is called as before

#### Scenario: handoff failure is surfaced to the caller

- **WHEN** the platform handoff fails (installer unavailable, permission denied, or launch returns false)
- **THEN** `openForInstall` throws (or otherwise reports failure) so the update banner reverts to its idle/error state

### Requirement: Browser fallback when no compatible asset

When `selectAssetForPlatform` returns `null`, the "Download" button MUST fall back to the existing behaviour of opening the GitHub release page in an external browser.

#### Scenario: fallback to browser when no asset matches

Given no compatible asset exists for the running platform,
when the user taps "Download",
then `launchUrl` opens the `releaseUrl` in an external browser.

### Requirement: UpdateDownloader is injectable for testing

`UpdateDownloader` SHALL be an abstract interface overridable via Riverpod so tests can inject a fake implementation.

#### Scenario: fake downloader is injected

Given a fake `UpdateDownloader` configured to report progress and return a file,
when it is injected via `ProviderScope(overrides: [...])`,
then the banner observes the fake's progress and completion instead of performing a real network download.

### Requirement: UpdateInstaller is injectable for testing

`UpdateInstaller` SHALL be an abstract interface overridable via Riverpod so tests can inject a fake implementation.

#### Scenario: fake installer is injected

Given a fake `UpdateInstaller`,
when it is injected via `ProviderScope(overrides: [...])` and the user taps the install/open button,
then the fake's `open` method is invoked with the downloaded file instead of launching the OS handler.


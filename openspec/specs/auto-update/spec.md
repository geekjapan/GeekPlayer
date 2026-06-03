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

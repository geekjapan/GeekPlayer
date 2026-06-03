## Capability: auto-update

Defines how GeekPlayer checks for newer releases and delivers an opt-in download prompt to the user.

## ADDED Requirements

### Version Check

The app checks for newer releases by querying the GitHub Releases API and comparing the result against the running version.

#### Scenario: update available

Given the running version is `0.1.0` and GitHub Releases returns `tag_name: "v0.2.0"`,
when `checkForUpdate("0.1.0")` is called,
then it returns `UpdateAvailable(latestVersion: "0.2.0", releaseUrl: <html_url>)`.

#### Scenario: up to date

Given the running version is `0.2.0` and GitHub Releases returns `tag_name: "v0.2.0"`,
when `checkForUpdate("0.2.0")` is called,
then it returns `UpToDate`.

#### Scenario: malformed tag name

Given GitHub Releases returns `tag_name: "release/0.2.0"` (non-semver),
when `checkForUpdate("0.1.0")` is called,
then it returns `UpToDate` (silent no-op).

### Update Delivery

The app surfaces an update banner in the Settings About section when an update is available.

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

### Error Handling

Network and HTTP errors are mapped to existing `AppError` variants and suppressed from the UI.

#### Scenario: network unreachable

Given the device is offline or DNS fails,
when `checkForUpdate` is called,
then it throws `NetworkUnreachableError` and no banner is shown.

#### Scenario: upstream server error

Given GitHub Releases returns HTTP 500,
when `checkForUpdate` is called,
then it throws `UpstreamUnavailableError(statusCode: 500)` and no banner is shown.

### Testability

The checker is an abstract interface that can be overridden in tests.

#### Scenario: fake checker returns update available

Given a `FakeUpdateChecker` configured to return `UpdateAvailable`,
when it is injected via `ProviderScope(overrides: [...])`,
then the `UpdateBanner` widget renders the banner.

#### Scenario: fake checker returns up to date

Given a `FakeUpdateChecker` configured to return `UpToDate`,
when it is injected via `ProviderScope(overrides: [...])`,
then no `UpdateBanner` is rendered.

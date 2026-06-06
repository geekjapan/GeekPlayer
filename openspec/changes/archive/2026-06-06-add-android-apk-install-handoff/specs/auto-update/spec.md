## MODIFIED Requirements

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

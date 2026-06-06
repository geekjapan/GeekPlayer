## Why

In-app update install is broken on Android. The `auto-update` capability's "OS handoff for installation" requirement has every platform call `launchUrl(Uri.file(path))`, but on Android 7+ a `file://` URI throws `FileUriExposedException` and Android 8+ requires the `REQUEST_INSTALL_PACKAGES` permission plus a `FileProvider` `content://` URI launched via the package-installer intent. So the downloaded APK never reaches the installer on Android. This is the known residual from `expand-auto-update-delivery` (HANDOFF §7); macOS/Windows/Linux already work.

## What Changes

- **BREAKING (spec)** Make the "OS handoff for installation" requirement **platform-aware**: Android routes a downloaded `.apk` through a `FileProvider` `content://` URI fired via the Android package-installer intent (mime `application/vnd.android.package-archive`); macOS/Windows/Linux keep the existing `file://` `launchUrl` handoff unchanged.
- `AndroidManifest.xml` (main): declare a `<provider>` `FileProvider` (authority `${applicationId}.fileprovider`), add `REQUEST_INSTALL_PACKAGES` `uses-permission`, and add a `res/xml/file_paths.xml` resource scoping the cache/temp download dir.
- Wire the Android install path so `UpdateInstaller.openForInstall` launches the install intent with the content URI on Android, while staying abstract + Riverpod-overridable for tests. The concrete intent mechanism (a maintained pub package vs a platform channel) is decided in design/grill against the roadmap readiness checklist (license must not be GPL/LGPL; non-Android targets unaffected).
- Localized error surfacing stays as today (existing download/handoff SnackBar path); no new user-visible strings expected beyond reuse.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `auto-update`: the "OS handoff for installation" requirement changes from a single all-platform `launchUrl(Uri.file(path))` contract to a platform-aware contract — Android uses a FileProvider content URI + package-installer intent; other desktop/Linux platforms retain the `file://` handoff. "UpdateInstaller is injectable for testing" is preserved (platform routing is unit-tested via injected fakes).

## Impact

- **Code**: `app/lib/features/update/update_installer.dart` (platform routing in the live installer), its provider, and update-flow tests under `app/test/features/update/`.
- **Android config**: `app/android/app/src/main/AndroidManifest.xml` (+ `<provider>`, `REQUEST_INSTALL_PACKAGES`, `<queries>` for the install action), new `app/android/app/src/main/res/xml/file_paths.xml`.
- **Dependencies**: adds `open_filex` (BSD-3-Clause, Android-only use) to fire the install intent via its bundled `FileProvider` (grill 20260606). No change to non-Android platforms.
- **CI**: install intent cannot run on CI without a device; platform routing is unit-tested via injected fakes and the live Android path is verified manually. No CI matrix change required.
- **ADR**: none. This stays within the existing `auto-update` capability and the OSS GitHub-Releases distribution model.

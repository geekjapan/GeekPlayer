## Context

`expand-auto-update-delivery` shipped an in-app updater: `UpdateDownloader` fetches the
platform asset (dio) into a temp path, then `UpdateInstaller.openForInstall(path)` hands it
to the OS. The live installer (`LaunchUrlUpdateInstaller`) calls
`launchUrl(Uri.file(path), mode: externalApplication)` for **all** platforms.

That works on macOS/Windows/Linux but is broken on Android:

- Android 7+ (`targetSdk >= 24`) forbids exposing `file://` URIs across app boundaries —
  passing one to another app throws `FileUriExposedException`. APKs must be shared via a
  `FileProvider` `content://` URI.
- Android 8+ requires the `REQUEST_INSTALL_PACKAGES` permission to launch the package
  installer for "install from unknown sources".
- The installer is launched via an intent (`ACTION_VIEW` / `ACTION_INSTALL_PACKAGE`) with
  mime `application/vnd.android.package-archive` and `FLAG_GRANT_READ_URI_PERMISSION`.

Constraints: OSS / non-store distribution (GitHub Releases), Apache-2.0 app, new deps must
not be GPL/LGPL and must not break the non-Android build (roadmap readiness checklist). The
install intent cannot run on CI (no device), so the design must keep the seam unit-testable.

## Goals / Non-Goals

**Goals:**
- Make Android in-app APK install actually reach the system installer.
- Keep macOS/Windows/Linux behavior byte-for-byte unchanged.
- Preserve `UpdateInstaller` as an abstract, Riverpod-overridable seam so platform routing is
  unit-tested via injected fakes (no device needed in CI).
- Add the Android manifest plumbing (FileProvider, permission, install-action query) once.

**Non-Goals:**
- No silent/background auto-install; the user still explicitly taps install (unchanged UX).
- No change to the download path, banner UI, asset selection, or non-Android handoff.
- No new ADR; this stays within the `auto-update` capability and the OSS distribution model.
- iOS is out of scope (no sideload install flow; non-store distribution per ADR-0006).

## Decisions

### D1. Platform-route inside the live installer; keep the abstraction

`LaunchUrlUpdateInstaller` becomes platform-aware: on Android it fires the install intent via
a content URI; on every other platform it keeps the current `launchUrl(Uri.file(path))`. The
`UpdateInstaller` interface and `updateInstallerProvider` are unchanged, so existing fake
injection in tests still works.

To keep **both** branches host-testable without a device, the live installer takes three
injected seams via constructor (all defaulting to the production functions):
- `platform` — a `bool Function()` (default `() => Platform.isAndroid`) selecting the branch.
  `Platform.isAndroid` is `false` on the CI host, so the Android branch is unreachable in a
  host test unless injected; the predicate makes it drivable.
- `launchFileUrl` — a `Future<bool> Function(Uri)` (default wraps
  `launchUrl(uri, mode: externalApplication)`) for the non-Android `file://` branch.
- `androidInstall` — a `Future<void> Function(String path)` (default = the D2 mechanism) for the
  Android content-URI install intent.

Tests inject fakes for these to assert routing and failure propagation on the host; the real
`androidInstall` is exercised manually on a device.

Alternative considered: a second `AndroidUpdateInstaller` selected by the provider per
platform. Rejected — it spreads platform logic into provider wiring and complicates override;
a single live implementation with injected seams is simpler and equally testable.

### D2. Install-intent mechanism — **DECIDED: `open_filex`, Android-only, bundled provider** (grill 20260606)

Fire the Android install intent via the **`open_filex`** pub package (BSD-3-Clause, maintained,
not GPL/LGPL). On Android it builds a `FileProvider` content URI and launches `ACTION_VIEW`
with the file's mime; for an `.apk` this resolves to the system installer. It returns a typed
`OpenResult` we map to success/failure (non-`done` → throw so the banner reverts).

- Used **Android-only** — the live installer calls `OpenFilex.open(path)` only in the Android
  branch; macOS/Windows/Linux keep `launchUrl(Uri.file(path))` unchanged.
- **Rely on the package's bundled `FileProvider`** (authority `${applicationId}.fileProvider`,
  registered by `open_filex`'s own manifest). We therefore do **not** hand-declare a `<provider>`
  (doing so would collide on the merged manifest). We still add `REQUEST_INSTALL_PACKAGES` and a
  `<queries>` entry ourselves, and no `res/xml/file_paths.xml` is needed (the package ships one
  covering the cache dir where `UpdateDownloader` writes).

Rejected: a hand-written Kotlin platform channel (zero new dep but adds native code +
MethodChannel to maintain/test, re-implementing what `open_filex` provides).

The default `androidInstall` seam (D1) is therefore `(path) => OpenFilex.open(path)` wrapped to
throw on a non-`done` result; tests inject a fake.

### D3. Manifest plumbing (with D2 = `open_filex`)

The app declares in `android/app/src/main/AndroidManifest.xml`:
- `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />`.
- A `<queries>` intent entry for `ACTION_VIEW` + the apk mime
  (`application/vnd.android.package-archive`) so package visibility (Android 11+) lets us
  resolve the installer.

We do **not** declare our own `<provider>` and do **not** add `res/xml/file_paths.xml`:
`open_filex` registers its own `FileProvider` (authority `${applicationId}.fileProvider`) and
ships a `file_paths` covering the cache dir. Declaring a second provider with a clashing
authority would fail the manifest merge.

### D4. CI-safety and testing

- Unit tests assert platform routing through the injected-fake seam (fake `UpdateInstaller`
  records `openForInstall` calls) — unchanged from today, ensuring the banner flow still wires
  to the installer on every platform.
- Host-side tests drive both branches via the injected seams (D1): with `platform: () => false`
  the desktop branch calls the injected `launchFileUrl` with `Uri.file(path)`; with
  `platform: () => true` the Android branch calls the injected `androidInstall` (never a
  `file://` URI). Failure propagation is asserted by making a seam throw / return false. The
  real `androidInstall` mechanism is verified manually on a device. No CI matrix change.

## Risks / Trade-offs

- **[Bundled FileProvider authority collision]** Declaring our own provider with the authority
  `open_filex` already registers would fail the manifest merge. → Resolved by D3: rely on the
  package's bundled provider and do not hand-declare one.
- **[`REQUEST_INSTALL_PACKAGES` review friction]** The permission is sensitive on Play Store,
  but GeekPlayer is GitHub-Releases-only (non-store), so store policy does not apply. → Note in
  proposal/impact; no store submission.
- **[Untestable on CI]** The live install intent needs a device. → Mitigated by the abstract
  seam + injected-fake unit tests; manual on-device verification step in tasks.
- **[New dependency]** Adds one pub package (if D2=A). → Permissive license, Android-only use,
  no effect on other targets; if undesirable, D2=B (platform channel) avoids the dep.

## Open Questions

(None — D2 resolved in grill 20260606: `open_filex`, Android-only, bundled provider.)

### Resolved during self-grill

- **Download dir** — `UpdateDownloader` writes to `getTemporaryDirectory()`
  (`update_downloader.dart:48`), which on Android is `context.getCacheDir()`. So a self-owned
  `FileProvider` would scope `<cache-path>` in `file_paths.xml`; `open_filex`'s bundled provider
  already covers the cache dir. (Resolved.)
- **iOS scope** — `selectAssetForPlatform` returns `null` for iOS/fuchsia
  (`release_asset.dart:62`), so the banner falls back to a browser and there is no install path
  to fix. iOS is correctly out of scope. (Resolved.)
- **Failure surfacing** — `UpdateBanner._install` (`update_banner.dart:210`) already wraps
  `openForInstall` in `try { } on Object` and shows a SnackBar, so an installer that throws on
  handoff failure integrates without UI changes. (Resolved.)

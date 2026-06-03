## 1. Dependencies

- [x] 1.1 Add `image: ^4.5.0` to `app/pubspec.yaml` dependencies
- [x] 1.2 Run `flutter pub get` in `app/`

## 2. Core Implementation

- [x] 2.1 Create `app/lib/core/ml/cpu_image_upscaler.dart` with `CpuImageUpscaler implements ImageUpscaler` using `image` package bicubic interpolation
- [x] 2.2 Update `imageUpscalerProvider` in `app/lib/core/ml/providers.dart` to return `CpuImageUpscaler` instead of `PassthroughUpscaler`
- [x] 2.3 Run `dart run build_runner build --delete-conflicting-outputs` in `app/`

## 3. Localization

- [x] 3.1 Add `mangaUpscaleAction`, `mangaUpscaleInProgress`, `mangaUpscaleError` keys to `app/lib/l10n/app_ja.arb`
- [x] 3.2 Add same keys (parity) to `app/lib/l10n/app_en.arb`
- [x] 3.3 Run `flutter gen-l10n` in `app/`

## 4. Manga Viewer UI

- [x] 4.1 Add upscale state (`_upscaling`, `_upscaledBytes`) to `_MangaViewerScreenState` in `manga_viewer_screen.dart`
- [x] 4.2 Add `_upscaleCurrentPage()` method that reads `imageUpscalerProvider` and calls `upscale()`
- [x] 4.3 Add `Icons.auto_fix_high` AppBar action button with `mangaUpscaleAction` tooltip wired to `_upscaleCurrentPage()`
- [x] 4.4 Show `CircularProgressIndicator` overlay when `_upscaling` is true
- [x] 4.5 Display upscaled image when `_upscaledBytes` is non-null; fall back to original on error

## 5. Tests

- [x] 5.1 Create `app/test/core/ml/cpu_image_upscaler_test.dart` — unit test 2x upscale returns doubled dimensions, 1x returns same dimensions
- [x] 5.2 Create `app/test/features/manga/manga_viewer_upscale_test.dart` — widget test: upscale button visible in AppBar when controls visible

## 6. OSS Licenses

- [x] 6.1 Run `dart run flutter_oss_licenses:generate -o lib/oss_licenses.dart -i flutter` in `app/`

## 7. Quality Gate

- [x] 7.1 `dart format --output=none --set-exit-if-changed .` passes in `app/`
- [x] 7.2 `flutter analyze --fatal-infos` passes in `app/`
- [x] 7.3 `flutter test` passes all tests in `app/`

## Why

GeekPlayer ships `PassthroughUpscaler` as the default `ImageUpscaler` — it returns input bytes unchanged while reporting scaled-up dimensions, producing blurry output. Landing a real CPU bicubic upscaler turns the existing ML seam into a genuinely usable feature for the first time and adds a visible "高画質化 / Upscale" action in the manga viewer.

## What Changes

- Add `CpuImageUpscaler` — a pure-Dart bicubic upscaler using the `image` package that replaces `PassthroughUpscaler` as the default `imageUpscalerProvider` return value.
- Add an "Upscale / 高画質化" icon button to the `MangaViewerScreen` AppBar that triggers upscaling of the current page and shows loading / error feedback.
- Add ARB localization keys (`mangaUpscaleAction`, `mangaUpscaleInProgress`, `mangaUpscaleError`) to both `app_ja.arb` and `app_en.arb`.
- Depend on the `image` package (pub.dev, MIT license) for bicubic pixel interpolation.
- Regenerate `oss_licenses.dart` after adding the `image` package.

## Capabilities

### New Capabilities

- `ai-image-upscaler`: CPU bicubic image upscaling via the `image` package — exposes `CpuImageUpscaler implements ImageUpscaler` and wires it into `imageUpscalerProvider`. Provides the user-facing upscale action in the manga viewer.

### Modified Capabilities

- `ml-runtime`: `imageUpscalerProvider` now returns `CpuImageUpscaler` instead of `PassthroughUpscaler`. The `ImageUpscaler` contract is unchanged; only the default provider implementation changes.

## Non-goals

- GPU / native backends (CoreML, NNAPI, TensorRT) — future work per `ml-runtime` spec.
- AI model inference (super-resolution neural networks) — future v1.0 milestone.
- Upscaling in video or audio pipelines.
- Persistent caching of upscaled images across sessions.

## Impact

- `app/lib/core/ml/providers.dart` (`imageUpscaler` provider, line 22) — swap `PassthroughUpscaler()` for `CpuImageUpscaler()`.
- `app/lib/features/manga/presentation/manga_viewer_screen.dart` — add AppBar action and upscale state.
- `app/lib/l10n/app_ja.arb`, `app/lib/l10n/app_en.arb` — 3 new keys each.
- `app/pubspec.yaml` — add `image: ^4.5.0` dependency.
- `app/lib/oss_licenses.dart` — regenerated after dep add.
- New file: `app/lib/core/ml/cpu_image_upscaler.dart`.
- New test files: `app/test/core/ml/cpu_image_upscaler_test.dart`, `app/test/features/manga/manga_viewer_upscale_test.dart`.

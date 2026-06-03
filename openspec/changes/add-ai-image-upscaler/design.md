## Context

The existing `ml-runtime` abstraction (`ImageUpscaler` interface, `UpscaleRequest`, `UpscaleResult`, `imageUpscalerProvider`) was established in `add-ml-runtime-abstraction`. The default implementation, `PassthroughUpscaler`, returns input bytes unchanged — no actual pixel interpolation occurs. This change lands the first real CPU upscaler on top of that seam, making the feature visible to users via a manga viewer action.

## Goals / Non-Goals

**Goals:**
- Ship `CpuImageUpscaler` with genuine bicubic interpolation (not passthrough).
- Wire `CpuImageUpscaler` as the default `imageUpscalerProvider` value.
- Add an "Upscale / 高画質化" action to `MangaViewerScreen` that uses the provider.
- Full localization (ja + en) for the 3 new UI strings.
- Unit tests for `CpuImageUpscaler` and widget tests for the manga viewer action.

**Non-Goals:**
- GPU or native ML backend implementations.
- Persistent cache for upscaled pages.
- Upscaling in video, audio, or book reader pipelines.

## Decisions

### D1: Use the `image` package for bicubic interpolation

**Choice**: Depend on `image` (pub.dev, MIT license) and call `copyResize(..., interpolation: Interpolation.cubic)`.

**Rationale**: Pure-Dart, no native code, cross-platform, well-tested, already present on pub.dev. The `dart:ui` codec path requires a Flutter engine context which breaks unit tests run in pure-Dart mode.

**Alternative considered**: `dart:ui` `decodeImageFromList` + canvas-based scaling — usable in flutter_test but not pure-Dart unit tests, and ties the implementation to the Flutter engine.

### D2: Replace `PassthroughUpscaler` as the provider default, keep it accessible

**Choice**: `imageUpscalerProvider` returns `const CpuImageUpscaler()`. `PassthroughUpscaler` stays in the codebase (tests reference it directly).

**Rationale**: The provider is `keepAlive: true` — switching the default is a one-line change in `providers.dart`. No existing production code holds a reference to `PassthroughUpscaler` directly.

### D3: Manga viewer action — in-widget state, no separate provider

**Choice**: Add `_upscaling` / `_upscaledBytes` state fields to `_MangaViewerScreenState`. The upscale action is per-session and not persisted.

**Rationale**: Avoids provider proliferation for a transient UI state. Persisting upscaled images across sessions is deferred to a future caching layer.

### D4: Decode-resize-encode pipeline

**Choice**: decode PNG/JPEG bytes → `image.copyResize` (bicubic) → re-encode PNG → return as `UpscaleResult`.

**Rationale**: Simplest correct pipeline. PNG lossless re-encoding preserves quality; JPEG artifacts on the source do not degrade further.

## Risks / Trade-offs

- [Risk] Large page images may take 100 ms – 1 s on low-end CPUs → Mitigation: run on an `Isolate` via `compute()` to avoid jank; show a progress indicator.
- [Risk] `image` package adds ~250 KB to compiled binary size → Mitigation: acceptable for v0.1 scope; tree-shaking eliminates unused codecs.
- [Risk] Re-encoding to PNG inflates byte count for JPEG source images → Mitigation: future work can detect source format and re-encode to JPEG; out of scope here.

## Migration Plan

No database schema changes. No breaking API changes. The `ImageUpscaler` interface is unchanged. Replacing `PassthroughUpscaler` with `CpuImageUpscaler` in the provider is the only runtime behavior change, and all existing tests that override `imageUpscalerProvider` are unaffected.

## Open Questions

None blocking this increment.

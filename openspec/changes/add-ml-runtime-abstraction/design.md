## Overview

A pure-Dart ML runtime abstraction at `app/lib/core/ml/` that provides:

1. A `MlBackend` enum mapping each target OS to its preferred accelerator.
2. `MlCapabilities` describing the active backend.
3. `UpscaleRequest` / `UpscaleResult` typed value objects for the upscaling API.
4. `ImageUpscaler` — a single-method async interface that concrete backends implement.
5. `MlRuntime` — detects the current platform and exposes `MlCapabilities`.
6. `PassthroughUpscaler` — a CPU-only no-op that returns the input bytes unchanged
   (dimensions updated to requested scale); used until native backends land.
7. Riverpod providers wiring the above into the app DI graph.

## Directory layout

```
app/lib/core/ml/
  ml_backend.dart          # enum MlBackend { coreml, nnapi, onnxRuntime, tensorRt, cpu }
  ml_capabilities.dart     # @immutable class MlCapabilities { final MlBackend backend; }
  upscale_request.dart     # @immutable class UpscaleRequest
  upscale_result.dart      # @immutable class UpscaleResult
  image_upscaler.dart      # abstract interface class ImageUpscaler
  ml_runtime.dart          # class MlRuntime (injectable platform detection)
  passthrough_upscaler.dart# class PassthroughUpscaler implements ImageUpscaler
  providers.dart           # @Riverpod mlRuntime / imageUpscaler
  providers.g.dart         # generated

app/test/core/ml/
  ml_runtime_test.dart
  passthrough_upscaler_test.dart
  providers_test.dart
```

## Key design decisions

### Injectable platform detection

`MlRuntime` accepts a `TargetPlatformResolver` function type rather than calling
`Platform.isIOS` etc. directly. This avoids `dart:io` in unit tests:

```dart
typedef TargetPlatformResolver = TargetPlatform Function();

class MlRuntime {
  const MlRuntime({TargetPlatformResolver? resolver})
    : _resolver = resolver ?? _defaultResolver;
  ...
}
```

The default resolver uses `defaultTargetPlatform` from `package:flutter/foundation.dart`,
which is safe in unit tests when the test environment overrides it via
`debugDefaultTargetPlatformOverride`.

### Backend selection

```
TargetPlatform.iOS | macOS  → MlBackend.coreml
TargetPlatform.android      → MlBackend.nnapi
TargetPlatform.windows      → MlBackend.tensorRt
TargetPlatform.linux        → MlBackend.onnxRuntime
fallback (fuchsia, etc.)    → MlBackend.cpu
```

### PassthroughUpscaler

Returns input bytes unchanged. `outWidth = srcWidth * scaleFactor`,
`outHeight = srcHeight * scaleFactor`. Backend is always `MlBackend.cpu`.
No image decoding/encoding occurs — this is a placeholder contract implementation.

### Riverpod providers

```dart
@Riverpod(keepAlive: true)
MlRuntime mlRuntime(Ref ref) => const MlRuntime();

@Riverpod(keepAlive: true)
ImageUpscaler imageUpscaler(Ref ref) =>
    PassthroughUpscaler(ref.watch(mlRuntimeProvider));
```

Both are `keepAlive: true` (singletons, no per-widget lifecycle).

## Value object equality

`UpscaleResult` and `MlCapabilities` implement `==` and `hashCode` manually
(no code-gen dependency to keep the core layer thin).

## What is NOT designed here

- Native plugin bridges (CoreML, NNAPI, ONNX, TensorRT) — deferred.
- Model download/caching — deferred to v1.0 model management change.
- Streaming progress API — not needed for passthrough; can be added when real
  backends land.

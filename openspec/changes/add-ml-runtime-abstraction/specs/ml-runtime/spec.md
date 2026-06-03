# ml-runtime

Cross-platform ML runtime abstraction for on-device AI upscaling.

## ADDED Requirements

1. SHALL expose a `MlBackend` enum with values `coreml`, `nnapi`, `onnxRuntime`,
   `tensorRt`, and `cpu` representing the available hardware accelerator backends.

2. SHALL provide a `MlCapabilities` immutable value object carrying the selected
   `MlBackend`; instances MUST implement `==` and `hashCode`.

3. SHALL provide an `UpscaleRequest` immutable value object carrying `bytes`
   (Uint8List), `srcWidth` (int), `srcHeight` (int), and `scaleFactor` (int ≥ 1).

4. SHALL provide an `UpscaleResult` immutable value object carrying `bytes`
   (Uint8List), `outWidth` (int), `outHeight` (int), and `backend` (MlBackend);
   instances MUST implement `==` and `hashCode`.

5. SHALL define an `ImageUpscaler` abstract interface with a single async method
   `Future<UpscaleResult> upscale(UpscaleRequest request)`.

6. SHALL provide a `MlRuntime` class that selects a `MlBackend` based on the
   current platform: iOS/macOS → `coreml`, Android → `nnapi`, Windows → `tensorRt`,
   Linux → `onnxRuntime`, all others → `cpu`.

7. MUST make platform detection injectable in `MlRuntime` so that unit tests can
   exercise any platform branch without requiring `dart:io`.

8. SHALL provide a `PassthroughUpscaler` that implements `ImageUpscaler` using only
   pure-Dart code (no native plugins, no FFI), returning input bytes with
   `outWidth = srcWidth * scaleFactor` and `outHeight = srcHeight * scaleFactor`.

9. SHALL expose Riverpod providers `mlRuntimeProvider` and `imageUpscalerProvider`,
   both `keepAlive: true`, wired via `@Riverpod` codegen.

10. MUST NOT introduce any new ML-specific or native-bridge dependencies in
    `app/pubspec.yaml`; all code MUST compile with the existing dependency set.

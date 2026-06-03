# ml-runtime Specification

## Purpose

Establishes the cross-platform ML runtime abstraction (`app/lib/core/ml/`) for on-device AI upscaling: backend enumeration, image upscale value objects, an `ImageUpscaler` interface, platform-based backend selection, a pure-Dart passthrough default, and Riverpod wiring. Concrete native backends (CoreML/NNAPI/ONNX Runtime/TensorRT) and real upscaler models are future changes that plug into this seam.

## Requirements

### Requirement: ML backend enumeration

The system SHALL expose an `MlBackend` enum with values `coreml`, `nnapi`, `onnxRuntime`, `tensorRt`, and `cpu` representing the available hardware accelerator backends.

#### Scenario: Backend values are stable

- **WHEN** `MlBackend.values` is enumerated
- **THEN** it contains exactly `coreml`, `nnapi`, `onnxRuntime`, `tensorRt`, and `cpu`

### Requirement: ML capabilities value object

The system SHALL provide an immutable `MlCapabilities` value object carrying the selected `MlBackend`. Instances MUST implement `==` and `hashCode`.

#### Scenario: Equal capabilities compare equal

- **GIVEN** two `MlCapabilities` constructed with the same `MlBackend`
- **THEN** they are `==` and share the same `hashCode`

### Requirement: Upscale request and result value objects

The system SHALL provide immutable `UpscaleRequest` (`bytes` Uint8List, `srcWidth` int, `srcHeight` int, `scaleFactor` int ≥ 1) and `UpscaleResult` (`bytes` Uint8List, `outWidth` int, `outHeight` int, `backend` MlBackend) value objects. Both MUST implement `==` and `hashCode`.

#### Scenario: Result carries output dimensions and backend

- **WHEN** an `UpscaleResult` is constructed with `outWidth`, `outHeight`, and a `backend`
- **THEN** those values are readable and equality holds for identical field values

### Requirement: ImageUpscaler interface

The system SHALL define an `ImageUpscaler` abstract interface with a single async method `Future<UpscaleResult> upscale(UpscaleRequest request)`.

#### Scenario: Concrete upscaler satisfies the interface

- **WHEN** a concrete class implements `ImageUpscaler`
- **THEN** it provides `Future<UpscaleResult> upscale(UpscaleRequest request)`

### Requirement: Platform-based backend selection

The system SHALL provide an `MlRuntime` class that selects an `MlBackend` based on the current platform: iOS/macOS → `coreml`, Android → `nnapi`, Windows → `tensorRt`, Linux → `onnxRuntime`, all others → `cpu`.

#### Scenario: Each platform maps to its backend

- **WHEN** `MlRuntime.describe()` is evaluated for iOS, macOS, Android, Windows, and Linux
- **THEN** the selected backend is `coreml`, `coreml`, `nnapi`, `tensorRt`, and `onnxRuntime` respectively

#### Scenario: Unknown platform falls back to CPU

- **WHEN** the resolved platform is none of the above (e.g. Fuchsia)
- **THEN** the selected backend is `cpu`

### Requirement: Injectable platform detection

The `MlRuntime` MUST make platform detection injectable so unit tests can exercise any platform branch without requiring `dart:io`.

#### Scenario: Test injects a platform resolver

- **GIVEN** an `MlRuntime` constructed with a resolver returning `TargetPlatform.android`
- **THEN** `describe()` selects `nnapi` without touching `dart:io`

### Requirement: Pure-Dart passthrough upscaler

The system SHALL provide a `PassthroughUpscaler` that implements `ImageUpscaler` using only pure-Dart code (no native plugins, no FFI), returning the input bytes with `outWidth = srcWidth * scaleFactor`, `outHeight = srcHeight * scaleFactor`, and `backend = cpu`.

#### Scenario: Passthrough scales dimensions and reports CPU

- **GIVEN** an `UpscaleRequest` with `srcWidth=100`, `srcHeight=50`, `scaleFactor=2`
- **WHEN** `PassthroughUpscaler().upscale(request)` resolves
- **THEN** the result has `outWidth=200`, `outHeight=100`, and `backend == MlBackend.cpu`

### Requirement: Riverpod providers for the ML runtime

The system SHALL expose Riverpod providers `mlRuntimeProvider` and `imageUpscalerProvider`, both `keepAlive: true`, wired via `@Riverpod` codegen, and overridable in tests.

#### Scenario: imageUpscalerProvider is overridable

- **WHEN** a test overrides `imageUpscalerProvider` with a fake `ImageUpscaler`
- **THEN** a consumer reading the provider observes the fake instance

### Requirement: No new native or ML dependencies

This capability MUST NOT introduce any new ML-specific or native-bridge dependencies in `app/pubspec.yaml`; all code MUST compile with the existing dependency set.

#### Scenario: pubspec dependencies are unchanged

- **WHEN** `app/pubspec.yaml` is diffed against the prior revision
- **THEN** no new dependency entries are added

# ml-runtime Specification

## Purpose

Establishes the cross-platform ML runtime abstraction (`app/lib/core/ml/`) for on-device AI upscaling: execution-provider-oriented backend enumeration, image upscale value objects, an `ImageUpscaler` interface, a platform-preferred backend plus an effective backend resolved by probing (per ADR-0007), a pure-Dart bicubic CPU floor, and Riverpod wiring. Concrete ONNX Runtime / GPU execution-provider backends and learned models are future changes that plug into this seam.

## Requirements

### Requirement: ML backend enumeration

The system SHALL expose an `MlBackend` enum oriented around execution providers (per ADR-0007): `coremlEp`, `nnapiEp`, `directmlEp`, `ortCpu`, and `bicubicCpu`. `bicubicCpu` is the pure-Dart universal floor; the others denote ONNX Runtime execution providers.

#### Scenario: Backend values are EP-oriented

- **WHEN** `MlBackend.values` is enumerated
- **THEN** it contains exactly `coremlEp`, `nnapiEp`, `directmlEp`, `ortCpu`, and `bicubicCpu`

### Requirement: ML capabilities value object

The system SHALL provide an immutable `MlCapabilities` value object carrying the `preferred` backend, the `effective` backend, the `modelState`, an `experimentalEnabled` flag, and a human-readable `reason`. Instances MUST implement `==` and `hashCode`.

#### Scenario: Equal capabilities compare equal

- **GIVEN** two `MlCapabilities` constructed with identical fields
- **THEN** they are `==` and share the same `hashCode`

#### Scenario: Capabilities expose preferred and effective separately

- **WHEN** an `MlCapabilities` is constructed with `preferred: coremlEp` and `effective: bicubicCpu`
- **THEN** both values are independently readable

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

### Requirement: Platform-based preferred backend selection

The system SHALL provide an `MlRuntime` that computes a platform-**preferred** `MlBackend`: iOS/macOS → `coremlEp`, Android → `nnapiEp`, Windows → `directmlEp`, Linux → `ortCpu`, all others → `bicubicCpu`. The preferred backend expresses intent only; the effective backend is resolved separately by probing.

#### Scenario: Each platform maps to its preferred backend

- **WHEN** the preferred backend is computed for iOS, macOS, Android, Windows, and Linux
- **THEN** it is `coremlEp`, `coremlEp`, `nnapiEp`, `directmlEp`, and `ortCpu` respectively

#### Scenario: Unknown platform prefers the CPU floor

- **WHEN** the resolved platform is none of the above (e.g. Fuchsia)
- **THEN** the preferred backend is `bicubicCpu`

### Requirement: Injectable platform detection

The `MlRuntime` MUST make platform detection, execution-provider availability, model state, and the experimental flag injectable so unit tests can exercise any branch without `dart:io`, real runtimes, or real models.

#### Scenario: Test injects all inputs

- **GIVEN** an `MlRuntime` constructed with a platform resolver, an execution-provider probe, a model-state resolver, and an experimental-flag resolver
- **THEN** `probe()` resolves using only the injected inputs and does not touch `dart:io`

### Requirement: Effective backend probe with fallback chain

The `MlRuntime` SHALL expose an async `probe()` returning `MlCapabilities` whose `effective` backend is resolved by a fallback chain: the platform-preferred execution provider, then `ortCpu`, then `bicubicCpu`. `bicubicCpu` is always available, so `probe()` MUST always return a usable effective backend and MUST NOT throw.

#### Scenario: Preferred EP is used when available

- **GIVEN** experimental is enabled, the model is present, and the preferred EP (`coremlEp`) probes available
- **WHEN** `probe()` resolves
- **THEN** `effective` is `coremlEp`

#### Scenario: Falls back to ORT CPU then bicubic

- **GIVEN** experimental is enabled and the model is present, but the preferred EP is unavailable
- **WHEN** `probe()` resolves
- **THEN** `effective` is `ortCpu` if ORT CPU is available, otherwise `bicubicCpu`

#### Scenario: probe never throws

- **GIVEN** every execution provider probes unavailable
- **WHEN** `probe()` resolves
- **THEN** `effective` is `bicubicCpu` and no exception is thrown

### Requirement: Experimental gating and model-state floor

The effective backend MUST be `bicubicCpu` whenever the experimental flag is disabled, or whenever the upscaling model is absent, regardless of platform. In each case the `reason` MUST explain why (experimental disabled, or model not downloaded).

#### Scenario: Experimental disabled forces the CPU floor

- **GIVEN** the experimental flag is disabled (the default)
- **WHEN** `probe()` resolves on any platform
- **THEN** `effective` is `bicubicCpu` and `reason` indicates the experimental feature is disabled

#### Scenario: Missing model forces the CPU floor

- **GIVEN** experimental is enabled but the model state is absent
- **WHEN** `probe()` resolves
- **THEN** `effective` is `bicubicCpu` and `reason` indicates the model is not downloaded

### Requirement: Default runtime resolves to the CPU floor

With no injected overrides, `MlRuntime` MUST default to experimental disabled, model absent, and no available execution providers, so `probe()` resolves to `effective == bicubicCpu`. This matches the only shipped upscaler (`CpuImageUpscaler`).

#### Scenario: Default probe yields bicubic CPU

- **GIVEN** a default `MlRuntime()` with no overrides
- **WHEN** `probe()` resolves
- **THEN** `effective` is `bicubicCpu`

### Requirement: Pure-Dart passthrough upscaler

The system SHALL provide a `PassthroughUpscaler` that implements `ImageUpscaler` using only pure-Dart code (no native plugins, no FFI), returning the input bytes with `outWidth = srcWidth * scaleFactor`, `outHeight = srcHeight * scaleFactor`, and `backend = bicubicCpu`.

#### Scenario: Passthrough scales dimensions and reports the CPU floor

- **GIVEN** an `UpscaleRequest` with `srcWidth=100`, `srcHeight=50`, `scaleFactor=2`
- **WHEN** `PassthroughUpscaler().upscale(request)` resolves
- **THEN** the result has `outWidth=200`, `outHeight=100`, and `backend == MlBackend.bicubicCpu`

### Requirement: Riverpod providers for the ML runtime

The system SHALL expose Riverpod providers `mlRuntimeProvider` and `imageUpscalerProvider`, both `keepAlive: true`, wired via `@Riverpod` codegen and overridable in tests. In production, `mlRuntimeProvider` SHALL construct its `MlRuntime` with the real injected resolvers rather than the floor defaults: the `ExperimentalFlagResolver` reads the AI-upscaling enable toggle, the `ModelStateResolver` reads the selected model's presence from the `ModelRepository`, and the `ExecutionProviderProbe` is the ONNX Runtime CPU probe (`ortCpuExecutionProviderProbe`). `imageUpscalerProvider` MUST remain overridable in tests; its concrete selection semantics (async resolution from `MlRuntime.probe()` and the model source) are owned by the `ai-image-upscaler` capability.

#### Scenario: imageUpscalerProvider is overridable

- **WHEN** a test overrides `imageUpscalerProvider` with a fake `ImageUpscaler`
- **THEN** a consumer reading the provider observes the fake instance

#### Scenario: Production mlRuntimeProvider injects real resolvers

- **WHEN** `mlRuntimeProvider` is read in production wiring (no overrides)
- **THEN** the constructed `MlRuntime` uses the experimental-flag, model-state, and ORT CPU probe resolvers — so `probe()` reflects the actual toggle and model presence rather than the always-floor defaults

### Requirement: No new native or ML dependencies

The `ml-runtime` capability MUST NOT introduce native-bridge dependencies; the runtime, value objects, and bicubic CPU floor MUST compile with the existing dependency set.

#### Scenario: pubspec has no native ML bridge for the runtime layer

- **WHEN** `app/pubspec.yaml` is inspected for the ml-runtime layer
- **THEN** no native ML bridge / FFI dependency is required by it

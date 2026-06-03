## 1. Backend & capabilities model

- [x] 1.1 Redefine `MlBackend` enum to `coremlEp`, `nnapiEp`, `directmlEp`, `ortCpu`, `bicubicCpu`
- [x] 1.2 Add `MlModelState { absent, present }`
- [x] 1.3 Expand `MlCapabilities` to `{ preferred, effective, modelState, experimentalEnabled, reason }` with `==`/`hashCode`/`toString`

## 2. MlRuntime probe + fallback

- [x] 2.1 Add injection typedefs (platform / EP probe / model state / experimental flag) with floor defaults
- [x] 2.2 Implement `preferredBackend()` (platform → preferred EP)
- [x] 2.3 Implement async `probe()` with experimental + model-state floors and the preferred → ortCpu → bicubicCpu fallback chain (never throws)

## 3. Upscalers & providers

- [x] 3.1 Update `CpuImageUpscaler` and `PassthroughUpscaler` to report `MlBackend.bicubicCpu`
- [x] 3.2 Keep `imageUpscalerProvider` returning `CpuImageUpscaler`; regenerate Riverpod code

## 4. Tests & verification

- [x] 4.1 Rewrite `ml_runtime_test.dart` for `preferredBackend()` + `probe()` (all platforms, experimental off, model absent, EP available, EP fallback)
- [x] 4.2 Update `cpu_image_upscaler_test.dart`, `passthrough_upscaler_test.dart`, `providers_test.dart` for `bicubicCpu` / `probe()`
- [x] 4.3 `dart run build_runner build` / `dart format` / `flutter analyze --fatal-infos` / `flutter test` all green
- [x] 4.4 `openspec validate refactor-ml-runtime-effective-backend --strict` passes

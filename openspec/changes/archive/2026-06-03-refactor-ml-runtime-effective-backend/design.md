## Context

Implements the foundation refactor from [ADR-0007](../../../docs/adr/0007-ai-upscaling-runtime-strategy.md) (step 1 of its Consequences sequence). No concrete ONNX/GPU backend or model repository exists yet, so the effective backend resolves to the `bicubicCpu` floor under defaults.

## Decisions

### MlBackend (EP-oriented)

```dart
enum MlBackend { coremlEp, nnapiEp, directmlEp, ortCpu, bicubicCpu }
```

`tensorRt` from the prior enum is dropped (ADR-0007 defers it); Windows preferred becomes `directmlEp`. `bicubicCpu` replaces `cpu` as the explicit universal floor.

### Injection surface (typedefs)

```dart
typedef TargetPlatformResolver = TargetPlatform Function();
typedef ExecutionProviderProbe = Future<bool> Function(MlBackend backend);
typedef ModelStateResolver = Future<MlModelState> Function();
typedef ExperimentalFlagResolver = Future<bool> Function();
```

Defaults: platform = `defaultTargetPlatform`; EP probe = always `false` (no EP implemented); model = `MlModelState.absent`; experimental = `false`. These defaults make `probe()` deterministically resolve to `bicubicCpu`, matching the only shipped upscaler.

### probe() algorithm

```
preferred = preferredBackend(platform)
experimental = await experimentalFlag()
model = await modelState()
if (!experimental)        -> effective bicubicCpu, reason "experimental feature disabled"
else if (model == absent) -> effective bicubicCpu, reason "model not downloaded"
else:
  if (preferred is a GPU EP && await epProbe(preferred)) -> effective preferred
  else if (await epProbe(ortCpu))                        -> effective ortCpu
  else                                                   -> effective bicubicCpu
```

`probe()` never throws — `bicubicCpu` is always reachable.

### MlCapabilities

Expanded to `{ preferred, effective, modelState, experimentalEnabled, reason }` with value equality. `describe()` (sync, platform-only) is removed in favour of `probe()`; a sync `preferredBackend()` is kept for callers that only need intent.

### Providers

`imageUpscalerProvider` continues to return `CpuImageUpscaler` (the `bicubicCpu` implementation) — the only upscaler that exists. Wiring the provider to switch implementations by effective backend is deferred to the change that introduces a second backend (`add-onnx-upscaler-runtime`).

## Risks / Trade-offs

- **[Trade-off] enum rename ripples into tests** → contained to `core/ml` + its 4 test files; no `lib` usage outside `core/ml`.
- **[Risk] probe() is async; callers must await** → only `core/ml` tests call it today; no UI consumes it yet.

## Migration

`CpuImageUpscaler` / `PassthroughUpscaler` switch `MlBackend.cpu` → `MlBackend.bicubicCpu`. Tests asserting `MlBackend.cpu` / `describe()` are rewritten for `bicubicCpu` / `probe()` / `preferredBackend()`.

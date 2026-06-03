# Tasks: add-ml-runtime-abstraction

## OpenSpec artifacts

- [x] Write `openspec/changes/add-ml-runtime-abstraction/specs/ml-runtime/spec.md` (delta spec)

## Source files

- [x] Create `app/lib/core/ml/ml_backend.dart`
- [x] Create `app/lib/core/ml/ml_capabilities.dart`
- [x] Create `app/lib/core/ml/upscale_request.dart`
- [x] Create `app/lib/core/ml/upscale_result.dart`
- [x] Create `app/lib/core/ml/image_upscaler.dart`
- [x] Create `app/lib/core/ml/ml_runtime.dart`
- [x] Create `app/lib/core/ml/passthrough_upscaler.dart`
- [x] Create `app/lib/core/ml/providers.dart`

## Code generation

- [x] Run `dart run build_runner build --delete-conflicting-outputs` (generates `providers.g.dart`)

## Tests

- [x] Create `app/test/core/ml/ml_runtime_test.dart`
- [x] Create `app/test/core/ml/passthrough_upscaler_test.dart`
- [x] Create `app/test/core/ml/providers_test.dart`

## Verification

- [x] `dart format --output=none --set-exit-if-changed .` (zero diff)
- [x] `flutter analyze --fatal-infos` (no issues)
- [x] `flutter test` (all tests pass — 507 total)

## Commit

- [ ] Commit all changes on `feature/add-ml-runtime-abstraction`

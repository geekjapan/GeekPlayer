import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/settings/presentation/app_settings_notifier.dart';
import 'cpu_image_upscaler.dart';
import 'image_upscaler.dart';
import 'ml_backend.dart';
import 'ml_model_state.dart';
import 'ml_runtime.dart';
import 'gpu_capability_probe.dart';
import 'model_repository.dart';
import 'onnx_model_source.dart';
import 'upscale_model_catalog.dart';
import 'upscaler_selection.dart';

part 'providers.g.dart';

/// The on-device upscale-model repository (download / SHA-256 verify / cache).
///
/// Downloads over HTTPS via `dio` and caches under the app-support directory.
/// Tests override this with a fake-downloader repository to stay offline.
@Riverpod(keepAlive: true)
ModelRepository modelRepository(Ref ref) {
  return ModelRepository(
    downloader: DioModelDownloader(Dio()),
    cacheDirProvider: getApplicationSupportDirectory,
  );
}

/// Provides the [MlRuntime] singleton wired with the production resolvers
/// (ADR-0007 step 3): the experimental flag reads the AI-upscaling toggle, the
/// model-state reads the selected model's presence from [ModelRepository], and
/// the execution-provider probe is the ONNX Runtime CPU probe. While the toggle
/// is OFF or the model is absent, `probe()` floors to bicubic CPU.
///
/// Tests can override this with a custom [MlRuntime] (floor defaults touch no
/// settings/DB) to exercise any branch without infrastructure.
@Riverpod(keepAlive: true)
MlRuntime mlRuntime(Ref ref) {
  return MlRuntime(
    executionProviderProbe: combinedExecutionProviderProbe,
    experimentalFlag: () async {
      final settings = await ref.read(appSettingsProvider.future);
      return settings.aiUpscaleEnabled;
    },
    preferredOverride: () async {
      final settings = await ref.read(appSettingsProvider.future);
      return resolvePreferredOverride(
        settings.aiUpscaleBackendOverride,
        defaultTargetPlatform,
      );
    },
    modelState: () async {
      final settings = await ref.read(appSettingsProvider.future);
      final UpscaleModelEntry? entry = UpscaleModelCatalog.forScale(
        settings.aiUpscaleScale,
      );
      if (entry == null) return MlModelState.absent;
      return ref.read(modelRepositoryProvider).stateOf(entry);
    },
  );
}

/// Resolves the active [ImageUpscaler] asynchronously from the effective
/// backend and the selected model (ADR-0007 step 3).
///
/// The floor branch (experimental OFF / model absent / ORT unavailable →
/// effective `bicubicCpu`) returns [CpuImageUpscaler] without reading settings,
/// so it stays cheap and infrastructure-free. Only when the effective backend
/// is `ortCpu` does it read the configured scale and fetch the model source,
/// delegating the final choice to the pure [resolveImageUpscaler] seam.
@Riverpod(keepAlive: true)
Future<ImageUpscaler> imageUpscaler(Ref ref) async {
  final MlRuntime runtime = ref.watch(mlRuntimeProvider);
  final caps = await runtime.probe();
  // Floor branch (bicubic) stays settings/DB-free. ONNX Runtime EPs (CPU or
  // GPU) go through the model-backed selection seam.
  const Set<MlBackend> onnxBackends = <MlBackend>{
    MlBackend.ortCpu,
    MlBackend.coremlEp,
    MlBackend.nnapiEp,
  };
  if (!onnxBackends.contains(caps.effective)) {
    return const CpuImageUpscaler();
  }
  final settings = await ref.watch(appSettingsProvider.future);
  final UpscaleModelEntry? entry = UpscaleModelCatalog.forScale(
    settings.aiUpscaleScale,
  );
  final OnnxModelSource? model = entry == null
      ? null
      : await ref.read(modelRepositoryProvider).sourceOf(entry);
  return resolveImageUpscaler(effective: caps.effective, model: model);
}

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/cpu_image_upscaler.dart';
import 'package:geekplayer/core/ml/ml_backend.dart';
import 'package:geekplayer/core/ml/onnx_image_upscaler.dart';
import 'package:geekplayer/core/ml/onnx_model_source.dart';
import 'package:geekplayer/core/ml/upscaler_selection.dart';
import 'package:geekplayer/features/settings/domain/ai_upscale_backend_override.dart';

void main() {
  final model = OnnxModelSource.bytes(Uint8List.fromList([0, 1, 2, 3]));

  group('resolveImageUpscaler', () {
    test('bicubic backend → CpuImageUpscaler floor', () {
      expect(
        resolveImageUpscaler(effective: MlBackend.bicubicCpu, model: model),
        isA<CpuImageUpscaler>(),
      );
    });

    test('ortCpu + model → OnnxImageUpscaler', () {
      expect(
        resolveImageUpscaler(effective: MlBackend.ortCpu, model: model),
        isA<OnnxImageUpscaler>(),
      );
    });

    test('ortCpu without model → floor', () {
      expect(
        resolveImageUpscaler(effective: MlBackend.ortCpu),
        isA<CpuImageUpscaler>(),
      );
    });

    test('coremlEp + model → OnnxImageUpscaler targeting CoreML', () {
      final upscaler = resolveImageUpscaler(
        effective: MlBackend.coremlEp,
        model: model,
      );
      expect(upscaler, isA<OnnxImageUpscaler>());
      expect((upscaler as OnnxImageUpscaler).targetBackend, MlBackend.coremlEp);
    });

    test('nnapiEp + model → OnnxImageUpscaler targeting NNAPI', () {
      final upscaler = resolveImageUpscaler(
        effective: MlBackend.nnapiEp,
        model: model,
      );
      expect(upscaler, isA<OnnxImageUpscaler>());
      expect((upscaler as OnnxImageUpscaler).targetBackend, MlBackend.nnapiEp);
    });

    test('GPU EP without model → floor', () {
      expect(
        resolveImageUpscaler(effective: MlBackend.coremlEp),
        isA<CpuImageUpscaler>(),
      );
    });

    test('directmlEp + model → floor (not an ORT-package EP)', () {
      expect(
        resolveImageUpscaler(effective: MlBackend.directmlEp, model: model),
        isA<CpuImageUpscaler>(),
      );
    });
  });

  group('resolvePreferredOverride', () {
    test('auto → null on every platform', () {
      for (final p in TargetPlatform.values) {
        expect(
          resolvePreferredOverride(AiUpscaleBackendOverride.auto, p),
          isNull,
        );
      }
    });

    test('forceCpu → ortCpu on every platform', () {
      for (final p in TargetPlatform.values) {
        expect(
          resolvePreferredOverride(AiUpscaleBackendOverride.forceCpu, p),
          MlBackend.ortCpu,
        );
      }
    });

    test('forceGpu maps to the platform GPU EP', () {
      expect(
        resolvePreferredOverride(
          AiUpscaleBackendOverride.forceGpu,
          TargetPlatform.iOS,
        ),
        MlBackend.coremlEp,
      );
      expect(
        resolvePreferredOverride(
          AiUpscaleBackendOverride.forceGpu,
          TargetPlatform.macOS,
        ),
        MlBackend.coremlEp,
      );
      expect(
        resolvePreferredOverride(
          AiUpscaleBackendOverride.forceGpu,
          TargetPlatform.android,
        ),
        MlBackend.nnapiEp,
      );
      expect(
        resolvePreferredOverride(
          AiUpscaleBackendOverride.forceGpu,
          TargetPlatform.windows,
        ),
        MlBackend.directmlEp,
      );
    });

    test('forceGpu → null on platforms with no GPU EP', () {
      expect(
        resolvePreferredOverride(
          AiUpscaleBackendOverride.forceGpu,
          TargetPlatform.linux,
        ),
        isNull,
      );
      expect(
        resolvePreferredOverride(
          AiUpscaleBackendOverride.forceGpu,
          TargetPlatform.fuchsia,
        ),
        isNull,
      );
    });
  });
}

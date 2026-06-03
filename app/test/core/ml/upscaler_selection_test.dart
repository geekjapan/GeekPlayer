import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/cpu_image_upscaler.dart';
import 'package:geekplayer/core/ml/ml_backend.dart';
import 'package:geekplayer/core/ml/onnx_image_upscaler.dart';
import 'package:geekplayer/core/ml/onnx_model_source.dart';
import 'package:geekplayer/core/ml/upscaler_selection.dart';

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

    test('GPU EP backend → floor in this step (no model selected)', () {
      // CoreML/NNAPI/DirectML EPs are not yet wired to the ORT upscaler here.
      expect(
        resolveImageUpscaler(effective: MlBackend.coremlEp, model: model),
        isA<CpuImageUpscaler>(),
      );
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/image_upscaler.dart';
import 'package:geekplayer/core/ml/ml_backend.dart';
import 'package:geekplayer/core/ml/ml_runtime.dart';
import 'package:geekplayer/core/ml/providers.dart';
import 'package:geekplayer/core/ml/upscale_request.dart';
import 'package:geekplayer/core/ml/upscale_result.dart';

/// Fake upscaler used for provider override tests.
class _FakeUpscaler implements ImageUpscaler {
  @override
  Future<UpscaleResult> upscale(UpscaleRequest request) async {
    return UpscaleResult(
      bytes: request.bytes,
      outWidth: 999,
      outHeight: 999,
      backend: MlBackend.coreml,
    );
  }
}

void main() {
  group('mlRuntimeProvider', () {
    test('default provider returns MlRuntime', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final runtime = container.read(mlRuntimeProvider);
      expect(runtime, isA<MlRuntime>());
    });

    test('overrideWithValue substitutes a custom MlRuntime', () {
      final fakeRuntime = MlRuntime(resolver: () => TargetPlatform.iOS);
      final container = ProviderContainer(
        overrides: [mlRuntimeProvider.overrideWithValue(fakeRuntime)],
      );
      addTearDown(container.dispose);

      final runtime = container.read(mlRuntimeProvider);
      expect(runtime.describe().backend, MlBackend.coreml);
    });
  });

  group('imageUpscalerProvider', () {
    test('default provider returns an ImageUpscaler', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final upscaler = container.read(imageUpscalerProvider);
      expect(upscaler, isA<ImageUpscaler>());
    });

    test('overrideWithValue substitutes a fake upscaler', () async {
      final fake = _FakeUpscaler();
      final container = ProviderContainer(
        overrides: [imageUpscalerProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final upscaler = container.read(imageUpscalerProvider);
      final result = await upscaler.upscale(
        UpscaleRequest(
          bytes: Uint8List.fromList([0]),
          srcWidth: 10,
          srcHeight: 10,
          scaleFactor: 2,
        ),
      );
      expect(result.outWidth, 999);
      expect(result.backend, MlBackend.coreml);
    });
  });
}

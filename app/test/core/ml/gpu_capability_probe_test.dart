import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/gpu_capability_probe.dart';
import 'package:geekplayer/core/ml/ml_backend.dart';

import 'ort_test_support.dart';

void main() async {
  final bool ortReady = await ensureOrtLoadable();

  group('gpuExecutionProviderProbe', () {
    test('returns a bool and never throws for CoreML / NNAPI', () async {
      // Availability depends on the host build; the only invariant we assert
      // here is that the probe resolves to a bool without throwing.
      expect(await gpuExecutionProviderProbe(MlBackend.coremlEp), isA<bool>());
      expect(await gpuExecutionProviderProbe(MlBackend.nnapiEp), isA<bool>());
    });

    test('reports directmlEp as always unavailable', () async {
      expect(await gpuExecutionProviderProbe(MlBackend.directmlEp), isFalse);
    });

    test('reports non-EP backends as unavailable', () async {
      expect(await gpuExecutionProviderProbe(MlBackend.ortCpu), isFalse);
      expect(await gpuExecutionProviderProbe(MlBackend.bicubicCpu), isFalse);
    });
  });

  group('combinedExecutionProviderProbe', () {
    test(
      'ortCpu reflects ORT initialization',
      () async {
        final bool result = await combinedExecutionProviderProbe(
          MlBackend.ortCpu,
        );
        expect(result, isA<bool>());
      },
      skip: ortReady ? false : 'ONNX Runtime native lib not loadable on host',
    );

    test(
      'reports ortCpu available when ORT loads',
      () async {
        expect(await combinedExecutionProviderProbe(MlBackend.ortCpu), isTrue);
      },
      skip: ortReady ? false : 'ONNX Runtime native lib not loadable on host',
    );

    test('delegates GPU EPs and never throws', () async {
      expect(
        await combinedExecutionProviderProbe(MlBackend.coremlEp),
        isA<bool>(),
      );
      expect(
        await combinedExecutionProviderProbe(MlBackend.nnapiEp),
        isA<bool>(),
      );
    });

    test('directmlEp is always false', () async {
      expect(
        await combinedExecutionProviderProbe(MlBackend.directmlEp),
        isFalse,
      );
    });
  });
}

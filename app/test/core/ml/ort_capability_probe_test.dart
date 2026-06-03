import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/ml_backend.dart';
import 'package:geekplayer/core/ml/ort_capability_probe.dart';

import 'ort_test_support.dart';

void main() async {
  final bool ortReady = await ensureOrtLoadable();

  group('ortCpuExecutionProviderProbe', () {
    test('reports ortCpu available when ORT loads', () async {
      expect(await ortCpuExecutionProviderProbe(MlBackend.ortCpu), isTrue);
      // GPU EPs stay unavailable until step 4.
      expect(await ortCpuExecutionProviderProbe(MlBackend.coremlEp), isFalse);
      expect(await ortCpuExecutionProviderProbe(MlBackend.nnapiEp), isFalse);
    }, skip: ortReady ? false : 'ONNX Runtime native lib not loadable on test host');

    test('never throws and always returns a bool', () async {
      // Whether or not ORT is loadable, the probe must resolve, not throw.
      final result = await ortCpuExecutionProviderProbe(MlBackend.ortCpu);
      expect(result, isA<bool>());
      final gpu = await ortCpuExecutionProviderProbe(MlBackend.directmlEp);
      expect(gpu, isFalse);
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/ml_backend.dart';
import 'package:geekplayer/core/ml/ml_runtime.dart';

void main() {
  MlRuntime runtimeFor(TargetPlatform platform) =>
      MlRuntime(resolver: () => platform);

  group('MlRuntime.describe()', () {
    test('iOS → coreml', () {
      expect(
        runtimeFor(TargetPlatform.iOS).describe().backend,
        MlBackend.coreml,
      );
    });

    test('macOS → coreml', () {
      expect(
        runtimeFor(TargetPlatform.macOS).describe().backend,
        MlBackend.coreml,
      );
    });

    test('android → nnapi', () {
      expect(
        runtimeFor(TargetPlatform.android).describe().backend,
        MlBackend.nnapi,
      );
    });

    test('windows → tensorRt', () {
      expect(
        runtimeFor(TargetPlatform.windows).describe().backend,
        MlBackend.tensorRt,
      );
    });

    test('linux → onnxRuntime', () {
      expect(
        runtimeFor(TargetPlatform.linux).describe().backend,
        MlBackend.onnxRuntime,
      );
    });

    test('fuchsia → cpu (fallback)', () {
      expect(
        runtimeFor(TargetPlatform.fuchsia).describe().backend,
        MlBackend.cpu,
      );
    });
  });
}

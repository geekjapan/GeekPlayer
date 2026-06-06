import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/ml_backend.dart';
import 'package:geekplayer/core/ml/ml_model_state.dart';
import 'package:geekplayer/core/ml/ml_runtime.dart';

void main() {
  group('MlRuntime.preferredBackend()', () {
    MlBackend preferredFor(TargetPlatform platform) =>
        MlRuntime(platform: () => platform).preferredBackend();

    test('iOS / macOS → coremlEp', () {
      expect(preferredFor(TargetPlatform.iOS), MlBackend.coremlEp);
      expect(preferredFor(TargetPlatform.macOS), MlBackend.coremlEp);
    });

    test('android → nnapiEp', () {
      expect(preferredFor(TargetPlatform.android), MlBackend.nnapiEp);
    });

    test('windows → directmlEp', () {
      expect(preferredFor(TargetPlatform.windows), MlBackend.directmlEp);
    });

    test('linux → ortCpu', () {
      expect(preferredFor(TargetPlatform.linux), MlBackend.ortCpu);
    });

    test('fuchsia → bicubicCpu (floor)', () {
      expect(preferredFor(TargetPlatform.fuchsia), MlBackend.bicubicCpu);
    });
  });

  group('MlRuntime.probe()', () {
    test('default runtime resolves to bicubicCpu floor', () async {
      final caps = await const MlRuntime().probe();
      expect(caps.effective, MlBackend.bicubicCpu);
      expect(caps.experimentalEnabled, isFalse);
    });

    test('experimental disabled forces the floor with reason', () async {
      final caps = await MlRuntime(
        platform: () => TargetPlatform.iOS,
        experimentalFlag: () async => false,
        modelState: () async => MlModelState.present,
        executionProviderProbe: (_) async => true,
      ).probe();
      expect(caps.preferred, MlBackend.coremlEp);
      expect(caps.effective, MlBackend.bicubicCpu);
      expect(caps.reason, contains('disabled'));
    });

    test('missing model forces the floor with reason', () async {
      final caps = await MlRuntime(
        platform: () => TargetPlatform.iOS,
        experimentalFlag: () async => true,
        modelState: () async => MlModelState.absent,
        executionProviderProbe: (_) async => true,
      ).probe();
      expect(caps.effective, MlBackend.bicubicCpu);
      expect(caps.reason, contains('model'));
    });

    test(
      'preferred EP used when enabled, model present, and available',
      () async {
        final caps = await MlRuntime(
          platform: () => TargetPlatform.android,
          experimentalFlag: () async => true,
          modelState: () async => MlModelState.present,
          executionProviderProbe: (b) async => b == MlBackend.nnapiEp,
        ).probe();
        expect(caps.preferred, MlBackend.nnapiEp);
        expect(caps.effective, MlBackend.nnapiEp);
      },
    );

    test('falls back to ortCpu when preferred EP unavailable', () async {
      final caps = await MlRuntime(
        platform: () => TargetPlatform.android,
        experimentalFlag: () async => true,
        modelState: () async => MlModelState.present,
        executionProviderProbe: (b) async => b == MlBackend.ortCpu,
      ).probe();
      expect(caps.effective, MlBackend.ortCpu);
    });

    test('falls back to bicubicCpu when nothing is available', () async {
      final caps = await MlRuntime(
        platform: () => TargetPlatform.android,
        experimentalFlag: () async => true,
        modelState: () async => MlModelState.present,
        executionProviderProbe: (_) async => false,
      ).probe();
      expect(caps.effective, MlBackend.bicubicCpu);
    });

    test('linux prefers ortCpu and uses it when available', () async {
      final caps = await MlRuntime(
        platform: () => TargetPlatform.linux,
        experimentalFlag: () async => true,
        modelState: () async => MlModelState.present,
        executionProviderProbe: (b) async => b == MlBackend.ortCpu,
      ).probe();
      expect(caps.preferred, MlBackend.ortCpu);
      expect(caps.effective, MlBackend.ortCpu);
    });
  });

  group('MlRuntime.probe() preferred override (ADR-0007 step 4)', () {
    test(
      'override forceCpu pins preferred to ortCpu even on a GPU platform',
      () async {
        final caps = await MlRuntime(
          platform: () => TargetPlatform.iOS,
          experimentalFlag: () async => true,
          modelState: () async => MlModelState.present,
          // Both CoreML and CPU are "available"; the override must win.
          executionProviderProbe: (_) async => true,
          preferredOverride: () async => MlBackend.ortCpu,
        ).probe();
        expect(caps.preferred, MlBackend.ortCpu);
        expect(caps.effective, MlBackend.ortCpu);
      },
    );

    test(
      'override forceGpu with the GPU EP unavailable degrades to the floor',
      () async {
        final caps = await MlRuntime(
          platform: () => TargetPlatform.android,
          experimentalFlag: () async => true,
          modelState: () async => MlModelState.present,
          // Neither the forced GPU EP nor ORT CPU is available → floor.
          executionProviderProbe: (_) async => false,
          preferredOverride: () async => MlBackend.coremlEp,
        ).probe();
        expect(caps.preferred, MlBackend.coremlEp);
        expect(caps.effective, MlBackend.bicubicCpu);
      },
    );

    test('null override uses the platform default', () async {
      final caps = await MlRuntime(
        platform: () => TargetPlatform.android,
        experimentalFlag: () async => true,
        modelState: () async => MlModelState.present,
        executionProviderProbe: (b) async => b == MlBackend.nnapiEp,
        preferredOverride: () async => null,
      ).probe();
      expect(caps.preferred, MlBackend.nnapiEp);
      expect(caps.effective, MlBackend.nnapiEp);
    });
  });
}

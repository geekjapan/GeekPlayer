import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/cpu_image_upscaler.dart';
import 'package:geekplayer/core/ml/image_upscaler.dart';
import 'package:geekplayer/core/ml/ml_backend.dart';
import 'package:geekplayer/core/ml/ml_model_state.dart';
import 'package:geekplayer/core/ml/ml_runtime.dart';
import 'package:geekplayer/core/ml/model_repository.dart';
import 'package:geekplayer/core/ml/onnx_image_upscaler.dart';
import 'package:geekplayer/core/ml/providers.dart';
import 'package:geekplayer/core/ml/upscale_model_catalog.dart';
import 'package:geekplayer/core/ml/upscale_request.dart';
import 'package:geekplayer/core/ml/upscale_result.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/settings/domain/app_settings.dart';
import 'package:geekplayer/features/settings/domain/setting_keys.dart';
import 'package:geekplayer/features/settings/presentation/app_settings_notifier.dart';

/// Fake upscaler used for provider override tests.
class _FakeUpscaler implements ImageUpscaler {
  @override
  Future<UpscaleResult> upscale(UpscaleRequest request) async {
    return UpscaleResult(
      bytes: request.bytes,
      outWidth: 999,
      outHeight: 999,
      backend: MlBackend.coremlEp,
    );
  }
}

/// A [ModelDownloader] returning fixed bytes.
class _Downloader implements ModelDownloader {
  _Downloader(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List> download(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async => bytes;
}

AppDatabase _freshDb() =>
    AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));

/// A real [ModelRepository] over a temp dir, with [entry] pre-fetched present.
Future<ModelRepository> _repoWithPresent(
  UpscaleModelEntry entry,
  Uint8List bytes,
  Directory dir,
) async {
  final repo = ModelRepository(
    downloader: _Downloader(bytes),
    cacheDirProvider: () async => dir,
  );
  await repo.ensureModel(entry);
  return repo;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mlRuntimeProvider', () {
    test('default provider returns MlRuntime', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(mlRuntimeProvider), isA<MlRuntime>());
    });

    test('overrideWithValue substitutes a custom MlRuntime', () {
      final fakeRuntime = MlRuntime(platform: () => TargetPlatform.iOS);
      final container = ProviderContainer(
        overrides: [mlRuntimeProvider.overrideWithValue(fakeRuntime)],
      );
      addTearDown(container.dispose);
      expect(
        container.read(mlRuntimeProvider).preferredBackend(),
        MlBackend.coremlEp,
      );
    });

    test(
      'production provider injects real resolvers (toggle + model state)',
      () async {
        final db = _freshDb();
        addTearDown(db.close);
        // Seed experimental ON, scale 2.
        await db.appSettingsDao.upsert(SettingKeys.aiUpscaleEnabled, 'true');
        await db.appSettingsDao.upsert(SettingKeys.aiUpscaleScale, '2');

        final dir = await Directory.systemTemp.createTemp('gp_prov_');
        addTearDown(() => dir.delete(recursive: true));
        final x2Bytes = await File(
          'test/fixtures/ml/upscale_x2_nearest.onnx',
        ).readAsBytes();
        final repo = await _repoWithPresent(
          UpscaleModelCatalog.x2,
          x2Bytes,
          dir,
        );

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            modelRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final caps = await container.read(mlRuntimeProvider).probe();
        // Resolvers are wired (not the always-floor defaults): the toggle and
        // model presence are reflected rather than forced off/absent.
        expect(caps.experimentalEnabled, isTrue);
        expect(caps.modelState, MlModelState.present);
      },
    );
  });

  group('imageUpscalerProvider (async)', () {
    test('floors to CpuImageUpscaler when effective is not ortCpu', () async {
      // Default MlRuntime() floors to bicubic (experimental off) with no DB.
      final container = ProviderContainer(
        overrides: [mlRuntimeProvider.overrideWithValue(const MlRuntime())],
      );
      addTearDown(container.dispose);

      final upscaler = await container.read(imageUpscalerProvider.future);
      expect(upscaler, isA<CpuImageUpscaler>());
    });

    test('experimental ON but model absent → CpuImageUpscaler floor', () async {
      final runtime = MlRuntime(
        experimentalFlag: () async => true,
        executionProviderProbe: (b) async => b == MlBackend.ortCpu,
        modelState: () async => MlModelState.absent,
      );
      final container = ProviderContainer(
        overrides: [mlRuntimeProvider.overrideWithValue(runtime)],
      );
      addTearDown(container.dispose);

      final upscaler = await container.read(imageUpscalerProvider.future);
      expect(upscaler, isA<CpuImageUpscaler>());
    });

    test('ortCpu + model present → OnnxImageUpscaler', () async {
      final runtime = MlRuntime(
        experimentalFlag: () async => true,
        executionProviderProbe: (b) async => b == MlBackend.ortCpu,
        modelState: () async => MlModelState.present,
      );
      final db = _freshDb();
      addTearDown(db.close);
      // Default scale is 2 → selects the x2 entry.
      final dir = await Directory.systemTemp.createTemp('gp_prov_onnx_');
      addTearDown(() => dir.delete(recursive: true));
      final x2Bytes = await File(
        'test/fixtures/ml/upscale_x2_nearest.onnx',
      ).readAsBytes();
      final repo = await _repoWithPresent(UpscaleModelCatalog.x2, x2Bytes, dir);

      final container = ProviderContainer(
        overrides: [
          mlRuntimeProvider.overrideWithValue(runtime),
          appDatabaseProvider.overrideWithValue(db),
          modelRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final upscaler = await container.read(imageUpscalerProvider.future);
      expect(upscaler, isA<OnnxImageUpscaler>());
    });

    test(
      'invalidate re-resolves after model state changes (download)',
      () async {
        // Mutable model state: starts absent (floor), flips to present after a
        // simulated download. The keepAlive provider must re-resolve only when
        // invalidated — this is the contract ExperimentalSection relies on.
        MlModelState state = MlModelState.absent;
        final runtime = MlRuntime(
          experimentalFlag: () async => true,
          executionProviderProbe: (b) async => b == MlBackend.ortCpu,
          modelState: () async => state,
        );
        final db = _freshDb();
        addTearDown(db.close);
        final dir = await Directory.systemTemp.createTemp('gp_prov_inval_');
        addTearDown(() => dir.delete(recursive: true));
        final x2Bytes = await File(
          'test/fixtures/ml/upscale_x2_nearest.onnx',
        ).readAsBytes();
        final repo = await _repoWithPresent(
          UpscaleModelCatalog.x2,
          x2Bytes,
          dir,
        );

        final container = ProviderContainer(
          overrides: [
            mlRuntimeProvider.overrideWithValue(runtime),
            appDatabaseProvider.overrideWithValue(db),
            modelRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        // Absent → floor, and the result is cached.
        expect(
          await container.read(imageUpscalerProvider.future),
          isA<CpuImageUpscaler>(),
        );
        // Simulate a completed download; without invalidation the cache stands.
        state = MlModelState.present;
        expect(
          await container.read(imageUpscalerProvider.future),
          isA<CpuImageUpscaler>(),
          reason: 'keepAlive cache holds until invalidated',
        );
        // After invalidation the upscaler re-resolves to the ONNX path.
        container.invalidate(imageUpscalerProvider);
        expect(
          await container.read(imageUpscalerProvider.future),
          isA<OnnxImageUpscaler>(),
        );
      },
    );

    test('overrideWith substitutes a fake upscaler', () async {
      final fake = _FakeUpscaler();
      final container = ProviderContainer(
        overrides: [imageUpscalerProvider.overrideWith((ref) async => fake)],
      );
      addTearDown(container.dispose);

      final upscaler = await container.read(imageUpscalerProvider.future);
      final result = await upscaler.upscale(
        UpscaleRequest(
          bytes: Uint8List.fromList([0]),
          srcWidth: 10,
          srcHeight: 10,
          scaleFactor: 2,
        ),
      );
      expect(result.outWidth, 999);
      expect(result.backend, MlBackend.coremlEp);
    });
  });

  // Silence unused import lint for AppSettings/notifier in some build configs.
  test('settings types are importable', () {
    expect(AppSettings.defaults().aiUpscaleScale, 2);
    expect(kAppSettingsWriteDebounce, isA<Duration>());
  });
}

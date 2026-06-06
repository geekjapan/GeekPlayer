import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/ml_model_state.dart';
import 'package:geekplayer/core/ml/model_repository.dart';
import 'package:geekplayer/core/ml/onnx_model_source.dart';
import 'package:geekplayer/core/ml/upscale_model_catalog.dart';

/// A [ModelDownloader] fake: returns canned bytes (or throws) and counts calls.
class _FakeDownloader implements ModelDownloader {
  _FakeDownloader({this.bytes, this.error});

  final Uint8List? bytes;
  final Object? error;
  int calls = 0;
  final List<String> requestedUrls = <String>[];

  @override
  Future<Uint8List> download(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    calls++;
    requestedUrls.add(url);
    if (error != null) throw error!;
    onProgress?.call(bytes!.length, bytes!.length);
    return bytes!;
  }
}

void main() {
  late Directory cacheDir;
  late Uint8List x2Bytes;

  setUp(() async {
    cacheDir = await Directory.systemTemp.createTemp('gp_models_test_');
    x2Bytes = await File(
      'test/fixtures/ml/upscale_x2_nearest.onnx',
    ).readAsBytes();
  });

  tearDown(() async {
    if (cacheDir.existsSync()) await cacheDir.delete(recursive: true);
  });

  ModelRepository repoWith(_FakeDownloader downloader) => ModelRepository(
    downloader: downloader,
    cacheDirProvider: () async => cacheDir,
  );

  group('ModelRepository.ensureModel', () {
    test('hash match → confirms to versioned path and returns it', () async {
      final downloader = _FakeDownloader(bytes: x2Bytes);
      final repo = repoWith(downloader);

      final String path = await repo.ensureModel(UpscaleModelCatalog.x2);

      expect(File(path).existsSync(), isTrue);
      expect(path, contains('ml_models'));
      expect(path, contains('fixture-nearest'));
      expect(path, contains('x2-2026.06'));
      expect(await File(path).readAsBytes(), x2Bytes);
      expect(await repo.stateOf(UpscaleModelCatalog.x2), MlModelState.present);
    });

    test(
      'hash mismatch → discards part file and throws, stays absent',
      () async {
        // x4 entry's expected sha will not match x2 bytes.
        final downloader = _FakeDownloader(bytes: x2Bytes);
        final repo = repoWith(downloader);

        await expectLater(
          repo.ensureModel(UpscaleModelCatalog.x4),
          throwsA(isA<ModelVerificationException>()),
        );
        expect(await repo.stateOf(UpscaleModelCatalog.x4), MlModelState.absent);
        expect(await repo.sizeOf(UpscaleModelCatalog.x4), 0);
        // No leftover .part anywhere under the cache dir.
        final leftovers = cacheDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.part'));
        expect(leftovers, isEmpty);
      },
    );

    test(
      'network failure → throws ModelDownloadException, stays absent',
      () async {
        final downloader = _FakeDownloader(
          error: const SocketException('down'),
        );
        final repo = repoWith(downloader);

        await expectLater(
          repo.ensureModel(UpscaleModelCatalog.x2),
          throwsA(isA<ModelDownloadException>()),
        );
        expect(await repo.stateOf(UpscaleModelCatalog.x2), MlModelState.absent);
      },
    );

    test('cached model is not re-downloaded', () async {
      final downloader = _FakeDownloader(bytes: x2Bytes);
      final repo = repoWith(downloader);

      final String first = await repo.ensureModel(UpscaleModelCatalog.x2);
      final String second = await repo.ensureModel(UpscaleModelCatalog.x2);

      expect(second, first);
      expect(downloader.calls, 1);
    });

    test('different versions cache to separate paths', () async {
      final repo2 = repoWith(_FakeDownloader(bytes: x2Bytes));
      final String p2 = await repo2.ensureModel(UpscaleModelCatalog.x2);

      final x4Bytes = await File(
        'test/fixtures/ml/upscale_x4_nearest.onnx',
      ).readAsBytes();
      final repo4 = repoWith(_FakeDownloader(bytes: x4Bytes));
      final String p4 = await repo4.ensureModel(UpscaleModelCatalog.x4);

      expect(p2, isNot(p4));
      // Deleting x4 leaves x2 intact.
      await repo4.delete(UpscaleModelCatalog.x4);
      expect(File(p2).existsSync(), isTrue);
      expect(File(p4).existsSync(), isFalse);
    });
  });

  group('ModelRepository state / size / delete / source', () {
    test('absent model reports absent and zero size', () async {
      final repo = repoWith(_FakeDownloader(bytes: x2Bytes));
      expect(await repo.stateOf(UpscaleModelCatalog.x2), MlModelState.absent);
      expect(await repo.sizeOf(UpscaleModelCatalog.x2), 0);
      expect(await repo.sourceOf(UpscaleModelCatalog.x2), isNull);
    });

    test('present model reports size and a file source', () async {
      final repo = repoWith(_FakeDownloader(bytes: x2Bytes));
      await repo.ensureModel(UpscaleModelCatalog.x2);

      expect(await repo.sizeOf(UpscaleModelCatalog.x2), x2Bytes.length);
      final source = await repo.sourceOf(UpscaleModelCatalog.x2);
      expect(source, isA<OnnxModelFileSource>());
    });

    test('delete returns to absent; second delete is a safe no-op', () async {
      final repo = repoWith(_FakeDownloader(bytes: x2Bytes));
      await repo.ensureModel(UpscaleModelCatalog.x2);

      await repo.delete(UpscaleModelCatalog.x2);
      expect(await repo.stateOf(UpscaleModelCatalog.x2), MlModelState.absent);
      expect(await repo.sizeOf(UpscaleModelCatalog.x2), 0);
      await expectLater(repo.delete(UpscaleModelCatalog.x2), completes);
    });
  });
}

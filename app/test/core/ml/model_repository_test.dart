import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/ml_model_state.dart';
import 'package:geekplayer/core/ml/model_repository.dart';
import 'package:geekplayer/core/ml/onnx_model_source.dart';
import 'package:geekplayer/core/ml/upscale_model_catalog.dart';

// Test-local entries pointing at the small nearest-neighbour fixtures (with
// their real digests), so repository tests don't depend on the production
// catalog's real-model URL/digest.
const UpscaleModelEntry _fx2 = UpscaleModelEntry(
  modelId: 'fixture-nearest',
  version: 'x2-test',
  url: 'https://example.invalid/upscale_x2_nearest.onnx',
  sha256: '68eddb443e4a48ed80566a4968bccc3ba47b4241bfeddad959a230ee70946927',
  scale: 2,
  license: 'Apache-2.0',
);
const UpscaleModelEntry _fx4 = UpscaleModelEntry(
  modelId: 'fixture-nearest',
  version: 'x4-test',
  url: 'https://example.invalid/upscale_x4_nearest.onnx',
  sha256: 'f5ea497c286ec2df5e787f9c41030f8a7f2ad819fc250895da9d61af2b20d60e',
  scale: 4,
  license: 'Apache-2.0',
);

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

/// A [ModelDownloader] that blocks on [gate] before returning, so a test can
/// hold multiple calls in-flight simultaneously.
class _GatedDownloader implements ModelDownloader {
  _GatedDownloader({required this.bytes, required this.gate});

  final Uint8List bytes;
  final Future<void> gate;
  int calls = 0;

  @override
  Future<Uint8List> download(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    calls++;
    await gate;
    return bytes;
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

  ModelRepository repoWith(ModelDownloader downloader) => ModelRepository(
    downloader: downloader,
    cacheDirProvider: () async => cacheDir,
  );

  group('ModelRepository.ensureModel', () {
    test('hash match → conforms to versioned path and returns it', () async {
      final downloader = _FakeDownloader(bytes: x2Bytes);
      final repo = repoWith(downloader);

      final String path = await repo.ensureModel(_fx2);

      expect(File(path).existsSync(), isTrue);
      expect(path, contains('ml_models'));
      expect(path, contains('fixture-nearest'));
      expect(path, contains('x2-test'));
      expect(await File(path).readAsBytes(), x2Bytes);
      expect(await repo.stateOf(_fx2), MlModelState.present);
    });

    test(
      'concurrent ensureModel for the same entry shares one download',
      () async {
        // A downloader gated on a Completer so both calls are in-flight before
        // either resolves; asserts the second call dedups onto the first.
        final gate = Completer<void>();
        final downloader = _GatedDownloader(bytes: x2Bytes, gate: gate.future);
        final repo = repoWith(downloader);

        final Future<String> a = repo.ensureModel(_fx2);
        final Future<String> b = repo.ensureModel(_fx2);
        // Let both calls reach the in-flight check before releasing the gate.
        await Future<void>.delayed(Duration.zero);
        gate.complete();

        final List<String> paths = await Future.wait(<Future<String>>[a, b]);
        expect(paths[0], paths[1]);
        expect(downloader.calls, 1, reason: 'second call must dedup');
        expect(await repo.stateOf(_fx2), MlModelState.present);
      },
    );

    test(
      'hash mismatch → discards part file and throws, stays absent',
      () async {
        // x4 entry's expected sha will not match x2 bytes.
        final downloader = _FakeDownloader(bytes: x2Bytes);
        final repo = repoWith(downloader);

        await expectLater(
          repo.ensureModel(_fx4),
          throwsA(isA<ModelVerificationException>()),
        );
        expect(await repo.stateOf(_fx4), MlModelState.absent);
        expect(await repo.sizeOf(_fx4), 0);
        // No leftover .part anywhere under the cache dir.
        final leftovers = cacheDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.part'));
        expect(leftovers, isEmpty);
      },
    );

    test(
      'non-HTTPS url → throws ModelDownloadException without downloading',
      () async {
        final downloader = _FakeDownloader(bytes: x2Bytes);
        final repo = repoWith(downloader);
        const insecure = UpscaleModelEntry(
          modelId: 'insecure',
          version: 'v1',
          url: 'http://example.com/model.onnx',
          sha256: 'deadbeef',
          scale: 2,
          license: 'Apache-2.0',
        );

        await expectLater(
          repo.ensureModel(insecure),
          throwsA(isA<ModelDownloadException>()),
        );
        expect(downloader.calls, 0, reason: 'must reject before downloading');
        expect(await repo.stateOf(insecure), MlModelState.absent);
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
          repo.ensureModel(_fx2),
          throwsA(isA<ModelDownloadException>()),
        );
        expect(await repo.stateOf(_fx2), MlModelState.absent);
      },
    );

    test('cached model is not re-downloaded', () async {
      final downloader = _FakeDownloader(bytes: x2Bytes);
      final repo = repoWith(downloader);

      final String first = await repo.ensureModel(_fx2);
      final String second = await repo.ensureModel(_fx2);

      expect(second, first);
      expect(downloader.calls, 1);
    });

    test('different versions cache to separate paths', () async {
      final repo2 = repoWith(_FakeDownloader(bytes: x2Bytes));
      final String p2 = await repo2.ensureModel(_fx2);

      final x4Bytes = await File(
        'test/fixtures/ml/upscale_x4_nearest.onnx',
      ).readAsBytes();
      final repo4 = repoWith(_FakeDownloader(bytes: x4Bytes));
      final String p4 = await repo4.ensureModel(_fx4);

      expect(p2, isNot(p4));
      // Deleting x4 leaves x2 intact.
      await repo4.delete(_fx4);
      expect(File(p2).existsSync(), isTrue);
      expect(File(p4).existsSync(), isFalse);
    });
  });

  group('ModelRepository state / size / delete / source', () {
    test('absent model reports absent and zero size', () async {
      final repo = repoWith(_FakeDownloader(bytes: x2Bytes));
      expect(await repo.stateOf(_fx2), MlModelState.absent);
      expect(await repo.sizeOf(_fx2), 0);
      expect(await repo.sourceOf(_fx2), isNull);
    });

    test('present model reports size and a file source', () async {
      final repo = repoWith(_FakeDownloader(bytes: x2Bytes));
      await repo.ensureModel(_fx2);

      expect(await repo.sizeOf(_fx2), x2Bytes.length);
      final source = await repo.sourceOf(_fx2);
      expect(source, isA<OnnxModelFileSource>());
    });

    test('delete returns to absent; second delete is a safe no-op', () async {
      final repo = repoWith(_FakeDownloader(bytes: x2Bytes));
      await repo.ensureModel(_fx2);

      await repo.delete(_fx2);
      expect(await repo.stateOf(_fx2), MlModelState.absent);
      expect(await repo.sizeOf(_fx2), 0);
      await expectLater(repo.delete(_fx2), completes);
    });
  });
}

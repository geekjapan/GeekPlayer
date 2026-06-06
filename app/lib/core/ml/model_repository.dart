import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'ml_model_state.dart';
import 'onnx_model_source.dart';
import 'upscale_model_catalog.dart';

/// Fetches the raw bytes of a model URL. Injected so tests stay offline.
abstract class ModelDownloader {
  /// Downloads [url], optionally reporting progress. Throws on network/HTTP error.
  Future<Uint8List> download(
    String url, {
    void Function(int received, int total)? onProgress,
  });
}

/// Production [ModelDownloader] backed by `dio`, requesting raw bytes over HTTPS.
class DioModelDownloader implements ModelDownloader {
  DioModelDownloader(this._dio);

  final Dio _dio;

  @override
  Future<Uint8List> download(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    final Response<List<int>> resp = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: onProgress,
    );
    final List<int>? data = resp.data;
    if (data == null) {
      throw const ModelDownloadException('empty response body');
    }
    return Uint8List.fromList(data);
  }
}

/// Thrown when a model download fails at the network/HTTP/I-O layer. Catchable
/// so the `ml-runtime` selection seam can fall back to the bicubic CPU floor.
class ModelDownloadException implements Exception {
  const ModelDownloadException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'ModelDownloadException: $message'
      : 'ModelDownloadException: $message ($cause)';
}

/// Thrown when a downloaded model's SHA-256 does not match the catalog digest.
/// Catchable; the partial file is discarded and the model stays absent.
class ModelVerificationException implements Exception {
  const ModelVerificationException(this.message);

  final String message;

  @override
  String toString() => 'ModelVerificationException: $message';
}

/// Downloads, verifies (SHA-256), caches, and manages on-device upscale models
/// (ADR-0007 step 3 — capability `upscale-model-distribution`).
///
/// Models are opt-in and never bundled. The cache layout is
/// `<cacheDir>/ml_models/<modelId>/<version>/model.onnx`, so distinct versions
/// coexist and deleting one never touches another. Confirmation is atomic:
/// bytes are verified in memory, written to a `.part` sibling, then `rename`d
/// onto the final path — so a present file is always a fully-verified model.
class ModelRepository {
  ModelRepository({required this.downloader, required this.cacheDirProvider});

  final ModelDownloader downloader;
  final Future<Directory> Function() cacheDirProvider;

  static const String _modelFileName = 'model.onnx';

  Future<Directory> _entryDir(UpscaleModelEntry entry) async {
    final Directory base = await cacheDirProvider();
    return Directory(
      p.join(base.path, 'ml_models', entry.modelId, entry.version),
    );
  }

  Future<File> _entryFile(UpscaleModelEntry entry) async {
    final Directory dir = await _entryDir(entry);
    return File(p.join(dir.path, _modelFileName));
  }

  /// The cached file for [entry] if it is present and non-empty, else `null`.
  Future<File?> _presentFile(UpscaleModelEntry entry) async {
    final File file = await _entryFile(entry);
    if (file.existsSync() && file.lengthSync() > 0) return file;
    return null;
  }

  /// Ensures [entry] is present on disk, downloading + verifying if needed, and
  /// returns its file path. Cached models are returned without any network I/O.
  Future<String> ensureModel(
    UpscaleModelEntry entry, {
    void Function(int received, int total)? onProgress,
  }) async {
    final File? cached = await _presentFile(entry);
    if (cached != null) return cached.path;

    final Uint8List bytes;
    try {
      bytes = await downloader.download(entry.url, onProgress: onProgress);
    } catch (e) {
      throw ModelDownloadException('failed to download ${entry.modelId}', e);
    }

    final String actual = sha256.convert(bytes).toString();
    if (actual.toLowerCase() != entry.sha256.toLowerCase()) {
      throw ModelVerificationException(
        'SHA-256 mismatch for ${entry.modelId}@${entry.version}: '
        'expected ${entry.sha256}, got $actual',
      );
    }

    final Directory dir = await _entryDir(entry);
    await dir.create(recursive: true);
    final File finalFile = File(p.join(dir.path, _modelFileName));
    final File partFile = File('${finalFile.path}.part');
    try {
      await partFile.writeAsBytes(bytes, flush: true);
      await partFile.rename(finalFile.path);
    } catch (e) {
      if (partFile.existsSync()) {
        try {
          await partFile.delete();
        } catch (_) {}
      }
      throw ModelDownloadException('failed to write ${entry.modelId}', e);
    }
    return finalFile.path;
  }

  /// Whether [entry] is present on disk.
  Future<MlModelState> stateOf(UpscaleModelEntry entry) async =>
      (await _presentFile(entry)) != null
      ? MlModelState.present
      : MlModelState.absent;

  /// The on-disk size of [entry] in bytes (0 if absent).
  Future<int> sizeOf(UpscaleModelEntry entry) async {
    final File? file = await _presentFile(entry);
    return file == null ? 0 : file.lengthSync();
  }

  /// An [OnnxModelSource] for [entry] if present, else `null`.
  Future<OnnxModelSource?> sourceOf(UpscaleModelEntry entry) async {
    final File? file = await _presentFile(entry);
    return file == null ? null : OnnxModelSource.file(file.path);
  }

  /// Deletes [entry] from the cache. Safe no-op if already absent.
  Future<void> delete(UpscaleModelEntry entry) async {
    final Directory dir = await _entryDir(entry);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}

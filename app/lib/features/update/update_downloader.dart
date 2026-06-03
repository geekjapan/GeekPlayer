/// In-app update downloader.
///
/// `UpdateDownloader` is abstract so tests can inject a fake via Riverpod
/// override. `DioUpdateDownloader` is the live implementation.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'release_asset.dart';

part 'update_downloader.g.dart';

/// Downloads a [ReleaseAsset] to the OS temporary directory with progress.
///
/// Returns the absolute path of the downloaded file.
/// Throws [NetworkUnreachableError] / [UpstreamUnavailableError] on failure.
abstract class UpdateDownloader {
  /// Downloads [asset] to a temporary file.
  ///
  /// [onProgress] receives `(received, total)` where `total` may be -1 when
  /// the server does not send Content-Length.
  ///
  /// [cancelToken] may be provided to cancel the download mid-flight.
  Future<String> download(
    ReleaseAsset asset, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  });
}

/// Live [UpdateDownloader] implementation backed by `dio`.
final class DioUpdateDownloader implements UpdateDownloader {
  DioUpdateDownloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<String> download(
    ReleaseAsset asset, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final Directory tmpDir = await getTemporaryDirectory();
    final String destPath = p.join(tmpDir.path, asset.name);

    await _dio.download(
      asset.downloadUrl,
      destPath,
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
      options: Options(
        headers: <String, String>{'Accept': 'application/octet-stream'},
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 30),
      ),
    );

    return destPath;
  }
}

/// Provides the live [UpdateDownloader] implementation.
///
/// Tests override via:
/// ```dart
/// updateDownloaderProvider.overrideWithValue(FakeUpdateDownloader(...))
/// ```
@Riverpod(keepAlive: true)
UpdateDownloader updateDownloader(Ref ref) => DioUpdateDownloader();

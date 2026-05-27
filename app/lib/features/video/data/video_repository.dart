import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/database.dart';
import '../domain/video_file.dart';

/// Result of a "pick a video" interaction. `null` means user cancelled.
typedef VideoPickResult = VideoFile?;

/// Repository wiring [file_picker] + drift DAOs for the video feature.
///
/// Keeps both DAOs behind a single seam so the use-case layer only depends
/// on one collaborator. Constructor takes the DAOs (not the database) to
/// keep tests narrow and to mirror how Riverpod providers will resolve
/// them in production.
class VideoRepository {
  VideoRepository({
    required this.positionsDao,
    required this.recentItemsDao,
    FilePickerDelegate? filePicker,
  }) : _filePicker = filePicker ?? const _DefaultFilePicker();

  final PlaybackPositionsDao positionsDao;
  final RecentItemsDao recentItemsDao;
  final FilePickerDelegate _filePicker;

  /// Show the OS file picker filtered to video file types. Returns `null`
  /// when the user cancels. The returned [VideoFile] carries a normalised
  /// `file://` URI ready to be persisted.
  Future<VideoPickResult> pickFile() async {
    final String? path = await _filePicker.pickSingleFile(
      allowedExtensions: const <String>[
        'mp4',
        'mkv',
        'mov',
        'webm',
        'avi',
        'm4v',
      ],
    );
    if (path == null) return null;
    final Uri uri = Uri.file(path);
    return VideoFile(uri: uri, displayName: p.basename(path));
  }

  /// Look up the saved [ResumePoint] for [uri], or `null` if none.
  Future<Duration?> loadResumePoint(Uri uri) {
    return positionsDao.getByUri(uri.toString());
  }

  /// Persist the current playhead [position] for [uri]. Called from the
  /// player screen's `dispose` handler.
  Future<void> saveResumePoint(Uri uri, Duration position) {
    return positionsDao.upsert(uri.toString(), position);
  }

  /// Record an "opened" event in the recent-items list (kind = `'video'`).
  Future<void> recordRecentOpen(Uri uri) {
    return recentItemsDao.recordOpen(uri.toString(), 'video');
  }

  /// Reverse-chronological recent items, mapped back to [VideoFile]s for
  /// display. Filters to `kind == 'video'`.
  Future<List<VideoFile>> fetchRecentItems({int limit = kRecentItemsCap}) async {
    final List<RecentItemRow> rows = await recentItemsDao.list(limit: limit);
    return rows
        .where((RecentItemRow r) => r.kind == 'video')
        .map((RecentItemRow r) {
      final Uri uri = Uri.parse(r.uri);
      final String name =
          uri.scheme == 'file' ? p.basename(uri.toFilePath()) : r.uri;
      return VideoFile(uri: uri, displayName: name);
    }).toList(growable: false);
  }

  /// Remove [uri] from both the recent-items list and the playback
  /// positions table. Used when a stale (deleted) file is detected.
  Future<void> forgetStaleEntry(Uri uri) async {
    await recentItemsDao.deleteByUri(uri.toString());
    await positionsDao.deleteByUri(uri.toString());
  }

  /// Returns `true` when the file referenced by [uri] still exists on
  /// disk. Web (`http://`) URIs are not supported in v0.1; non-file URIs
  /// return `false`.
  Future<bool> fileExists(Uri uri) async {
    if (uri.scheme != 'file') return false;
    try {
      return File(uri.toFilePath()).exists();
    } on Exception {
      return false;
    }
  }
}

/// Test seam: lets unit tests replace the OS file picker without dragging
/// in MethodChannel mocks. Production uses [_DefaultFilePicker].
abstract class FilePickerDelegate {
  const FilePickerDelegate();
  Future<String?> pickSingleFile({required List<String> allowedExtensions});
}

class _DefaultFilePicker extends FilePickerDelegate {
  const _DefaultFilePicker();

  @override
  Future<String?> pickSingleFile({
    required List<String> allowedExtensions,
  }) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
    );
    if (result == null) return null;
    final PlatformFile file = result.files.single;
    final String? path = file.path;
    if (path == null) {
      if (kDebugMode) {
        debugPrint('VideoRepository: file_picker returned null path; '
            'this is unexpected on desktop/Android in v0.1.');
      }
      return null;
    }
    return path;
  }
}

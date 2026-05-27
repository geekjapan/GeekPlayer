import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/database.dart';
import '../domain/audio_track.dart';

/// Supported audio file extensions for v0.1 (proposal §"What Changes").
/// Lowercase, no leading dot.
const Set<String> kSupportedAudioExtensions = <String>{
  'mp3',
  'flac',
  'm4a',
  'aac',
  'ogg',
  'opus',
  'wav',
};

/// Result of a "pick audio" interaction. May be a single track or a
/// queue derived from a folder. `null` means the user cancelled.
@immutable
class AudioPickResult {
  const AudioPickResult({required this.tracks, required this.sourceUri});
  final List<AudioTrack> tracks;

  /// URI to write to `recent_items` (single-file picks store the file
  /// URI; folder picks store the folder URI so the recent-list entry
  /// re-opens the folder).
  final Uri sourceUri;

  bool get isEmpty => tracks.isEmpty;
}

/// Repository wiring [file_picker] + drift DAOs for the audio feature.
class AudioRepository {
  AudioRepository({
    required this.positionsDao,
    required this.recentItemsDao,
    AudioPickerDelegate? filePicker,
  }) : _filePicker = filePicker ?? const _DefaultFilePicker();

  final PlaybackPositionsDao positionsDao;
  final RecentItemsDao recentItemsDao;
  final AudioPickerDelegate _filePicker;

  /// Show the OS picker. The user can pick a single audio file **or**
  /// a folder; the result drives an in-memory queue (design.md D3).
  /// Returns `null` on cancel.
  Future<AudioPickResult?> pickFileOrFolder() async {
    final PickedAudioSource? picked = await _filePicker.pick();
    if (picked == null) return null;
    if (picked.isFolder) {
      return expandFolderToQueue(picked.path);
    }
    final String path = picked.path;
    final Uri uri = Uri.file(path);
    return AudioPickResult(
      tracks: <AudioTrack>[AudioTrack(uri: uri, displayName: p.basename(path))],
      sourceUri: uri,
    );
  }

  /// Enumerate [folderPath] **non-recursively** and assemble a queue of
  /// [AudioTrack]s in file-name ascending order, restricted to the
  /// supported extensions. Returns `null` when the folder contains no
  /// playable file (caller surfaces the "no playable files" message).
  Future<AudioPickResult?> expandFolderToQueue(String folderPath) async {
    final Directory dir = Directory(folderPath);
    if (!await dir.exists()) return null;
    final List<FileSystemEntity> entries = await dir.list().toList();
    final List<File> files =
        entries
            .whereType<File>()
            .where((File f) => _isSupported(f.path))
            .toList()
          ..sort(
            (File a, File b) => p
                .basename(a.path)
                .toLowerCase()
                .compareTo(p.basename(b.path).toLowerCase()),
          );
    if (files.isEmpty) return null;
    final List<AudioTrack> tracks = files
        .map((File f) {
          final Uri u = Uri.file(f.path);
          return AudioTrack(uri: u, displayName: p.basename(f.path));
        })
        .toList(growable: false);
    return AudioPickResult(
      tracks: tracks,
      sourceUri: Uri.directory(folderPath),
    );
  }

  static bool _isSupported(String filePath) {
    final String ext = p.extension(filePath).toLowerCase();
    if (ext.isEmpty) return false;
    return kSupportedAudioExtensions.contains(ext.substring(1));
  }

  /// Look up the saved ResumePoint for [uri], or `null` if none.
  Future<Duration?> loadResumePoint(Uri uri) {
    return positionsDao.getByUri(uri.toString());
  }

  /// Persist the playhead [position] for [uri]. Called when switching
  /// tracks or leaving the player screen.
  Future<void> saveResumePoint(Uri uri, Duration position) {
    return positionsDao.upsert(uri.toString(), position);
  }

  /// Record an "opened" event in the recent-items list (kind `'audio'`).
  Future<void> recordRecentOpen(Uri uri) {
    return recentItemsDao.recordOpen(uri.toString(), 'audio');
  }

  /// Reverse-chronological recent items for `kind='audio'`. Each entry
  /// is wrapped in an [AudioTrack] with a basename-derived display name.
  Future<List<AudioTrack>> fetchRecentAudioItems({
    int limit = kRecentItemsCap,
  }) async {
    final List<RecentItemRow> rows = await recentItemsDao.fetchByKind(
      'audio',
      limit: limit,
    );
    return rows
        .map((RecentItemRow r) {
          final Uri uri = Uri.parse(r.uri);
          final String name = uri.scheme == 'file'
              ? (uri.pathSegments.isEmpty
                    ? r.uri
                    : p.basename(uri.toFilePath()))
              : r.uri;
          return AudioTrack(uri: uri, displayName: name);
        })
        .toList(growable: false);
  }

  /// Remove [uri] from `recent_items` and `playback_positions`. Used
  /// when a stale (deleted) source is detected on tap.
  Future<void> forgetStaleEntry(Uri uri) async {
    await recentItemsDao.deleteByUri(uri.toString());
    await positionsDao.deleteByUri(uri.toString());
  }

  /// Returns `true` when the source referenced by [uri] still exists.
  /// Handles both single-file and folder URIs.
  Future<bool> sourceExists(Uri uri) async {
    if (uri.scheme != 'file') return false;
    try {
      final String path = uri.toFilePath();
      if (await FileSystemEntity.isDirectory(path)) {
        return Directory(path).exists();
      }
      return File(path).exists();
    } on Exception {
      return false;
    }
  }
}

/// Picker abstraction so widget tests can drive picks without the
/// MethodChannel mock surface. Production wraps `file_picker`.
abstract class AudioPickerDelegate {
  const AudioPickerDelegate();
  Future<PickedAudioSource?> pick();
}

/// Result of [AudioPickerDelegate.pick]: either a single file path or
/// a folder path. Exposed (not private) so tests can drive the picker
/// delegate without copying types.
class PickedAudioSource {
  const PickedAudioSource.file(this.path) : isFolder = false;
  const PickedAudioSource.folder(this.path) : isFolder = true;
  final String path;
  final bool isFolder;
}

class _DefaultFilePicker extends AudioPickerDelegate {
  const _DefaultFilePicker();

  @override
  Future<PickedAudioSource?> pick() async {
    // file_picker's API does not allow "file OR folder" in a single
    // call. We bias to file-pick first; the home section also exposes
    // a separate "フォルダを開く" affordance via [expandFolderToQueue].
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: kSupportedAudioExtensions.toList(growable: false),
    );
    if (result == null) return null;
    final PlatformFile file = result.files.single;
    final String? path = file.path;
    if (path == null) {
      if (kDebugMode) {
        debugPrint(
          'AudioRepository: file_picker returned null path; '
          'desktop / Android in v0.1 should always supply one.',
        );
      }
      return null;
    }
    return PickedAudioSource.file(path);
  }
}

/// Public helper for the UI: pick a folder explicitly.
extension AudioRepositoryFolderPick on AudioRepository {
  /// Show the OS folder picker and expand the picked folder into a
  /// queue. Returns `null` on cancel or when the folder has no playable
  /// audio file.
  Future<AudioPickResult?> pickFolder() async {
    final String? folder = await FilePicker.getDirectoryPath();
    if (folder == null) return null;
    return expandFolderToQueue(folder);
  }
}

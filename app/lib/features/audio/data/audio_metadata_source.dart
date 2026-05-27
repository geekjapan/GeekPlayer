import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;
import 'package:flutter/foundation.dart';

import '../domain/audio_track.dart';

/// Reads track-level tags via `audio_metadata_reader`. Used by the
/// audio controller when a track becomes current (D4 — lazy).
///
/// Returns [AudioMetadata] with whatever fields the reader could
/// resolve. Errors and missing tags are coerced to a `null` field
/// rather than thrown — the caller folds back to file-name / placeholder
/// fallbacks via [AudioTrack.effectiveTitle] etc.
class AudioMetadataSource {
  const AudioMetadataSource();

  /// Read metadata for [uri]. Non-`file://` URIs are not supported in
  /// v0.1 (network streams come later) and return an empty metadata
  /// object. The returned future never throws — failures degrade to an
  /// empty result so the UI never crashes on a bad tag block.
  Future<AudioMetadata> readMetadata(Uri uri) async {
    if (uri.scheme != 'file') {
      return const AudioMetadata();
    }
    final File file = File(uri.toFilePath());
    if (!await file.exists()) {
      return const AudioMetadata();
    }
    try {
      // The library is synchronous; offload to an isolate if it ever
      // becomes a bottleneck. For v0.1 we run it inline — tag blocks
      // are small.
      final amr.AudioMetadata raw = amr.readMetadata(file, getImage: true);
      Uint8List? artwork;
      if (raw.pictures.isNotEmpty) {
        // Prefer the first picture (typically the front cover).
        artwork = raw.pictures.first.bytes;
      }
      return AudioMetadata(
        title: _trimToNull(raw.title),
        artist: _trimToNull(raw.artist),
        album: _trimToNull(raw.album),
        artworkBytes: artwork,
      );
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('AudioMetadataSource: failed to read tags for $uri: $e');
      }
      return const AudioMetadata();
    }
  }

  static String? _trimToNull(String? s) {
    if (s == null) return null;
    final String t = s.trim();
    return t.isEmpty ? null : t;
  }
}

import 'package:flutter/foundation.dart';

/// Domain value object representing a single audio Episode the user can
/// (or has) opened.
///
/// `uri` is the canonical key written to drift (`file://...`).
/// `displayName` is the source file's basename — what we render before
/// metadata loads. `metadata` is filled in lazily once `audio_metadata_
/// reader` resolves; until then it is `null`.
@immutable
class AudioTrack {
  const AudioTrack({
    required this.uri,
    required this.displayName,
    this.metadata,
  });

  final Uri uri;
  final String displayName;
  final AudioMetadata? metadata;

  /// URI as the string form persisted in drift.
  String get uriString => uri.toString();

  /// Title that the player UI should show right now. Falls back to the
  /// file's basename (without extension) when no tag-derived title is
  /// available.
  String get effectiveTitle {
    final String? t = metadata?.title;
    if (t != null && t.isNotEmpty) return t;
    final int dot = displayName.lastIndexOf('.');
    return dot > 0 ? displayName.substring(0, dot) : displayName;
  }

  /// Artist line for the player UI, with the project-wide fallback.
  String get effectiveArtist => metadata?.artist ?? '不明なアーティスト';

  /// Album line. May be empty (renders as a blank line in the UI).
  String get effectiveAlbum => metadata?.album ?? '';

  AudioTrack copyWith({
    Uri? uri,
    String? displayName,
    AudioMetadata? metadata,
  }) {
    return AudioTrack(
      uri: uri ?? this.uri,
      displayName: displayName ?? this.displayName,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioTrack &&
        other.uri == uri &&
        other.displayName == displayName &&
        other.metadata == metadata;
  }

  @override
  int get hashCode => Object.hash(uri, displayName, metadata);

  @override
  String toString() => 'AudioTrack($displayName, $uri)';
}

/// Lazily-resolved metadata for an [AudioTrack]. All fields are
/// nullable so partial reads are representable. `artworkBytes` is the
/// raw embedded image (typically JPEG / PNG); the UI is responsible for
/// decoding it.
@immutable
class AudioMetadata {
  const AudioMetadata({this.title, this.artist, this.album, this.artworkBytes});

  final String? title;
  final String? artist;
  final String? album;
  final Uint8List? artworkBytes;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioMetadata &&
        other.title == title &&
        other.artist == artist &&
        other.album == album &&
        // Bytes equality by reference is intentional — the underlying
        // package always returns a fresh `Uint8List` per call, so
        // structural equality would require an O(n) compare on every
        // rebuild. Identity suffices for state-class diffing.
        identical(other.artworkBytes, artworkBytes);
  }

  @override
  int get hashCode => Object.hash(title, artist, album, artworkBytes);
}

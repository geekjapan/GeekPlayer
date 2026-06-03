/// Domain model for an indexed local media file.
class MediaItem {
  const MediaItem({
    required this.uri,
    required this.path,
    required this.kind,
    required this.title,
    required this.extension,
    required this.fileSizeBytes,
    required this.fileLastModified,
    required this.scannedAt,
  });

  /// Normalized `file://` URI.
  final String uri;

  /// Resolved absolute path.
  final String path;

  /// `'video'` or `'audio'`.
  final String kind;

  /// Display title (filename stem).
  final String title;

  /// Lower-case file extension without dot (e.g. `'mp4'`).
  final String extension;

  final int fileSizeBytes;
  final DateTime fileLastModified;
  final DateTime scannedAt;
}

/// Domain model for watch/play history of a single media item.
class WatchHistoryEntry {
  const WatchHistoryEntry({
    required this.uri,
    required this.lastPlayedAt,
    required this.positionMs,
    required this.durationMs,
    required this.completed,
  });

  final String uri;
  final DateTime lastPlayedAt;
  final int positionMs;
  final int durationMs;
  final bool completed;
}

/// Domain model for a favorited media item.
class FavoriteItem {
  const FavoriteItem({required this.uri, required this.favoritedAt});

  final String uri;
  final DateTime favoritedAt;
}

/// Domain model for a user-created playlist.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Domain model for an ordered item within a playlist.
class PlaylistItem {
  const PlaylistItem({
    required this.playlistId,
    required this.mediaUri,
    required this.position,
  });

  final int playlistId;
  final String mediaUri;
  final int position;
}

/// Supported video file extensions (lower-case, no dot).
const Set<String> kVideoExtensions = <String>{
  'mp4',
  'mkv',
  'avi',
  'mov',
  'webm',
};

/// Supported audio file extensions (lower-case, no dot).
const Set<String> kAudioExtensions = <String>{
  'mp3',
  'flac',
  'aac',
  'wav',
  'ogg',
  'm4a',
  'opus',
};

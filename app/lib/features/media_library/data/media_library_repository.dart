import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/storage/database.dart';
import '../domain/media_item.dart';

/// Repository for local media library operations.
///
/// Folder scanning runs via [scanFolder], which lists [dir] recursively
/// and upserts every supported file into [MediaIndex]. All other methods
/// are thin wrappers over the DAOs.
class MediaLibraryRepository {
  const MediaLibraryRepository({
    required this.mediaIndexDao,
    required this.watchHistoryDao,
    required this.favoritesDao,
    required this.playlistsDao,
    required this.playlistItemsDao,
  });

  final MediaIndexDao mediaIndexDao;
  final WatchHistoryDao watchHistoryDao;
  final FavoritesDao favoritesDao;
  final PlaylistsDao playlistsDao;
  final PlaylistItemsDao playlistItemsDao;

  // ---------------------------------------------------------------------------
  // Folder scanning
  // ---------------------------------------------------------------------------

  /// Scan [dirPath] recursively, indexing every supported media file.
  /// Returns the number of files indexed (inserted or updated).
  Future<int> scanFolder(String dirPath) async {
    final Directory dir = Directory(dirPath);
    if (!dir.existsSync()) return 0;

    int count = 0;
    final DateTime now = DateTime.now().toUtc();

    await for (final FileSystemEntity entity in dir.list(recursive: true)) {
      if (entity is! File) continue;
      final String ext = p
          .extension(entity.path)
          .toLowerCase()
          .replaceFirst('.', '');
      String? kind;
      if (kVideoExtensions.contains(ext)) {
        kind = 'video';
      } else if (kAudioExtensions.contains(ext)) {
        kind = 'audio';
      } else {
        continue;
      }

      final FileStat stat = entity.statSync();
      final String uri = entity.uri.toString();
      final String title = p.basenameWithoutExtension(entity.path);

      await mediaIndexDao.upsert(
        uri: uri,
        path: entity.path,
        kind: kind,
        title: title,
        extension: ext,
        fileSizeBytes: stat.size,
        fileLastModified: stat.modified.toUtc(),
        scannedAt: now,
      );
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Media index
  // ---------------------------------------------------------------------------

  Future<List<MediaItem>> listAll() async {
    return (await mediaIndexDao.listAll()).map(_rowToItem).toList();
  }

  Future<List<MediaItem>> listByKind(String kind) async {
    return (await mediaIndexDao.listByKind(kind)).map(_rowToItem).toList();
  }

  // ---------------------------------------------------------------------------
  // Watch history
  // ---------------------------------------------------------------------------

  Future<void> recordPlayed({
    required String uri,
    required DateTime playedAt,
    required int positionMs,
    required int durationMs,
    required bool completed,
  }) {
    return watchHistoryDao.upsert(
      uri: uri,
      lastPlayedAt: playedAt,
      positionMs: positionMs,
      durationMs: durationMs,
      completed: completed,
    );
  }

  Future<List<WatchHistoryEntry>> listRecent({int limit = 50}) async {
    return (await watchHistoryDao.listRecent(
      limit: limit,
    )).map(_rowToHistoryEntry).toList();
  }

  Future<WatchHistoryEntry?> getHistory(String uri) async {
    final WatchHistoryRow? row = await watchHistoryDao.getByUri(uri);
    return row == null ? null : _rowToHistoryEntry(row);
  }

  // ---------------------------------------------------------------------------
  // Favorites
  // ---------------------------------------------------------------------------

  Future<void> addFavorite(String uri) {
    return favoritesDao.add(uri, DateTime.now().toUtc());
  }

  Future<void> removeFavorite(String uri) async {
    await favoritesDao.remove(uri);
  }

  Future<bool> isFavorite(String uri) {
    return favoritesDao.isFavorite(uri);
  }

  Future<List<FavoriteItem>> listFavorites() async {
    return (await favoritesDao.listAll())
        .map(
          (FavoriteRow r) =>
              FavoriteItem(uri: r.uri, favoritedAt: r.favoritedAt),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Playlists
  // ---------------------------------------------------------------------------

  Future<int> createPlaylist(String name) {
    return playlistsDao.create(name, DateTime.now().toUtc());
  }

  Future<void> renamePlaylist(int id, String newName) {
    return playlistsDao.rename(id, newName, DateTime.now().toUtc());
  }

  Future<List<Playlist>> listPlaylists() async {
    return (await playlistsDao.listAll()).map(_rowToPlaylist).toList();
  }

  Future<void> deletePlaylist(int id) {
    return playlistsDao.deleteById(id);
  }

  Future<void> addToPlaylist(int playlistId, String mediaUri) async {
    final List<PlaylistItemRow> existing = await playlistItemsDao
        .listByPlaylist(playlistId);
    final int position = existing.length;
    await playlistItemsDao.add(
      playlistId: playlistId,
      mediaUri: mediaUri,
      position: position,
    );
  }

  Future<void> removeFromPlaylist(int playlistId, String mediaUri) {
    return playlistItemsDao.remove(playlistId, mediaUri);
  }

  Future<List<PlaylistItem>> listPlaylistItems(int playlistId) async {
    return (await playlistItemsDao.listByPlaylist(
      playlistId,
    )).map(_rowToPlaylistItem).toList();
  }

  Future<void> reorderPlaylist(int playlistId, List<String> orderedUris) {
    return playlistItemsDao.replaceAll(playlistId, orderedUris);
  }

  // ---------------------------------------------------------------------------
  // Mappers
  // ---------------------------------------------------------------------------

  MediaItem _rowToItem(MediaIndexRow row) => MediaItem(
    uri: row.uri,
    path: row.path,
    kind: row.kind,
    title: row.title,
    extension: row.extension,
    fileSizeBytes: row.fileSizeBytes,
    fileLastModified: row.fileLastModified,
    scannedAt: row.scannedAt,
  );

  WatchHistoryEntry _rowToHistoryEntry(WatchHistoryRow row) =>
      WatchHistoryEntry(
        uri: row.uri,
        lastPlayedAt: row.lastPlayedAt,
        positionMs: row.positionMs,
        durationMs: row.durationMs,
        completed: row.completed,
      );

  Playlist _rowToPlaylist(PlaylistRow row) => Playlist(
    id: row.id,
    name: row.name,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  PlaylistItem _rowToPlaylistItem(PlaylistItemRow row) => PlaylistItem(
    playlistId: row.playlistId,
    mediaUri: row.mediaUri,
    position: row.position,
  );
}

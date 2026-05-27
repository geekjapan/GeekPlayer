import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'database.dart';

part 'providers.g.dart';

/// Application-wide singleton [AppDatabase]. Keeps the underlying SQLite
/// connection alive for the lifetime of the process; disposed only when
/// the provider container is torn down (rare outside tests).
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
PlaybackPositionsDao playbackPositionsDao(Ref ref) {
  return ref.watch(appDatabaseProvider).playbackPositionsDao;
}

@Riverpod(keepAlive: true)
RecentItemsDao recentItemsDao(Ref ref) {
  return ref.watch(appDatabaseProvider).recentItemsDao;
}

@Riverpod(keepAlive: true)
NovelWorksDao novelWorksDao(Ref ref) {
  return ref.watch(appDatabaseProvider).novelWorksDao;
}

@Riverpod(keepAlive: true)
NovelEpisodesDao novelEpisodesDao(Ref ref) {
  return ref.watch(appDatabaseProvider).novelEpisodesDao;
}

@Riverpod(keepAlive: true)
NovelBookmarksDao novelBookmarksDao(Ref ref) {
  return ref.watch(appDatabaseProvider).novelBookmarksDao;
}

@Riverpod(keepAlive: true)
SiteConsentsDao siteConsentsDao(Ref ref) {
  return ref.watch(appDatabaseProvider).siteConsentsDao;
}

@Riverpod(keepAlive: true)
AppSettingsDao appSettingsDao(Ref ref) {
  return ref.watch(appDatabaseProvider).appSettingsDao;
}

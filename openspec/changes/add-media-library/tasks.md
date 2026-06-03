## 1. Storage — Tables and Migration

- [x] 1.1 Add `app/lib/core/storage/tables/media_index.dart` (Drift table)
- [x] 1.2 Add `app/lib/core/storage/tables/watch_history.dart` (Drift table)
- [x] 1.3 Add `app/lib/core/storage/tables/favorites.dart` (Drift table)
- [x] 1.4 Add `app/lib/core/storage/tables/playlists.dart` (Drift table)
- [x] 1.5 Add `app/lib/core/storage/tables/playlist_items.dart` (Drift table)
- [x] 1.6 Add `app/lib/core/storage/migrations/v5_to_v6.dart` with `migrateV5ToV6`
- [x] 1.7 Bump `AppDatabase.schemaVersion` to 6 and wire v5→v6 migration in `database.dart`
- [x] 1.8 Add DAOs: `MediaIndexDao`, `WatchHistoryDao`, `FavoritesDao`, `PlaylistsDao`, `PlaylistItemsDao` in `database.dart`

## 2. Tests — Migration and DAOs

- [x] 2.1 Add `app/test/core/storage/migration_v5_to_v6_test.dart` mirroring v4→v5 test structure
- [x] 2.2 Test covers: v5→v6 migration preserves all prior data, v1→v6 skip, fresh install at v6
- [x] 2.3 Test covers: DAO round-trips for `MediaIndexDao`, `WatchHistoryDao`, `FavoritesDao`, `PlaylistsDao`/`PlaylistItemsDao`

## 3. Domain and Data Layer

- [x] 3.1 Add domain models: `MediaItem`, `WatchHistoryEntry`, `FavoriteItem`, `Playlist`, `PlaylistItem`
- [x] 3.2 Add `MediaLibraryRepository` with: `scanFolder`, `listAll`, `listRecent`, `upsertWatchHistory`, `toggleFavorite`, `listFavorites`, `createPlaylist`, `addToPlaylist`, `reorderPlaylist`, `deletePlaylist`
- [x] 3.3 Add Riverpod providers in `app/lib/features/media_library/data/media_library_providers.dart`

## 4. Presentation

- [x] 4.1 Add `MediaLibraryHomeSection` (order 700) and `mediaLibraryHomeSectionsProvider`
- [x] 4.2 Register `...ref.watch(mediaLibraryHomeSectionsProvider)` in `home_section_registry.dart`
- [x] 4.3 Add folder-scan entry point (button in section header)
- [x] 4.4 Display recently played items in the section body
- [x] 4.5 Display favorites count / badge

## 5. Localization

- [x] 5.1 Add new keys to `app/lib/l10n/app_ja.arb`
- [x] 5.2 Add matching keys to `app/lib/l10n/app_en.arb` (exact parity)
- [x] 5.3 Run `cd app && flutter gen-l10n`

## 6. Codegen and Verification

- [x] 6.1 Run `cd app && dart run build_runner build --delete-conflicting-outputs`
- [x] 6.2 Run `cd app && dart format --output=none --set-exit-if-changed .`
- [x] 6.3 Run `cd app && flutter analyze --fatal-infos`
- [x] 6.4 Run `cd app && flutter test`
- [x] 6.5 Run `openspec validate --all --strict` (pre-existing spec/app-settings failure is acceptable)
- [x] 6.6 Run `git diff --check`

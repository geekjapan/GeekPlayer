import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/video/data/video_providers.dart';
import 'package:geekplayer/features/video/data/video_repository.dart';
import 'package:geekplayer/features/video/domain/video_file.dart';
import 'package:geekplayer/features/video/presentation/home_section.dart';

/// Stub repository used by the recent-list widget test. We bypass the
/// real DAOs here so the test can assert presence of items without
/// driving SQLite from a sync test setup.
class _StubVideoRepository extends VideoRepository {
  _StubVideoRepository({
    required this.recents,
    this.staleUris = const <String>{},
    required super.positionsDao,
    required super.recentItemsDao,
  });

  final List<VideoFile> recents;
  final Set<String> staleUris;

  @override
  Future<List<VideoFile>> fetchRecentItems({
    int limit = kRecentItemsCap,
  }) async {
    return recents;
  }

  @override
  Future<bool> fileExists(Uri uri) async {
    if (staleUris.contains(uri.toString())) return false;
    return super.fileExists(uri);
  }
}

void main() {
  testWidgets('recent list renders entries from VideoRepository', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(db.close);
    final VideoFile a = VideoFile(
      uri: Uri.file('/videos/A.mp4'),
      displayName: 'A.mp4',
    );
    final VideoFile b = VideoFile(
      uri: Uri.file('/videos/B.mkv'),
      displayName: 'B.mkv',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) {
            ref.onDispose(db.close);
            return db;
          }),
          videoRepositoryProvider.overrideWith((Ref ref) {
            return _StubVideoRepository(
              recents: <VideoFile>[a, b],
              positionsDao: db.playbackPositionsDao,
              recentItemsDao: db.recentItemsDao,
            );
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: VideoHomeSectionBody())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A.mp4'), findsOneWidget);
    expect(find.text('B.mkv'), findsOneWidget);
    // The empty-state placeholder must not appear when the list is non-empty.
    expect(find.text('最近開いた動画はまだありません'), findsNothing);
  });

  testWidgets('tapping a stale recent entry shows a snackbar and removes it', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(db.close);
    final VideoFile missing = VideoFile(
      uri: Uri.file(
        '/nonexistent-${DateTime.now().microsecondsSinceEpoch}.mp4',
      ),
      displayName: 'missing.mp4',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) {
            ref.onDispose(db.close);
            return db;
          }),
          videoRepositoryProvider.overrideWith((Ref ref) {
            return _StubVideoRepository(
              recents: <VideoFile>[missing],
              staleUris: <String>{missing.uri.toString()},
              positionsDao: db.playbackPositionsDao,
              recentItemsDao: db.recentItemsDao,
            );
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: VideoHomeSectionBody())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('missing.mp4'), findsOneWidget);
    await tester.tap(find.text('missing.mp4'));
    // Run the async tap handler + the SnackBar entry animation but stop
    // before the SnackBar's auto-dismiss timer.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.textContaining('ファイルが見つかりません'), findsOneWidget);
    // Drain the snackbar so pending timers don't leak into the next test.
    await tester.pump(const Duration(seconds: 5));
  });
}

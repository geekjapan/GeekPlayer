import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/audio/data/audio_providers.dart';
import 'package:geekplayer/features/audio/data/audio_repository.dart';
import 'package:geekplayer/features/audio/domain/audio_track.dart';
import 'package:geekplayer/features/audio/presentation/home_section.dart';

class _StubAudioRepository extends AudioRepository {
  _StubAudioRepository({
    required this.recents,
    required super.positionsDao,
    required super.recentItemsDao,
  });

  final List<AudioTrack> recents;

  @override
  Future<List<AudioTrack>> fetchRecentAudioItems({int limit = 50}) async {
    return recents;
  }
}

void main() {
  testWidgets(
    'AudioHomeSectionBody renders 音楽を開く + フォルダを開く + empty-state placeholder',
    (WidgetTester tester) async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWith((Ref ref) {
              ref.onDispose(db.close);
              return db;
            }),
            audioRepositoryProvider.overrideWith((Ref ref) {
              return _StubAudioRepository(
                recents: const <AudioTrack>[],
                positionsDao: db.playbackPositionsDao,
                recentItemsDao: db.recentItemsDao,
              );
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AudioHomeSectionBody()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('音楽'), findsOneWidget);
      expect(find.text('音楽を開く'), findsOneWidget);
      expect(find.text('フォルダを開く'), findsOneWidget);
      expect(find.text('最近開いた音楽はまだありません'), findsOneWidget);
    },
  );

  testWidgets('AudioHomeSectionBody renders recent entries when non-empty', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(db.close);

    final AudioTrack a = AudioTrack(
      uri: Uri.file('/music/A.mp3'),
      displayName: 'A.mp3',
    );
    final AudioTrack b = AudioTrack(
      uri: Uri.file('/music/B.flac'),
      displayName: 'B.flac',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) {
            ref.onDispose(db.close);
            return db;
          }),
          audioRepositoryProvider.overrideWith((Ref ref) {
            return _StubAudioRepository(
              recents: <AudioTrack>[a, b],
              positionsDao: db.playbackPositionsDao,
              recentItemsDao: db.recentItemsDao,
            );
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: AudioHomeSectionBody())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A.mp3'), findsOneWidget);
    expect(find.text('B.flac'), findsOneWidget);
    expect(find.text('最近開いた音楽はまだありません'), findsNothing);
  });
}

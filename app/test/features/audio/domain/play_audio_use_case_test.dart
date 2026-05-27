import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/features/audio/data/audio_repository.dart';
import 'package:geekplayer/features/audio/domain/play_audio_use_case.dart';

void main() {
  late AppDatabase db;
  late AudioRepository repo;
  late PlayAudioUseCase useCase;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    repo = AudioRepository(
      positionsDao: db.playbackPositionsDao,
      recentItemsDao: db.recentItemsDao,
    );
    useCase = PlayAudioUseCase(repo);
  });

  tearDown(() => db.close());

  test('returns Duration.zero when no resume point is saved', () async {
    final Uri uri = Uri.parse('file:///fresh.mp3');
    expect(await useCase.resolveStart(uri), Duration.zero);
  });

  test('returns the saved position verbatim when duration unknown', () async {
    final Uri uri = Uri.parse('file:///mid.mp3');
    await repo.saveResumePoint(uri, const Duration(seconds: 75));
    expect(await useCase.resolveStart(uri), const Duration(seconds: 75));
  });

  test(
    'returns Duration.zero when saved position is within end threshold',
    () async {
      final Uri uri = Uri.parse('file:///near-end.mp3');
      await repo.saveResumePoint(uri, const Duration(minutes: 3, seconds: 57));
      final Duration start = await useCase.resolveStart(
        uri,
        knownDuration: const Duration(minutes: 4),
      );
      expect(start, Duration.zero);
    },
  );

  test(
    'returns the saved position when duration is comfortably ahead',
    () async {
      final Uri uri = Uri.parse('file:///middle.mp3');
      await repo.saveResumePoint(uri, const Duration(minutes: 1));
      final Duration start = await useCase.resolveStart(
        uri,
        knownDuration: const Duration(minutes: 4),
      );
      expect(start, const Duration(minutes: 1));
    },
  );

  test(
    'applyEndOfPlaybackRule guard: zero / negative duration returns saved',
    () {
      expect(
        PlayAudioUseCase.applyEndOfPlaybackRule(
          const Duration(seconds: 10),
          Duration.zero,
        ),
        const Duration(seconds: 10),
      );
    },
  );
}

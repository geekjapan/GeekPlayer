import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/policy_version.dart';
import 'package:geekplayer/core/storage/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() => db.close());

  group('NovelWorksDao', () {
    test('upsert is idempotent on the composite primary key', () async {
      final DateTime now = DateTime.utc(2026, 5, 27, 10);
      await db.novelWorksDao.upsertWork(
        site: 'narou',
        externalId: 'n9669bk',
        title: 'first',
        author: 'A',
        episodeCount: 1,
        addedAt: now,
      );
      await db.novelWorksDao.upsertWork(
        site: 'narou',
        externalId: 'n9669bk',
        title: 'second',
        author: 'B',
        episodeCount: 5,
        addedAt: now,
      );
      final NovelWorkRow? row =
          await db.novelWorksDao.getWork('narou', 'n9669bk');
      expect(row, isNotNull);
      expect(row!.title, 'second');
      expect(row.author, 'B');
      expect(row.episodeCount, 5);

      // Different (site, externalId) coexists.
      await db.novelWorksDao.upsertWork(
        site: 'kakuyomu',
        externalId: 'n9669bk',
        title: 'kakuyomu work',
        author: 'C',
        episodeCount: 3,
        addedAt: now,
      );
      final List<NovelWorkRow> all = await db.novelWorksDao.listAll();
      expect(all.length, 2);
    });

    test('listBySite filters by site code', () async {
      final DateTime now = DateTime.utc(2026, 5, 27);
      await db.novelWorksDao.upsertWork(
        site: 'narou',
        externalId: 'a',
        title: 'a',
        author: 'x',
        episodeCount: 1,
        addedAt: now,
      );
      await db.novelWorksDao.upsertWork(
        site: 'kakuyomu',
        externalId: 'b',
        title: 'b',
        author: 'x',
        episodeCount: 1,
        addedAt: now,
      );
      final List<NovelWorkRow> narou =
          await db.novelWorksDao.listBySite('narou');
      expect(narou.length, 1);
      expect(narou.first.externalId, 'a');
    });

    test(
      'deleteWork cascades to novel_episodes and novel_bookmarks',
      () async {
        final DateTime now = DateTime.utc(2026, 5, 27);
        await db.novelWorksDao.upsertWork(
          site: 'narou',
          externalId: 'w1',
          title: 't',
          author: 'a',
          episodeCount: 2,
          addedAt: now,
        );
        await db.novelEpisodesDao.upsertEpisode(
          site: 'narou',
          externalId: 'w1',
          episodeIndex: 1,
          title: 'e1',
          body: 'body1',
          fetchedAt: now,
        );
        await db.novelEpisodesDao.upsertEpisode(
          site: 'narou',
          externalId: 'w1',
          episodeIndex: 2,
          title: 'e2',
          body: 'body2',
          fetchedAt: now,
        );
        await db.novelBookmarksDao.upsertBookmark(
          site: 'narou',
          externalId: 'w1',
          episodeIndex: 2,
          scrollFraction: 0.5,
          updatedAt: now,
        );

        // Sanity: a Work in a different (site, externalId) must NOT be
        // touched by the cascade.
        await db.novelWorksDao.upsertWork(
          site: 'kakuyomu',
          externalId: 'w1',
          title: 'kak',
          author: 'a',
          episodeCount: 1,
          addedAt: now,
        );
        await db.novelEpisodesDao.upsertEpisode(
          site: 'kakuyomu',
          externalId: 'w1',
          episodeIndex: 1,
          title: 'kak-e1',
          body: 'kbody',
          fetchedAt: now,
        );

        final int removed =
            await db.novelWorksDao.deleteWork('narou', 'w1');
        expect(removed, 1);
        expect(await db.novelWorksDao.getWork('narou', 'w1'), isNull);
        expect(
          await db.novelEpisodesDao.listEpisodes('narou', 'w1'),
          isEmpty,
        );
        expect(
          await db.novelBookmarksDao.getBookmark('narou', 'w1'),
          isNull,
        );

        // The kakuyomu Work survives.
        expect(
          await db.novelWorksDao.getWork('kakuyomu', 'w1'),
          isNotNull,
        );
        expect(
          (await db.novelEpisodesDao.listEpisodes('kakuyomu', 'w1')).length,
          1,
        );
      },
    );
  });

  group('NovelEpisodesDao', () {
    test('existingIndices returns the set of cached indices', () async {
      final DateTime now = DateTime.utc(2026, 5, 27);
      for (final int i in <int>[1, 3, 5]) {
        await db.novelEpisodesDao.upsertEpisode(
          site: 'narou',
          externalId: 'w1',
          episodeIndex: i,
          title: 'e$i',
          body: 'b$i',
          fetchedAt: now,
        );
      }
      final Set<int> existing =
          await db.novelEpisodesDao.existingIndices('narou', 'w1');
      expect(existing, <int>{1, 3, 5});
    });

    test('upsert is idempotent and replaces body on conflict', () async {
      final DateTime now = DateTime.utc(2026, 5, 27);
      await db.novelEpisodesDao.upsertEpisode(
        site: 'narou',
        externalId: 'w1',
        episodeIndex: 1,
        title: 'e1',
        body: 'first',
        fetchedAt: now,
      );
      await db.novelEpisodesDao.upsertEpisode(
        site: 'narou',
        externalId: 'w1',
        episodeIndex: 1,
        title: 'e1-updated',
        body: 'second',
        fetchedAt: now.add(const Duration(hours: 1)),
      );
      final NovelEpisodeRow? row =
          await db.novelEpisodesDao.getEpisode('narou', 'w1', 1);
      expect(row!.title, 'e1-updated');
      expect(row.body, 'second');
    });
  });

  group('NovelBookmarksDao', () {
    test('only one bookmark per Work (upsert replaces)', () async {
      final DateTime now = DateTime.utc(2026, 5, 27);
      await db.novelBookmarksDao.upsertBookmark(
        site: 'narou',
        externalId: 'w1',
        episodeIndex: 2,
        scrollFraction: 0.25,
        updatedAt: now,
      );
      await db.novelBookmarksDao.upsertBookmark(
        site: 'narou',
        externalId: 'w1',
        episodeIndex: 3,
        scrollFraction: 0.75,
        updatedAt: now,
      );
      final NovelBookmarkRow? row =
          await db.novelBookmarksDao.getBookmark('narou', 'w1');
      expect(row!.episodeIndex, 3);
      expect(row.scrollFraction, closeTo(0.75, 1e-9));
    });
  });

  group('SiteConsentsDao', () {
    test('hasFreshConsent reflects granted + policyVersion match', () async {
      // No row -> false
      expect(
        await db.siteConsentsDao.hasFreshConsent('narou', kPolicyVersion),
        isFalse,
      );

      // granted=false -> false
      await db.siteConsentsDao.setConsent(
        site: 'narou',
        granted: false,
        policyVersion: kPolicyVersion,
      );
      expect(
        await db.siteConsentsDao.hasFreshConsent('narou', kPolicyVersion),
        isFalse,
      );

      // granted=true with matching version -> true
      await db.siteConsentsDao.setConsent(
        site: 'narou',
        granted: true,
        policyVersion: kPolicyVersion,
      );
      expect(
        await db.siteConsentsDao.hasFreshConsent('narou', kPolicyVersion),
        isTrue,
      );

      // granted=true but stale policy version -> false
      await db.siteConsentsDao.setConsent(
        site: 'narou',
        granted: true,
        policyVersion: '2020-01-01',
      );
      expect(
        await db.siteConsentsDao.hasFreshConsent('narou', kPolicyVersion),
        isFalse,
      );
    });

    test('getAll returns one row per site', () async {
      await db.siteConsentsDao.setConsent(
        site: 'narou',
        granted: true,
        policyVersion: kPolicyVersion,
      );
      await db.siteConsentsDao.setConsent(
        site: 'kakuyomu',
        granted: false,
        policyVersion: kPolicyVersion,
      );
      final List<SiteConsentRow> rows = await db.siteConsentsDao.getAll();
      expect(rows.length, 2);
    });
  });
}

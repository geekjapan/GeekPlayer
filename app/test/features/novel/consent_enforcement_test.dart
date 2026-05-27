import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/errors.dart';
import 'package:geekplayer/core/novel/fake_novel_repository.dart';
import 'package:geekplayer/core/novel/models/episode.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/novel/models/work.dart';
import 'package:geekplayer/core/novel/models/work_id.dart';
import 'package:geekplayer/core/novel/models/work_query.dart';
import 'package:geekplayer/core/novel/policy_version.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/features/novel/data/consent_guarded_repository.dart';
import 'package:geekplayer/features/novel/data/consent_repository.dart';

void main() {
  late AppDatabase db;
  late ConsentRepository consent;
  late FakeNovelRepository fake;
  late ConsentGuardedRepository guarded;

  const WorkId workId =
      WorkId(site: Site.kakuyomu, externalId: 'k-1');

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    consent = ConsentRepository(db.siteConsentsDao);
    fake = FakeNovelRepository(
      site: Site.kakuyomu,
      seed: <WorkId, FakeWorkData>{
        workId: FakeWorkData(
          work: Work(
            id: workId,
            title: 't',
            author: 'a',
            episodeCount: 1,
            addedAt: DateTime.utc(2026, 5, 27),
          ),
          episodes: <Episode>[
            Episode(id: EpisodeId(1), title: 'e1'),
          ],
          bodies: <int, EpisodeBody>{
            1: EpisodeBody(
              body: 'hello',
              fetchedAt: DateTime.utc(2026, 5, 27),
            ),
          },
        ),
      },
    );
    guarded = ConsentGuardedRepository(inner: fake, consent: consent);
  });

  tearDown(() => db.close());

  test('throws SiteConsentRequiredError when no row exists', () async {
    await expectLater(
      guarded.fetchWork(workId),
      throwsA(
        isA<SiteConsentRequiredError>()
            .having((SiteConsentRequiredError e) => e.site, 'site', Site.kakuyomu),
      ),
    );
  });

  test('throws SiteConsentRequiredError when granted=false', () async {
    await consent.revoke(Site.kakuyomu);
    await expectLater(
      guarded.fetchEpisodeBody(workId, EpisodeId(1)),
      throwsA(isA<SiteConsentRequiredError>()),
    );
  });

  test('granted=true passes through to inner', () async {
    await consent.grant(Site.kakuyomu);
    final Work w = await guarded.fetchWork(workId);
    expect(w.title, 't');
    final EpisodeBody body =
        await guarded.fetchEpisodeBody(workId, EpisodeId(1));
    expect(body.body, 'hello');
  });

  test('fetchEpisodes stream throws before yielding when denied', () async {
    await consent.revoke(Site.kakuyomu);
    final Stream<Episode> s = guarded.fetchEpisodes(workId);
    await expectLater(
      s.toList,
      throwsA(isA<SiteConsentRequiredError>()),
    );
  });

  test('searchWorks gates on consent', () async {
    await expectLater(
      guarded.searchWorks(const WorkQuery(site: Site.kakuyomu)),
      throwsA(isA<SiteConsentRequiredError>()),
    );
  });

  test('stale policyVersion is treated as no fresh consent', () async {
    // Manually write a stale row (predates kPolicyVersion).
    await db.siteConsentsDao.setConsent(
      site: Site.kakuyomu.code,
      granted: true,
      policyVersion: '2020-01-01',
    );
    expect(
      await consent.hasFreshConsent(Site.kakuyomu),
      isFalse,
    );
    await expectLater(
      guarded.fetchWork(workId),
      throwsA(isA<SiteConsentRequiredError>()),
    );

    // Re-granting writes the current kPolicyVersion.
    await consent.grant(Site.kakuyomu);
    final SiteConsentRow? row =
        await db.siteConsentsDao.getConsent(Site.kakuyomu.code);
    expect(row!.policyVersion, kPolicyVersion);
    expect(row.granted, isTrue);
  });
}

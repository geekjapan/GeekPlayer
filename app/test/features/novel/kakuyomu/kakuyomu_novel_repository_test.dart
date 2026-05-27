import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/errors.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/novel/models/work_query.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/features/novel/data/consent_repository.dart';
import 'package:geekplayer/features/novel_kakuyomu/data/kakuyomu_html_source.dart';
import 'package:geekplayer/features/novel_kakuyomu/data/kakuyomu_novel_repository.dart';
import 'package:geekplayer/features/novel_kakuyomu/data/kakuyomu_rss_source.dart';
import 'package:geekplayer/features/novel_kakuyomu/domain/kakuyomu_search_query.dart';
import 'package:mocktail/mocktail.dart';

class _MockRss extends Mock implements KakuyomuRssSource {}

class _MockHtml extends Mock implements KakuyomuHtmlSource {}

class _FakeKakuyomuSearchQuery extends Fake implements KakuyomuSearchQuery {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeKakuyomuSearchQuery());
  });

  late AppDatabase db;
  late ConsentRepository consent;
  late _MockRss rss;
  late _MockHtml html;
  late KakuyomuNovelRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    consent = ConsentRepository(db.siteConsentsDao);
    rss = _MockRss();
    html = _MockHtml();
    repo = KakuyomuNovelRepository(
      rssSource: rss,
      htmlSource: html,
      consent: consent,
    );
  });

  tearDown(() => db.close());

  group('consent gating', () {
    test('search throws SiteConsentRequiredError when no consent', () async {
      expect(
        () => repo.search(const KakuyomuSearchQuery(keyword: 'x')),
        throwsA(isA<SiteConsentRequiredError>()),
      );
      verifyNever(() => rss.search(any()));
    });

    test('latest throws without consent', () async {
      expect(repo.latest(), throwsA(isA<SiteConsentRequiredError>()));
      verifyNever(() => rss.latest());
    });

    test('searchWorks (NovelRepository) throws without consent', () async {
      expect(
        repo.searchWorks(const WorkQuery(site: Site.kakuyomu, keyword: 'x')),
        throwsA(isA<SiteConsentRequiredError>()),
      );
    });
  });

  group('with consent', () {
    setUp(() async {
      await consent.grant(Site.kakuyomu);
    });

    test('search delegates to RSS source', () async {
      when(() => rss.search(any())).thenAnswer((_) async => const <Never>[]);
      await repo.search(const KakuyomuSearchQuery(keyword: 'q'));
      verify(() => rss.search(any())).called(1);
    });

    test('site is kakuyomu', () {
      expect(repo.site, Site.kakuyomu);
    });
  });
}

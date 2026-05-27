import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/models/episode.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/novel/models/work.dart';
import 'package:geekplayer/core/novel/models/work_id.dart';

void main() {
  group('Site', () {
    test('codes are stable and round-trip via fromCode', () {
      for (final Site s in Site.values) {
        expect(Site.fromCode(s.code), s);
      }
      expect(Site.fromCode('unknown'), isNull);
    });

    test('baseUrl points at the body-page origin per ADR-0003', () {
      expect(Site.narou.baseUrl.host, 'ncode.syosetu.com');
      expect(Site.noc.baseUrl.host, 'novel18.syosetu.com');
      expect(Site.kakuyomu.baseUrl.host, 'kakuyomu.jp');
    });

    test('exhaustive switch over Site compiles without default', () {
      // The analyzer enforces exhaustiveness on a switch expression
      // over an `enum`. If a new value is added to Site without
      // updating this switch the compile fails.
      String label(Site s) => switch (s) {
        Site.narou => 'narou',
        Site.noc => 'noc',
        Site.kakuyomu => 'kakuyomu',
      };
      for (final Site s in Site.values) {
        expect(label(s), s.code);
      }
    });
  });

  group('WorkId', () {
    test('structural equality and hashCode', () {
      const WorkId a = WorkId(site: Site.narou, externalId: 'n9669bk');
      const WorkId b = WorkId(site: Site.narou, externalId: 'n9669bk');
      const WorkId c = WorkId(site: Site.kakuyomu, externalId: 'n9669bk');
      const WorkId d = WorkId(site: Site.narou, externalId: 'other');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('toString embeds site.code and externalId', () {
      const WorkId id = WorkId(site: Site.kakuyomu, externalId: 'k-42');
      expect(id.toString(), contains('kakuyomu'));
      expect(id.toString(), contains('k-42'));
    });
  });

  group('Episode / EpisodeId / EpisodeBody', () {
    test('EpisodeId rejects index < 1', () {
      expect(() => EpisodeId(0), throwsArgumentError);
      expect(() => EpisodeId(-5), throwsArgumentError);
    });

    test('Episode structural equality holds across const construction', () {
      final Episode a = Episode(id: EpisodeId(1), title: 'e1');
      final Episode b = Episode(id: EpisodeId(1), title: 'e1');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('EpisodeBody is immutable (no setters; equality by value)', () {
      final DateTime now = DateTime.utc(2026, 5, 27);
      final EpisodeBody a = EpisodeBody(body: 'x', fetchedAt: now);
      final EpisodeBody b = EpisodeBody(body: 'x', fetchedAt: now);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('Work', () {
    test('copyWith preserves untouched fields', () {
      final Work w = Work(
        id: const WorkId(site: Site.narou, externalId: 'n1'),
        title: 't',
        author: 'a',
        episodeCount: 3,
        addedAt: DateTime.utc(2026, 5, 27),
      );
      final Work updated = w.copyWith(title: 't2');
      expect(updated.title, 't2');
      expect(updated.author, 'a');
      expect(updated.id, w.id);
      expect(updated.episodeCount, 3);
    });
  });
}

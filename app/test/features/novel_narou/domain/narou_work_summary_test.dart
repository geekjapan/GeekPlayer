import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/novel/models/work.dart';
import 'package:geekplayer/features/novel_narou/domain/narou_episode.dart';
import 'package:geekplayer/features/novel_narou/domain/narou_work_detail.dart';
import 'package:geekplayer/features/novel_narou/domain/narou_work_summary.dart';

void main() {
  group('NarouWorkSummary.toWork', () {
    test('連載作品は generalAllNo を episodeCount にマップ', () {
      const NarouWorkSummary s = NarouWorkSummary(
        ncode: 'n1234ab',
        title: '魔王',
        site: Site.narou,
        writer: '著者',
        generalAllNo: 47,
        novelType: 1,
      );
      final Work w = s.toWork();
      expect(w.id.externalId, 'n1234ab');
      expect(w.id.site, Site.narou);
      expect(w.episodeCount, 47);
      expect(w.author, '著者');
    });

    test('短編 (novelType=2) は episodeCount=1', () {
      const NarouWorkSummary s = NarouWorkSummary(
        ncode: 'n9999xx',
        title: '短編',
        site: Site.narou,
        novelType: 2,
        generalAllNo: 0,
      );
      expect(s.toWork().episodeCount, 1);
      expect(s.isShort, isTrue);
    });

    test('R18 サイトでも site=Site.noc を保つ', () {
      const NarouWorkSummary s = NarouWorkSummary(
        ncode: 'n0000zz',
        title: 't',
        site: Site.noc,
      );
      expect(s.toWork().id.site, Site.noc);
    });

    test('synopsis 空文字なら null になる', () {
      const NarouWorkSummary s = NarouWorkSummary(
        ncode: 'n0000zz',
        title: 't',
        site: Site.narou,
        story: '',
      );
      expect(s.toWork().synopsis, isNull);
    });
  });

  group('NarouWorkDetail', () {
    test('detail は summary フィールドをそのまま expose', () {
      const NarouWorkDetail d = NarouWorkDetail(
        summary: NarouWorkSummary(
          ncode: 'n1234ab',
          title: 'タイトル',
          site: Site.narou,
          generalAllNo: 10,
        ),
      );
      expect(d.ncode, 'n1234ab');
      expect(d.generalAllNo, 10);
      expect(d.toWork().episodeCount, 10);
    });
  });

  group('NarouEpisode.toEpisode', () {
    test('1-based index と subtitle がマップされる', () {
      final NarouEpisode ep = NarouEpisode(
        index: 3,
        subtitle: '第三話',
        updateAt: DateTime.utc(2026, 1, 1),
      );
      expect(ep.toEpisode().id.index, 3);
      expect(ep.toEpisode().title, '第三話');
    });
  });
}

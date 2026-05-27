import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/novel_narou/domain/narou_genre.dart';
import 'package:geekplayer/features/novel_narou/domain/narou_work_query.dart';

void main() {
  group('NarouSearchOptions.toQueryParameters', () {
    test('keyword + limit を含む最小ケース', () {
      const NarouSearchOptions opts = NarouSearchOptions(
        keyword: '魔法',
        limit: 20,
      );
      final Map<String, String> params = opts.toQueryParameters();
      expect(params['word'], '魔法');
      expect(params['lim'], '20');
      expect(params.containsKey('st'), isFalse);
    });

    test('ジャンル multi-select はコード昇順のハイフン連結', () {
      const NarouSearchOptions opts = NarouSearchOptions(
        keyword: 'a',
        genres: <NarouGenre>{NarouGenre.fantasyHigh, NarouGenre.sfSpace},
      );
      final Map<String, String> params = opts.toQueryParameters();
      // fantasyHigh=201, sfSpace=402 → '201-402'
      expect(params['genre'], '201-402');
    });

    test('文字数レンジは min-max', () {
      const NarouSearchOptions opts = NarouSearchOptions(
        keyword: 'a',
        minChars: 50000,
        maxChars: 200000,
      );
      expect(opts.toQueryParameters()['length'], '50000-200000');
    });

    test('片側のみの文字数も許容', () {
      const NarouSearchOptions minOnly = NarouSearchOptions(
        keyword: 'a',
        minChars: 50000,
      );
      expect(minOnly.toQueryParameters()['length'], '50000-');
      const NarouSearchOptions maxOnly = NarouSearchOptions(
        keyword: 'a',
        maxChars: 200000,
      );
      expect(maxOnly.toQueryParameters()['length'], '-200000');
    });

    test('lastUpdatedAfter は UNIX 秒に変換される', () {
      final NarouSearchOptions opts = NarouSearchOptions(
        keyword: 'a',
        lastUpdatedAfter: DateTime.utc(2026, 1, 1),
      );
      final int expected =
          DateTime.utc(2026, 1, 1).millisecondsSinceEpoch ~/ 1000;
      expect(opts.toQueryParameters()['lastup'], expected.toString());
    });

    test('completed=true は type=er', () {
      const NarouSearchOptions opts = NarouSearchOptions(
        keyword: 'a',
        completed: true,
      );
      expect(opts.toQueryParameters()['type'], 'er');
    });

    test('false / null フラグはキー自体省略', () {
      const NarouSearchOptions opts = NarouSearchOptions(
        keyword: 'a',
        completed: false,
        pickup: false,
        longRunning: null,
      );
      final Map<String, String> params = opts.toQueryParameters();
      expect(params.containsKey('type'), isFalse);
      expect(params.containsKey('ispickup'), isFalse);
      expect(params.containsKey('stop'), isFalse);
    });

    test('キー順序は昇順で安定', () {
      const NarouSearchOptions opts = NarouSearchOptions(
        keyword: '魔法',
        limit: 20,
        offset: 40,
        genres: <NarouGenre>{NarouGenre.fantasyHigh},
        minChars: 1000,
        completed: true,
        pickup: true,
      );
      final List<String> keys = opts.toQueryParameters().keys.toList();
      final List<String> sorted = List<String>.from(keys)..sort();
      expect(keys, sorted, reason: 'キー順序が昇順安定であること');
    });

    test('copyWith でフィールドを差し替えできる', () {
      const NarouSearchOptions base = NarouSearchOptions(keyword: 'a');
      final NarouSearchOptions next = base.copyWith(
        keyword: 'b',
        minChars: 100,
      );
      expect(next.keyword, 'b');
      expect(next.minChars, 100);
    });
  });
}

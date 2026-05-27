import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/novel_kakuyomu/data/kakuyomu_rss_source.dart';
import 'package:geekplayer/features/novel_kakuyomu/domain/kakuyomu_feed_item.dart';

/// Snapshot tests for the Kakuyomu RSS / Atom parser.
///
/// `KAKUYOMU_UPDATE_GOLDENS=1` regenerates the golden JSON files; CI
/// (and local default) compares against the checked-in goldens.
void main() {
  group('parseFeedBody', () {
    test('latest.xml (RSS) — golden parity', () async {
      await _runFixture(
        'latest.xml',
        contentType: 'application/rss+xml; charset=utf-8',
      );
    });

    test('ranking_daily.xml (RSS) — golden parity', () async {
      await _runFixture(
        'ranking_daily.xml',
        contentType: 'application/rss+xml; charset=utf-8',
      );
    });

    test('ranking_weekly.xml (Atom) — golden parity', () async {
      await _runFixture(
        'ranking_weekly.xml',
        contentType: 'application/atom+xml; charset=utf-8',
      );
    });

    test('malformed item is skipped, remaining items survive', () async {
      final File file = File('test/fixtures/kakuyomu/rss/latest.xml');
      final List<KakuyomuFeedItem> items =
          parseFeedBody(await file.readAsString(), contentType: 'rss');
      // latest.xml contains 4 <item>s but one is missing <link>; expect 3.
      expect(items.length, 3);
      for (final KakuyomuFeedItem it in items) {
        expect(it.url, isNotEmpty);
        expect(it.workId, isNotEmpty);
      }
    });
  });

  group('extractWorkIdFromUrl', () {
    test('returns numeric id from work URL', () {
      expect(
        extractWorkIdFromUrl(
          'https://kakuyomu.jp/works/1177354054881131863',
        ),
        '1177354054881131863',
      );
    });

    test('returns numeric id from episode URL', () {
      expect(
        extractWorkIdFromUrl(
          'https://kakuyomu.jp/works/1177354054881131863/episodes/42',
        ),
        '1177354054881131863',
      );
    });

    test('returns empty string for unrelated URL', () {
      expect(extractWorkIdFromUrl('https://example.com/foo'), '');
    });
  });
}

Future<void> _runFixture(String name, {required String contentType}) async {
  final File fixture = File('test/fixtures/kakuyomu/rss/$name');
  final File golden =
      File('test/fixtures/kakuyomu/rss/${name.replaceAll('.xml', '.golden.json')}');

  final List<KakuyomuFeedItem> items = parseFeedBody(
    await fixture.readAsString(),
    contentType: contentType,
  );
  final String serialized = const JsonEncoder.withIndent('  ').convert(
    items.map((KakuyomuFeedItem i) => i.toJson()).toList(growable: false),
  );

  if (Platform.environment['KAKUYOMU_UPDATE_GOLDENS'] == '1' ||
      !golden.existsSync()) {
    await golden.writeAsString('$serialized\n');
  }
  final String expected = await golden.readAsString();
  expect(serialized, expected.trimRight());
}

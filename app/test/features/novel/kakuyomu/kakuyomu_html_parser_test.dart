import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/novel_kakuyomu/data/kakuyomu_html_parser.dart';
import 'package:geekplayer/features/novel_kakuyomu/domain/exceptions.dart';
import 'package:geekplayer/features/novel_kakuyomu/domain/kakuyomu_episode.dart';
import 'package:geekplayer/features/novel_kakuyomu/domain/kakuyomu_work.dart';

/// Snapshot tests for `KakuyomuHtmlParser`.
///
/// Set `KAKUYOMU_UPDATE_GOLDENS=1` to regenerate golden JSON when the
/// parser intentionally changes shape.
void main() {
  const KakuyomuHtmlParser parser = KakuyomuHtmlParser();

  group('parseWorkPage', () {
    for (int i = 1; i <= 5; i++) {
      final String name = 'work_${i.toString().padLeft(3, '0')}';
      final String workId = '${i}000000000000000000$i';
      test('$name.html — golden parity', () async {
        final File f = File('test/fixtures/kakuyomu/html/$name.html');
        final KakuyomuWorkDetail detail = parser.parseWorkPage(
          await f.readAsString(),
          workId: workId,
        );
        await _check(name, detail.toJson());
        expect(detail.id, workId);
        expect(detail.title, isNotEmpty);
        expect(detail.author, isNotEmpty);
        expect(detail.episodes, isNotEmpty);
      });
    }

    test('missing title triggers KakuyomuParseException with selector', () {
      const String broken = '<html><body><div>no title</div></body></html>';
      expect(
        () => parser.parseWorkPage(broken, workId: 'X'),
        throwsA(
          isA<KakuyomuParseException>().having(
            (KakuyomuParseException e) => e.selector,
            'selector',
            contains('workTitle'),
          ),
        ),
      );
    });
  });

  group('parseEpisodePage', () {
    for (int i = 1; i <= 5; i++) {
      final String name = 'episode_${i.toString().padLeft(3, '0')}';
      test('$name.html — golden parity', () async {
        final File f = File('test/fixtures/kakuyomu/html/$name.html');
        final KakuyomuEpisodeBody body = parser.parseEpisodePage(
          await f.readAsString(),
          workId: '0',
          episodeId: '$i',
        );
        await _check(name, body.toJson());
        expect(body.id, '$i');
        expect(body.title, isNotEmpty);
        expect(body.paragraphs, isNotEmpty);
      });
    }

    test('episode without body container throws KakuyomuParseException', () {
      const String broken =
          '<html><body><h1 id="workTitle">t</h1></body></html>';
      expect(
        () => parser.parseEpisodePage(broken, workId: 'W', episodeId: 'E'),
        throwsA(
          isA<KakuyomuParseException>().having(
            (KakuyomuParseException e) => e.selector,
            'selector',
            contains('widget-episodeBody'),
          ),
        ),
      );
    });
  });
}

Future<void> _check(String name, Map<String, dynamic> actual) async {
  final File golden = File('test/fixtures/kakuyomu/html/$name.golden.json');
  final String serialized = const JsonEncoder.withIndent('  ').convert(actual);
  if (Platform.environment['KAKUYOMU_UPDATE_GOLDENS'] == '1' ||
      !golden.existsSync()) {
    await golden.writeAsString('$serialized\n');
  }
  final String expected = await golden.readAsString();
  expect(
    serialized,
    expected.trimRight(),
    reason:
        'Golden mismatch for $name (set KAKUYOMU_UPDATE_GOLDENS=1 to refresh)',
  );
}

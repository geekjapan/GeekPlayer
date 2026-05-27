import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/about/data/build_info.dart';

void main() {
  group('formattedGitSha', () {
    test('passes through a real SHA', () {
      expect(formattedGitSha('abc1234'), 'abc1234');
    });

    test('maps "unknown" to "(dev build)"', () {
      expect(formattedGitSha('unknown'), '(dev build)');
    });

    test('maps empty string to "(dev build)"', () {
      expect(formattedGitSha(''), '(dev build)');
    });

    test('default arg comes from kGitSha (dart-define)', () {
      // In tests we never pass --dart-define=GIT_SHA, so kGitSha is
      // "unknown" and the default-arg version of formattedGitSha must
      // therefore return "(dev build)".
      expect(kGitSha, 'unknown');
      expect(formattedGitSha(), '(dev build)');
    });
  });
}

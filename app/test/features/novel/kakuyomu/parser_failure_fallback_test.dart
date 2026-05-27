import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/novel_kakuyomu/domain/exceptions.dart';
import 'package:geekplayer/features/novel_kakuyomu/presentation/parser_failure_fallback.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group('buildDiagnostic', () {
    test('contains selector, URL, version, os and nothing else', () {
      final KakuyomuParseException ex = KakuyomuParseException(
        message: 'no body',
        selector: '.widget-episodeBody',
        url: 'https://kakuyomu.jp/works/A/episodes/B',
      );
      final String diag = buildDiagnostic(
        error: ex,
        requestUrl: 'https://kakuyomu.jp/works/A/episodes/B',
        appVersion: '1.2.3',
        osNameOverride: 'linux',
      );
      expect(diag, contains('.widget-episodeBody'));
      expect(diag, contains('https://kakuyomu.jp/works/A/episodes/B'));
      expect(diag, contains('1.2.3'));
      expect(diag, contains('linux'));
      // MUST NOT include privacy-sensitive bits.
      expect(diag, isNot(contains('192.168.')));
      expect(diag, isNot(contains('Cookie')));
      expect(diag, isNot(contains('<html')));
    });
  });

  group('ParserFailureFallback widget', () {
    testWidgets('tapping 公式ビューアで開く invokes the launcher', (
      WidgetTester tester,
    ) async {
      Uri? launched;
      LaunchMode? capturedMode;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParserFailureFallback(
              error: KakuyomuParseException(
                message: 'x',
                selector: 's',
                url: 'u',
              ),
              url: 'https://kakuyomu.jp/works/A/episodes/B',
              launchUrlOverride:
                  (
                    Uri u, {
                    LaunchMode mode = LaunchMode.platformDefault,
                  }) async {
                    launched = u;
                    capturedMode = mode;
                    return true;
                  },
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('kakuyomu-open-external')));
      await tester.pump();
      expect(launched, Uri.parse('https://kakuyomu.jp/works/A/episodes/B'));
      expect(capturedMode, LaunchMode.externalApplication);
    });
  });
}

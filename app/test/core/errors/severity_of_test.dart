import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/app_error.dart';
import 'package:geekplayer/core/errors/error_banner.dart';

void main() {
  group('severityOf classifies every variant deterministically', () {
    final cases = <(AppError, ErrorSeverity)>[
      (const NetworkUnreachableError(message: 'm'), ErrorSeverity.warning),
      (const RateLimitError(message: 'm'), ErrorSeverity.warning),
      (
        const SiteConsentRequiredError(message: 'm', site: 'kakuyomu'),
        ErrorSeverity.warning,
      ),
      (const HtmlParseError(message: 'm'), ErrorSeverity.warning),
      (const UpstreamUnavailableError(message: 'm'), ErrorSeverity.warning),
      (
        const RobotsDisallowedError(message: 'm', path: '/x'),
        ErrorSeverity.error,
      ),
      (
        FileNotFoundError(message: 'm', uri: Uri.parse('file:///x')),
        ErrorSeverity.error,
      ),
      (const UnsupportedFormatError(message: 'm'), ErrorSeverity.error),
      (const StorageQuotaError(message: 'm'), ErrorSeverity.error),
      (UnknownError(const FormatException('x')), ErrorSeverity.error),
    ];

    for (final (error, expected) in cases) {
      test('${error.runtimeType} -> $expected', () {
        expect(severityOf(error), expected);
      });
    }

    test('all ten variants are covered exactly once', () {
      expect(cases.length, 10);
      expect(
        cases.map((c) => c.$1.runtimeType).toSet().length,
        10,
        reason: 'each variant must appear exactly once in the severity table',
      );
    });
  });
}

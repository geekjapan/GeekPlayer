import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/app_error.dart';
import 'package:geekplayer/core/errors/error_messages.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

/// Pumps a minimal widget tree that installs [AppLocalizations] (ja) so that
/// `ErrorMessages.localize` resolves against the generated delegate.
Future<String> _localize(WidgetTester tester, AppError error) async {
  String? result;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ja'),
      home: Builder(
        builder: (context) {
          result = ErrorMessages.localize(error, context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return result!;
}

void main() {
  final variants = <AppError>[
    const NetworkUnreachableError(message: 'fallback offline'),
    const RateLimitError(
      message: 'fallback rate',
      retryAfter: Duration(seconds: 30),
    ),
    const SiteConsentRequiredError(message: 'fallback consent', site: 'kakuyomu'),
    const RobotsDisallowedError(message: 'fallback robots', path: '/x'),
    const HtmlParseError(message: 'fallback parse'),
    FileNotFoundError(message: 'fallback file', uri: Uri.parse('file:///a')),
    const UnsupportedFormatError(message: 'fallback fmt'),
    const UpstreamUnavailableError(message: 'fallback 5xx'),
    const StorageQuotaError(message: 'fallback quota'),
    UnknownError(const FormatException('fallback unknown')),
  ];

  group('localize returns non-empty ja text for every variant', () {
    for (final error in variants) {
      testWidgets('${error.runtimeType}', (tester) async {
        final text = await _localize(tester, error);
        expect(text, isNotEmpty);
        expect(text, isNot(equals(error.message)),
            reason: 'localized string should differ from the raw fallback');
      });
    }
  });

  testWidgets('RateLimitError interpolates retryAfter seconds', (tester) async {
    final text = await _localize(
      tester,
      const RateLimitError(
        message: 'raw',
        retryAfter: Duration(seconds: 30),
      ),
    );
    expect(text, contains('30'));
    expect(text, contains('秒'));
  });

  testWidgets('SiteConsentRequiredError interpolates site identifier', (
    tester,
  ) async {
    final text = await _localize(
      tester,
      const SiteConsentRequiredError(message: 'raw', site: 'kakuyomu'),
    );
    expect(text, contains('kakuyomu'));
  });

  testWidgets('detached context falls back to error.message', (tester) async {
    // A bare BuildContext without any AppLocalizations delegate above it.
    String? result;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            result = ErrorMessages.localize(
              const NetworkUnreachableError(message: 'fallback message'),
              context,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(result, 'fallback message');
  });
}

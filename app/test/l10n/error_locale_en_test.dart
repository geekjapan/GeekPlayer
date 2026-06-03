import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/app_error.dart';
import 'package:geekplayer/core/errors/error_messages.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

/// Spec `english-localization` Scenario "English locale is selected by the
/// platform": error copy resolves to English under `Locale('en')`. Mirrors
/// the existing Japanese coverage in
/// `test/core/errors/error_messages_test.dart`.
Future<String> _localize(
  WidgetTester tester,
  AppError error,
  Locale locale,
) async {
  String? result;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Builder(
        builder: (BuildContext context) {
          result = ErrorMessages.localize(error, context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return result!;
}

void main() {
  testWidgets('errors resolve to English copy under Locale(en)', (
    WidgetTester tester,
  ) async {
    expect(
      await _localize(
        tester,
        UnknownError(const FormatException('boom')),
        const Locale('en'),
      ),
      'An unexpected error occurred.',
    );
    expect(
      await _localize(
        tester,
        const UnsupportedFormatError(message: 'x'),
        const Locale('en'),
      ),
      contains('format'),
    );
  });

  testWidgets('the same errors still resolve to Japanese under Locale(ja)', (
    WidgetTester tester,
  ) async {
    expect(
      await _localize(
        tester,
        UnknownError(const FormatException('boom')),
        const Locale('ja'),
      ),
      '予期しないエラーが発生しました。',
    );
  });
}

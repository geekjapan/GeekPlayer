import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/utils/novel_date_formatter.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

Future<String> _formatWithLocale(
  WidgetTester tester,
  DateTime? date,
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
          result = formatNovelDate(date, context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return result!;
}

void main() {
  testWidgets('formats a date for the Japanese locale', (
    WidgetTester tester,
  ) async {
    final String result = await _formatWithLocale(
      tester,
      DateTime(2024, 3, 15, 12),
      const Locale('ja'),
    );

    expect(result, '2024年3月15日');
  });

  testWidgets('formats a date for the English locale', (
    WidgetTester tester,
  ) async {
    final String result = await _formatWithLocale(
      tester,
      DateTime(2024, 3, 15, 12),
      const Locale('en'),
    );

    expect(result, 'Mar 15, 2024');
  });

  testWidgets('returns localized unknown text for null input', (
    WidgetTester tester,
  ) async {
    final String result = await _formatWithLocale(
      tester,
      null,
      const Locale('ja'),
    );

    expect(result, '不明');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/theme/app_theme.dart';
import 'package:geekplayer/core/theme/tokens.dart';
import 'package:geekplayer/features/library/home_screen.dart';
import 'package:geekplayer/features/library/home_section.dart';
import 'package:geekplayer/features/library/home_section_registry.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

const _ids = ['video', 'audio', 'novel', 'book', 'manga', 'media_library'];
const _labels = ['動画へ', '音楽へ', '小説へ', '書籍へ', '漫画へ', 'ライブラリへ'];

class _Section extends HomeSection {
  const _Section(this.id);

  @override
  final String id;

  @override
  int get order => _ids.indexOf(id);

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    height: 900,
    child: Align(alignment: Alignment.topLeft, child: Text('Heading $id')),
  );
}

class _LoadingSection extends _Section {
  const _LoadingSection(this.height) : super('novel');

  final ValueNotifier<double> height;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ValueListenableBuilder(
    valueListenable: height,
    builder: (_, value, _) => SizedBox(height: value),
  );
}

Future<void> _pumpHome(
  WidgetTester tester, {
  Locale locale = const Locale('ja'),
  List<String> ids = _ids,
  List<HomeSection>? sections,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeSectionsProvider.overrideWith(
          (_) => [
            const _Section('audio.miniPlayer'),
            ...?sections,
            if (sections == null) ...ids.map(_Section.new),
          ],
        ),
        homeAppBarActionsProvider.overrideWith((_) => []),
      ],
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectHeadingVisible(WidgetTester tester, String id) {
  final viewport = tester.getRect(find.byType(ListView));
  final heading = tester.getRect(find.text('Heading $id'));
  expect(heading.top, greaterThanOrEqualTo(viewport.top));
  expect(heading.bottom, lessThanOrEqualTo(viewport.bottom));
}

void main() {
  testWidgets('shows localized accessible destinations with 48dp targets', (
    tester,
  ) async {
    await _pumpHome(tester);

    expect(find.byType(ActionChip), findsNWidgets(6));
    for (final label in _labels) {
      final chip = find.widgetWithText(ActionChip, label);
      expect(chip, findsOneWidget);
      expect(find.byTooltip(label), findsOneWidget);
      expect(tester.getSemantics(chip).label, contains(label));
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSize(chip).width,
        greaterThanOrEqualTo(AppSizes.minTouchTarget),
      );
    }
  });

  testWidgets('jumps to distant sections and back without manual scrolling', (
    tester,
  ) async {
    await _pumpHome(tester);
    for (final index in [5, 0, 4, 1, 3, 2]) {
      await tester.tap(find.widgetWithText(ActionChip, _labels[index]));
      await tester.pumpAndSettle();
      _expectHeadingVisible(tester, _ids[index]);
    }
  });

  testWidgets(
    'keyboard reaches and activates every destination on narrow view',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpHome(tester);

      for (final id in _ids) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        _expectHeadingVisible(tester, id);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uses registry order and only shows registered destinations', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      locale: const Locale('en'),
      ids: ['manga', 'video'],
    );
    final labels = tester
        .widgetList<ActionChip>(find.byType(ActionChip))
        .map((chip) => (chip.label as Text).data);
    expect(labels, ['Comics', 'Video']);
  });

  testWidgets(
    'keeps the destination visible when earlier content finishes loading',
    (tester) async {
      final height = ValueNotifier<double>(40);
      addTearDown(height.dispose);
      await _pumpHome(
        tester,
        sections: [
          _LoadingSection(height),
          const _Section('book'),
          const _Section('manga'),
        ],
      );
      await tester.tap(find.widgetWithText(ActionChip, '書籍へ'));
      await tester.pumpAndSettle();
      height.value = 2400;
      await tester.pumpAndSettle();
      _expectHeadingVisible(tester, 'book');
    },
  );

  for (final input in ['drag', 'PageDown']) {
    testWidgets('stops tracking the destination after user $input scrolling', (
      tester,
    ) async {
      final height = ValueNotifier<double>(40);
      addTearDown(height.dispose);
      await _pumpHome(
        tester,
        sections: [
          _LoadingSection(height),
          const _Section('book'),
          const _Section('manga'),
        ],
      );
      await tester.tap(find.widgetWithText(ActionChip, '書籍へ'));
      await tester.pumpAndSettle();
      if (input == 'drag') {
        await tester.drag(find.byType(ListView), const Offset(0, -200));
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      }
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(find.text('Heading book')).dy;
      expect(top, lessThan(tester.getRect(find.byType(ListView)).top));
      height.value += 40;
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Heading book')).dy,
        closeTo(top + 40, 0.1),
      );
    });
  }
}

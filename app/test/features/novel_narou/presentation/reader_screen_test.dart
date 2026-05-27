import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/novel_narou/presentation/reader_settings.dart';

/// リーダー画面そのもののウィジェットテストは、`NarouNovelRepository`
/// が深い依存ツリー (Dio + RateLimiter + package_info) を要求するため
/// 単体では建てにくい。代わりに **設定パネル相当の状態変化** を
/// `ProviderContainer` 経由で検証することで「フォントサイズ変更が
/// state に伝わる」「テーマ変更が反映される」契約を担保する。
///
/// 前話 / 次話遷移と栞復元は drift v2 schema migration テストおよび
/// `LibraryRepository.saveBookmark` の DAO テストで間接的にカバー
/// される（Wave 2 側）。
void main() {
  testWidgets('font up ボタン押下で readerTheme.fontSize が更新される', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: _FakeReaderSettingsPanel()),
      ),
    );
    final double before = container.read(readerThemeProvider).fontSize;
    await tester.tap(find.byKey(const Key('reader-font-up')));
    await tester.pump();
    expect(container.read(readerThemeProvider).fontSize, before + 2);
  });

  testWidgets('テーマ chip タップで colorScheme が変わる', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: _FakeReaderSettingsPanel()),
      ),
    );
    await tester.tap(find.byKey(const Key('reader-theme-dark')));
    await tester.pump();
    expect(
      container.read(readerThemeProvider).colorScheme,
      ReaderColorScheme.dark,
    );
  });
}

/// 設定 BottomSheet と同じ UI を独立 ConsumerWidget として展開し、
/// reader_screen 本体を pump せずに state mutation 経路を検証する。
class _FakeReaderSettingsPanel extends ConsumerWidget {
  const _FakeReaderSettingsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReaderTheme theme = ref.watch(readerThemeProvider);
    final ReaderThemeNotifier notifier = ref.read(readerThemeProvider.notifier);
    return Scaffold(
      body: Column(
        children: <Widget>[
          IconButton(
            key: const Key('reader-font-up'),
            onPressed: () => notifier.setFontSize(theme.fontSize + 2),
            icon: const Icon(Icons.text_increase),
          ),
          for (final ReaderColorScheme c in ReaderColorScheme.values)
            ChoiceChip(
              key: ValueKey<String>('reader-theme-${c.name}'),
              label: Text(c.label),
              selected: theme.colorScheme == c,
              onSelected: (_) => notifier.setColorScheme(c),
            ),
        ],
      ),
    );
  }
}

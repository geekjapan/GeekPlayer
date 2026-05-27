import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/about/presentation/lgpl_notice_section.dart';

Widget _harness() {
  return const MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: LgplNoticeSection())),
  );
}

void main() {
  testWidgets('renders required LGPL strings and OS-specific paths', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Helper that searches across all SelectableText / Text widgets
    // (since SelectableText wraps the string in an internal RichText).
    Finder hasText(String snippet) {
      return find.byWidgetPredicate((Widget w) {
        if (w is Text && w.data != null) {
          return w.data!.contains(snippet);
        }
        if (w is SelectableText && w.data != null) {
          return w.data!.contains(snippet);
        }
        return false;
      });
    }

    // Spec `lgpl-compliance` Scenario "LGPL section is visible without
    // scrolling on first paint" — the key phrases must be present.
    expect(hasText('LGPL-2.1+'), findsWidgets);
    expect(hasText('動的リンク'), findsWidgets);
    // User rights statement (Requirement "User rights statement under
    // LGPL").
    expect(hasText('差し替える権利'), findsWidgets);
    expect(hasText('再構築'), findsWidgets);

    // OS-specific replacement paths.
    expect(hasText('Contents/Frameworks/'), findsWidgets);
    expect(hasText('mpv-2.dll'), findsWidgets);
    expect(hasText('lib/<abi>/libmpv.so'), findsWidgets);

    // Upstream link.
    expect(find.byKey(const Key('lgpl-upstream-link')), findsOneWidget);
    expect(hasText('上流ソース (mpv-player/mpv)'), findsWidgets);

    // THIRD_PARTY_NOTICES link.
    expect(find.byKey(const Key('lgpl-third-party-link')), findsOneWidget);

    // LGPL-2.1 full text link.
    expect(find.byKey(const Key('lgpl-full-text-link')), findsOneWidget);
    expect(hasText('LGPL-2.1 全文'), findsWidgets);
  });
}

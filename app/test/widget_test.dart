import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geekplayer/main.dart';

void main() {
  testWidgets('Hello GeekPlayer screen renders', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GeekPlayerApp()));
    expect(find.text('GeekPlayer'), findsWidgets);
    expect(find.text('Hello, GeekPlayer'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'core/errors/error_boundary.dart';
import 'core/errors/scaffold_messenger_key.dart';
import 'features/library/home_screen.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await runAppWithErrorBoundary(const ProviderScope(child: GeekPlayerApp()));
}

class GeekPlayerApp extends ConsumerWidget {
  const GeekPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messengerKey = ref.watch(scaffoldMessengerKeyProvider);
    return MaterialApp(
      title: 'GeekPlayer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      scaffoldMessengerKey: messengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ja'),
      home: const HomeScreen(),
    );
  }
}

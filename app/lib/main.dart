import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'core/errors/error_boundary.dart';
import 'core/errors/scaffold_messenger_key.dart';
import 'core/media/audio_handler.dart';
import 'core/media/audio_providers.dart';
import 'features/library/home_screen.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // Initialise audio_service once, before runApp. The resulting handler
  // is registered with the Riverpod provider so any AudioSession created
  // later in the app drives the same AudioPlayer instance.
  // NOTE: audio_service enforces `!androidNotificationOngoing ||
  // androidStopForegroundOnPause` at construction time, so the design.md
  // combination (ongoing=true + stopForeground=false) cannot be expressed
  // verbatim. We pick stopForeground=false (the music-app default — keep
  // the notification visible when paused) and let ongoing fall back to
  // false.
  final GeekPlayerAudioHandler handler = await AudioService.init(
    builder: GeekPlayerAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'dev.geekjapan.geekplayer.channel.audio',
      androidNotificationChannelName: 'GeekPlayer 音楽再生',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
    ),
  );
  setAudioHandlerInstance(handler);
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

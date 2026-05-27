import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/media/media_session.dart';
import 'package:geekplayer/core/media/models.dart';
import 'package:geekplayer/features/audio/domain/audio_queue.dart';
import 'package:geekplayer/features/audio/domain/audio_track.dart';
import 'package:geekplayer/features/audio/presentation/audio_controller_notifier.dart';
import 'package:geekplayer/features/audio/presentation/player_screen.dart';
import 'package:just_audio/just_audio.dart' as ja;

class _StubAudioController extends AudioController {
  _StubAudioController(this._initial);
  final AudioControllerState? _initial;

  @override
  AudioControllerState? build() => _initial;
}

AudioSession _stubSession() => AudioSession.fromStreams(
  position: const Stream<Duration>.empty(),
  bufferedPosition: const Stream<Duration>.empty(),
  duration: const Stream<Duration?>.empty(),
  playerState: const Stream<ja.PlayerState>.empty(),
);

AudioTrack _track() => AudioTrack(
  uri: Uri.file('/music/Hoge.mp3'),
  displayName: 'Hoge.mp3',
  metadata: const AudioMetadata(title: 'Hoge', artist: 'Fuga', album: 'Piyo'),
);

void main() {
  testWidgets(
    'AudioPlayerScreen renders title / artist / album + transport controls',
    (WidgetTester tester) async {
      final AudioSession session = _stubSession();
      addTearDown(session.dispose);
      final AudioControllerState state = AudioControllerState(
        session: session,
        queue: AudioQueue(tracks: <AudioTrack>[_track()]),
        playState: const MediaPlayState.playing(),
        duration: const Duration(minutes: 3),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioControllerProvider.overrideWith(
              () => _StubAudioController(state),
            ),
          ],
          child: const MaterialApp(home: AudioPlayerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Title appears in AppBar and body.
      expect(find.text('Hoge'), findsWidgets);
      expect(find.text('Fuga'), findsOneWidget);
      expect(find.text('Piyo'), findsOneWidget);
      // Transport row.
      expect(find.byIcon(Icons.pause_circle), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      // Speed button shows default 1.0x.
      expect(find.text('1.0x'), findsOneWidget);
      // Shuffle + repeat icons.
      expect(find.byIcon(Icons.shuffle), findsOneWidget);
      expect(find.byIcon(Icons.repeat), findsOneWidget);
    },
  );

  testWidgets(
    'AudioPlayerScreen empty state shows placeholder when no current track',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AudioPlayerScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.text('再生中の曲がありません'), findsOneWidget);
    },
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/media/media_session.dart';
import 'package:geekplayer/core/media/models.dart';
import 'package:geekplayer/features/audio/domain/audio_queue.dart';
import 'package:geekplayer/features/audio/domain/audio_track.dart';
import 'package:geekplayer/features/audio/presentation/audio_controller_notifier.dart';
import 'package:geekplayer/features/audio/presentation/mini_player.dart';
import 'package:just_audio/just_audio.dart' as ja;

class _StubAudioController extends AudioController {
  _StubAudioController(this._initial);
  final AudioControllerState? _initial;

  @override
  AudioControllerState? build() => _initial;
}

AudioSession _stubSession() {
  return AudioSession.fromStreams(
    position: const Stream<Duration>.empty(),
    bufferedPosition: const Stream<Duration>.empty(),
    duration: const Stream<Duration?>.empty(),
    playerState: const Stream<ja.PlayerState>.empty(),
  );
}

AudioTrack _track() =>
    AudioTrack(uri: Uri.file('/music/sample.mp3'), displayName: 'sample.mp3');

void main() {
  testWidgets('MiniPlayer is hidden when state is null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: MiniPlayer())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.music_note), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('MiniPlayer renders title + play icon when playing', (
    WidgetTester tester,
  ) async {
    final AudioSession session = _stubSession();
    addTearDown(session.dispose);
    final AudioControllerState state = AudioControllerState(
      session: session,
      queue: AudioQueue(tracks: <AudioTrack>[_track()]),
      playState: const MediaPlayState.playing(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioControllerProvider.overrideWith(
            () => _StubAudioController(state),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MiniPlayer())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('sample'), findsOneWidget); // effectiveTitle drops .mp3
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('MiniPlayer shows play icon when paused', (
    WidgetTester tester,
  ) async {
    final AudioSession session = _stubSession();
    addTearDown(session.dispose);
    final AudioControllerState state = AudioControllerState(
      session: session,
      queue: AudioQueue(tracks: <AudioTrack>[_track()]),
      playState: const MediaPlayState.paused(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioControllerProvider.overrideWith(
            () => _StubAudioController(state),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MiniPlayer())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);
  });

  testWidgets('MiniPlayer is hidden when playState is idle', (
    WidgetTester tester,
  ) async {
    final AudioSession session = _stubSession();
    addTearDown(session.dispose);
    final AudioControllerState state = AudioControllerState(
      session: session,
      queue: AudioQueue(tracks: <AudioTrack>[_track()]),
      playState: const MediaPlayState.idle(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioControllerProvider.overrideWith(
            () => _StubAudioController(state),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MiniPlayer())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
  });
}

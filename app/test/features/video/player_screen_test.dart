import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geekplayer/core/media/media_session.dart';
import 'package:geekplayer/features/video/domain/video_file.dart';
import 'package:geekplayer/features/video/presentation/player_screen.dart';
import 'package:geekplayer/features/video/presentation/video_controller_notifier.dart';

void main() {
  testWidgets(
    'PlayerScreen renders overlay with file name when session loads',
    (WidgetTester tester) async {
      final VideoFile file = VideoFile(
        uri: Uri.parse('file:///fixture.mp4'),
        displayName: 'fixture.mp4',
      );

      // Streams-only session: no media_kit Player required, no platform
      // channel work — the widget renders the overlay around a blank
      // ColoredBox where the Video surface would normally be.
      final VideoSession session = VideoSession.fromStreams(
        position: const Stream<Duration>.empty(),
        buffer: const Stream<Duration>.empty(),
        duration: const Stream<Duration>.empty(),
        playing: const Stream<bool>.empty(),
        completed: const Stream<bool>.empty(),
      );
      addTearDown(session.dispose);
      final VideoControllerState state = VideoControllerState(
        session: session,
        file: file,
        initialStart: Duration.zero,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoControllerProvider(
              file,
            ).overrideWith(() => _StubVideoControllerNotifier(state)),
          ],
          child: MaterialApp(home: PlayerScreen(file: file)),
        ),
      );
      // First pump shows loading; pump again after the override builds.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('fixture.mp4'), findsOneWidget);
      // Speed defaults to 1.0x and is shown in the bottom bar.
      expect(find.text('1.0x'), findsOneWidget);
    },
  );
}

class _StubVideoControllerNotifier extends VideoControllerNotifier {
  _StubVideoControllerNotifier(this._state);
  final VideoControllerState _state;

  @override
  Future<VideoControllerState> build(VideoFile file) async => _state;
}

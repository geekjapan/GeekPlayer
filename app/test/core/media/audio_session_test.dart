import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/media/media_session.dart';
import 'package:geekplayer/core/media/models.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  group('AudioSession (streams-only test seam)', () {
    late StreamController<Duration> position;
    late StreamController<Duration> bufferedPosition;
    late StreamController<Duration?> duration;
    late StreamController<PlayerState> playerState;
    late AudioSession session;

    setUp(() {
      position = StreamController<Duration>.broadcast();
      bufferedPosition = StreamController<Duration>.broadcast();
      duration = StreamController<Duration?>.broadcast();
      playerState = StreamController<PlayerState>.broadcast();
      session = AudioSession.fromStreams(
        position: position.stream,
        bufferedPosition: bufferedPosition.stream,
        duration: duration.stream,
        playerState: playerState.stream,
      );
    });

    tearDown(() async {
      await session.dispose();
      await position.close();
      await bufferedPosition.close();
      await duration.close();
      await playerState.close();
    });

    test(
      'positionStream emits transformed MediaPosition on engine event',
      () async {
        final Future<MediaPosition> first = session.positionStream.first;
        position.add(const Duration(seconds: 7));
        final MediaPosition p = await first;
        expect(p.position, const Duration(seconds: 7));
      },
    );

    test('durationStream forwards null then a non-null duration', () async {
      final List<Duration?> received = <Duration?>[];
      final StreamSubscription<Duration?> sub = session.durationStream.listen(
        received.add,
      );
      duration.add(null);
      duration.add(const Duration(minutes: 3, seconds: 30));
      await Future<void>.delayed(Duration.zero);
      expect(received, <Duration?>[
        null,
        const Duration(minutes: 3, seconds: 30),
      ]);
      await sub.cancel();
    });

    test(
      'playStateStream maps just_audio ProcessingState transitions',
      () async {
        final List<MediaPlayState> states = <MediaPlayState>[];
        final StreamSubscription<MediaPlayState> sub = session.playStateStream
            .listen(states.add);
        playerState.add(PlayerState(false, ProcessingState.idle));
        playerState.add(PlayerState(false, ProcessingState.loading));
        playerState.add(PlayerState(true, ProcessingState.ready));
        playerState.add(PlayerState(false, ProcessingState.ready));
        playerState.add(PlayerState(false, ProcessingState.completed));
        await Future<void>.delayed(Duration.zero);
        expect(states, <MediaPlayState>[
          const MediaPlayState.idle(),
          const MediaPlayState.loading(),
          const MediaPlayState.playing(),
          const MediaPlayState.paused(),
          const MediaPlayState.ended(),
        ]);
        await sub.cancel();
      },
    );

    test(
      'setSpeed updates the speed accessor even in streams-only mode',
      () async {
        expect(session.speed, MediaSpeed.normal);
        await session.setSpeed(MediaSpeed.x1_5);
        expect(session.speed.value, 1.5);
      },
    );

    test('dispose closes streams and second dispose is a no-op', () async {
      await session.dispose();
      // Subsequent commands throw — matches MediaSession contract.
      expect(session.play, throwsStateError);
      // Calling dispose again does not throw.
      await session.dispose();
    });

    test(
      'AudioSession is a valid MediaSession variant (exhaustive switch)',
      () {
        // This test exists primarily to keep the switch site honest: if
        // a new variant is added without updating this list the
        // analyzer flags `non_exhaustive_switch_expression` here.
        final MediaSession s = session;
        final String label = switch (s) {
          AudioSession() => 'audio',
          VideoSession() => 'video',
          PageSession() => 'page',
        };
        expect(label, 'audio');
      },
    );
  });
}

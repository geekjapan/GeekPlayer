import 'dart:math' show Random;

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/audio/domain/audio_queue.dart';
import 'package:geekplayer/features/audio/domain/audio_track.dart';

AudioTrack _t(String name) =>
    AudioTrack(uri: Uri.file('/music/$name.mp3'), displayName: '$name.mp3');

void main() {
  group('AudioQueue', () {
    final AudioTrack a = _t('A');
    final AudioTrack b = _t('B');
    final AudioTrack c = _t('C');

    test('current returns null on empty queue', () {
      expect(AudioQueue.empty.current, isNull);
      expect(AudioQueue.empty.skipNext(), isNull);
    });

    test('skipNext advances by one in default order', () {
      final AudioQueue q = AudioQueue(tracks: <AudioTrack>[a, b, c]);
      final AudioQueue? next = q.skipNext();
      expect(next?.current, b);
      expect(next?.currentIndex, 1);
    });

    test('skipNext at tail returns null when repeat=none', () {
      final AudioQueue q = AudioQueue(
        tracks: <AudioTrack>[a, b, c],
        currentIndex: 2,
      );
      expect(q.skipNext(), isNull);
    });

    test('skipNext at tail wraps to head when repeat=all', () {
      final AudioQueue q = AudioQueue(
        tracks: <AudioTrack>[a, b, c],
        currentIndex: 2,
        repeat: RepeatMode.all,
      );
      final AudioQueue? next = q.skipNext();
      expect(next?.current, a);
    });

    test('skipNext is a self-return when repeat=one', () {
      final AudioQueue q = AudioQueue(
        tracks: <AudioTrack>[a, b, c],
        currentIndex: 1,
        repeat: RepeatMode.one,
      );
      // Stays on the same track — the caller seeks to position 0.
      expect(q.skipNext()?.current, b);
    });

    test('skipPrevious from head is a no-op (caller seeks to 0)', () {
      final AudioQueue q = AudioQueue(
        tracks: <AudioTrack>[a, b, c],
        currentIndex: 0,
      );
      expect(q.skipPrevious().currentIndex, 0);
    });

    test('skipPrevious steps back one', () {
      final AudioQueue q = AudioQueue(
        tracks: <AudioTrack>[a, b, c],
        currentIndex: 2,
      );
      expect(q.skipPrevious().current, b);
    });

    test('toggleShuffle pins the current track and shuffles the rest', () {
      // 5 tracks, current = third (index 2). After enabling shuffle the
      // 3rd track must remain the current track; the other 4 may end
      // up in any order — we only assert the "current pinned" property
      // because the rest is random.
      final List<AudioTrack> five = <AudioTrack>[
        _t('a'),
        _t('b'),
        _t('c'),
        _t('d'),
        _t('e'),
      ];
      final AudioQueue q = AudioQueue(
        tracks: five,
        currentIndex: 2,
      );
      final AudioQueue shuffled = q.toggleShuffle(random: Random(42));
      expect(shuffled.shuffle, isTrue);
      expect(shuffled.current, five[2]);
      // The logical position of the current track is 0 after shuffle.
      expect(shuffled.shuffledOrder.first, 2);
      // No duplicates and no missing indices.
      expect(shuffled.shuffledOrder.toSet(), <int>{0, 1, 2, 3, 4});
      // Toggling off restores natural order.
      final AudioQueue restored = shuffled.toggleShuffle(random: Random(42));
      expect(restored.shuffle, isFalse);
      expect(restored.shuffledOrder, <int>[0, 1, 2, 3, 4]);
    });

    test('cycleRepeat moves none → all → one → none', () {
      AudioQueue q = AudioQueue(tracks: <AudioTrack>[a]);
      expect(q.repeat, RepeatMode.none);
      q = q.cycleRepeat();
      expect(q.repeat, RepeatMode.all);
      q = q.cycleRepeat();
      expect(q.repeat, RepeatMode.one);
      q = q.cycleRepeat();
      expect(q.repeat, RepeatMode.none);
    });

    test('withCurrentMetadata patches only the current track', () {
      final AudioQueue q = AudioQueue(
        tracks: <AudioTrack>[a, b],
        currentIndex: 1,
      );
      final AudioQueue updated = q.withCurrentMetadata(
        const AudioMetadata(title: 'B-title'),
      );
      expect(updated.tracks[0], a);
      expect(updated.tracks[1].metadata?.title, 'B-title');
    });
  });
}

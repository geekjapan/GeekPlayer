import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/models.dart';
import '../domain/audio_queue.dart';
import '../domain/audio_track.dart';
import 'audio_controller_notifier.dart';

/// Full-screen audio player. Subscribes to [AudioController] for state
/// and pushes commands back through the same notifier.
class AudioPlayerScreen extends ConsumerWidget {
  const AudioPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AudioControllerState? state = ref.watch(audioControllerProvider);
    if (state == null || state.currentTrack == null) {
      return const Scaffold(body: Center(child: Text('再生中の曲がありません')));
    }
    return Scaffold(
      appBar: AppBar(title: Text(state.currentTrack!.effectiveTitle)),
      body: SafeArea(child: _Body(state: state)),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});
  final AudioControllerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = state.currentTrack!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: _Artwork(metadata: track.metadata),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            track.effectiveTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            track.effectiveArtist,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (track.effectiveAlbum.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              track.effectiveAlbum,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
          const SizedBox(height: 16),
          _SeekBar(state: state),
          const SizedBox(height: 8),
          _TransportRow(state: state),
          const SizedBox(height: 8),
          _SecondaryRow(state: state),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.metadata});
  final AudioMetadata? metadata;

  @override
  Widget build(BuildContext context) {
    final bytes = metadata?.artworkBytes;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, fit: BoxFit.cover),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: Icon(Icons.music_note, size: 96)),
    );
  }
}

class _SeekBar extends ConsumerWidget {
  const _SeekBar({required this.state});
  final AudioControllerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Duration total = state.duration ?? Duration.zero;
    final double max = total.inMilliseconds.toDouble();
    final double value = max > 0
        ? state.position.inMilliseconds.clamp(0, max.toInt()).toDouble()
        : 0;
    return Row(
      children: <Widget>[
        Text(_format(state.position)),
        Expanded(
          child: Slider(
            min: 0,
            max: max > 0 ? max : 1,
            value: value,
            onChanged: max > 0
                ? (double v) => ref
                      .read(audioControllerProvider.notifier)
                      .seek(Duration(milliseconds: v.toInt()))
                : null,
          ),
        ),
        Text(_format(total)),
      ],
    );
  }

  static String _format(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(m)}:${two(s)}';
  }
}

class _TransportRow extends ConsumerWidget {
  const _TransportRow({required this.state});
  final AudioControllerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AudioController notifier = ref.read(audioControllerProvider.notifier);
    final bool playing = state.playState.isPlaying;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton(
          tooltip: '前へ',
          icon: const Icon(Icons.skip_previous),
          iconSize: 36,
          onPressed: notifier.skipPrevious,
        ),
        IconButton(
          tooltip: playing ? '一時停止' : '再生',
          icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
          iconSize: 64,
          onPressed: notifier.togglePlayPause,
        ),
        IconButton(
          tooltip: '次へ',
          icon: const Icon(Icons.skip_next),
          iconSize: 36,
          onPressed: notifier.skipNext,
        ),
      ],
    );
  }
}

class _SecondaryRow extends ConsumerWidget {
  const _SecondaryRow({required this.state});
  final AudioControllerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AudioController notifier = ref.read(audioControllerProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton(
          tooltip: 'シャッフル',
          icon: Icon(
            Icons.shuffle,
            color: state.queue.shuffle
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          onPressed: notifier.toggleShuffle,
        ),
        _SpeedButton(
          current: state.session.speed,
          onChanged: notifier.setSpeed,
        ),
        IconButton(
          tooltip: 'リピート: ${_repeatLabel(state.queue.repeat)}',
          icon: Icon(
            _repeatIcon(state.queue.repeat),
            color: state.queue.repeat == RepeatMode.none
                ? null
                : Theme.of(context).colorScheme.primary,
          ),
          onPressed: notifier.cycleRepeat,
        ),
      ],
    );
  }

  static IconData _repeatIcon(RepeatMode m) => switch (m) {
    RepeatMode.none => Icons.repeat,
    RepeatMode.all => Icons.repeat_on,
    RepeatMode.one => Icons.repeat_one_on,
  };

  static String _repeatLabel(RepeatMode m) => switch (m) {
    RepeatMode.none => 'なし',
    RepeatMode.all => '全曲',
    RepeatMode.one => '1曲',
  };
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.current, required this.onChanged});

  final MediaSpeed current;
  final ValueChanged<MediaSpeed> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MediaSpeed>(
      tooltip: '再生速度',
      initialValue: current,
      onSelected: onChanged,
      itemBuilder: (BuildContext context) => MediaSpeed.presets
          .map(
            (MediaSpeed s) =>
                PopupMenuItem<MediaSpeed>(value: s, child: Text('${s.value}x')),
          )
          .toList(growable: false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text('${current.value}x'),
      ),
    );
  }
}

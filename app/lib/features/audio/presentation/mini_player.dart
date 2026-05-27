import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/audio_track.dart';
import 'audio_controller_notifier.dart';
import 'player_screen.dart';

/// Sticky bottom mini player. Hidden when no [AudioSession] exists or
/// the session is idle (D7 / spec L2 R "Mini player on the home screen").
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AudioControllerState? state = ref.watch(audioControllerProvider);
    if (state == null) return const SizedBox.shrink();
    if (state.playState.isIdle) return const SizedBox.shrink();
    final track = state.currentTrack;
    if (track == null) return const SizedBox.shrink();
    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => _openFullScreen(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 44,
                height: 44,
                child: _Artwork(metadata: track.metadata),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      track.effectiveTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      track.effectiveArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: state.playState.isPlaying ? '一時停止' : '再生',
                icon: Icon(
                  state.playState.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: ref
                    .read(audioControllerProvider.notifier)
                    .togglePlayPause,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AudioPlayerScreen()));
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
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(bytes, fit: BoxFit.cover),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(child: Icon(Icons.music_note)),
    );
  }
}

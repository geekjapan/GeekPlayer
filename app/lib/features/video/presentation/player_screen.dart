import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/media/media_session.dart';
import '../../../core/media/models.dart';
import '../domain/play_video_use_case.dart';
import '../domain/video_file.dart';
import 'video_controller_notifier.dart';

/// Full-screen video player. Loads via [VideoControllerNotifier] (which
/// owns the [VideoSession]) and renders the libmpv surface with an
/// auto-hiding control overlay.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({required this.file, super.key});

  final VideoFile file;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _overlayVisible = true;
  Timer? _hideTimer;

  static const Duration _autoHideAfter = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_autoHideAfter, () {
      if (mounted) setState(() => _overlayVisible = false);
    });
  }

  void _toggleOverlay() {
    setState(() => _overlayVisible = !_overlayVisible);
    if (_overlayVisible) _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<VideoControllerState> async = ref.watch(
      videoControllerProvider(widget.file),
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (Object e, StackTrace st) => _ErrorView(error: e),
        data: (VideoControllerState s) => _PlayerBody(
          state: s,
          overlayVisible: _overlayVisible,
          onSurfaceTap: _toggleOverlay,
          onUserInteraction: _scheduleHide,
        ),
      ),
    );
  }
}

class _PlayerBody extends ConsumerWidget {
  const _PlayerBody({
    required this.state,
    required this.overlayVisible,
    required this.onSurfaceTap,
    required this.onUserInteraction,
  });

  final VideoControllerState state;
  final bool overlayVisible;
  final VoidCallback onSurfaceTap;
  final VoidCallback onUserInteraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VideoSession session = state.session;
    final VideoController? controller = session.videoController;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSurfaceTap,
          child: controller == null
              ? const ColoredBox(color: Colors.black)
              : Video(controller: controller),
        ),
        AnimatedOpacity(
          opacity: overlayVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !overlayVisible,
            child: _OverlayControls(
              state: state,
              onUserInteraction: onUserInteraction,
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayControls extends ConsumerStatefulWidget {
  const _OverlayControls({
    required this.state,
    required this.onUserInteraction,
  });

  final VideoControllerState state;
  final VoidCallback onUserInteraction;

  @override
  ConsumerState<_OverlayControls> createState() => _OverlayControlsState();
}

class _OverlayControlsState extends ConsumerState<_OverlayControls> {
  MediaPlayState _lastPlayState = const MediaPlayState.loading();
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _subtitleOn = false;
  bool _durationRuleApplied = false;

  @override
  void initState() {
    super.initState();
    final VideoSession s = widget.state.session;
    s.playStateStream.listen((MediaPlayState ps) {
      if (mounted) setState(() => _lastPlayState = ps);
    });
    s.positionStream.listen((MediaPosition mp) {
      if (mounted) setState(() => _position = mp.position);
    });
    s.durationStream.listen((Duration? d) async {
      if (!mounted) return;
      setState(() => _duration = d);
      if (!_durationRuleApplied && d != null) {
        _durationRuleApplied = true;
        final Duration adjusted = PlayVideoUseCase.applyEndOfPlaybackRule(
          widget.state.initialStart,
          d,
        );
        if (adjusted == Duration.zero &&
            widget.state.initialStart > Duration.zero) {
          await s.seek(Duration.zero);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const <double>[0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _TopBar(file: widget.state.file),
            const Spacer(),
            _BottomBar(
              playState: _lastPlayState,
              position: _position,
              duration: _duration,
              currentSpeed: widget.state.session.speed,
              subtitleOn: _subtitleOn,
              onPlayPause: () async {
                widget.onUserInteraction();
                final VideoControllerNotifier n = ref.read(
                  videoControllerProvider(widget.state.file).notifier,
                );
                await n.togglePlayPause(_lastPlayState);
              },
              onSeek: (Duration target) async {
                widget.onUserInteraction();
                final VideoControllerNotifier n = ref.read(
                  videoControllerProvider(widget.state.file).notifier,
                );
                await n.seek(target);
              },
              onSpeed: (MediaSpeed speed) async {
                widget.onUserInteraction();
                final VideoControllerNotifier n = ref.read(
                  videoControllerProvider(widget.state.file).notifier,
                );
                await n.setSpeed(speed);
                if (mounted) setState(() {});
              },
              onSubtitleToggle: () async {
                widget.onUserInteraction();
                final VideoControllerNotifier n = ref.read(
                  videoControllerProvider(widget.state.file).notifier,
                );
                final bool now = await n.toggleSubtitle();
                if (mounted) setState(() => _subtitleOn = now);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.file});
  final VideoFile file;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: '戻る',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            file.displayName,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.playState,
    required this.position,
    required this.duration,
    required this.currentSpeed,
    required this.subtitleOn,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSpeed,
    required this.onSubtitleToggle,
  });

  final MediaPlayState playState;
  final Duration position;
  final Duration? duration;
  final MediaSpeed currentSpeed;
  final bool subtitleOn;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<MediaSpeed> onSpeed;
  final VoidCallback onSubtitleToggle;

  @override
  Widget build(BuildContext context) {
    final Duration total = duration ?? Duration.zero;
    final double max = total.inMilliseconds.toDouble();
    final double value = max > 0
        ? position.inMilliseconds.clamp(0, max.toInt()).toDouble()
        : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.white),
              ),
              Expanded(
                child: Slider(
                  min: 0,
                  max: max > 0 ? max : 1,
                  value: value,
                  onChanged: max > 0
                      ? (double v) => onSeek(Duration(milliseconds: v.toInt()))
                      : null,
                ),
              ),
              Text(
                _formatDuration(total),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                onPressed: onPlayPause,
                tooltip: playState.isPlaying ? '一時停止' : '再生',
                icon: Icon(
                  playState.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              _SpeedButton(current: currentSpeed, onChanged: onSpeed),
              IconButton(
                onPressed: onSubtitleToggle,
                tooltip: subtitleOn ? '字幕オフ' : '字幕オン',
                icon: Icon(
                  subtitleOn ? Icons.subtitles : Icons.subtitles_off,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final int h = d.inHours;
    final int m = d.inMinutes.remainder(60);
    final int s = d.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
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
        child: Text(
          '${current.value}x',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, color: Colors.white70, size: 56),
            const SizedBox(height: 16),
            const Text(
              'このファイルは再生できません',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('戻る'),
            ),
          ],
        ),
      ),
    );
  }
}

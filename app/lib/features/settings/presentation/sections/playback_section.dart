import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_settings.dart';
import '../app_settings_notifier.dart';
import '../settings_screen.dart';

/// 再生 section — default playback speed (presets only). Per spec
/// Requirement "Playback section sets default playback speed", changing
/// the value MUST NOT affect a currently playing session.
class PlaybackSection extends ConsumerWidget {
  const PlaybackSection({super.key});

  static const List<double> presets = <double>[
    0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double current = ref.watch(
      appSettingsProvider.select(
        (AsyncValue<AppSettings> s) =>
            s.value?.defaultPlaybackSpeed ?? 1.0,
      ),
    );

    return SettingsSection(
      id: 'playback',
      title: '再生',
      children: <Widget>[
        ListTile(
          key: const Key('default-playback-speed'),
          title: const Text('デフォルト再生速度'),
          subtitle: Wrap(
            spacing: 8,
            children: <Widget>[
              for (final double p in presets)
                ChoiceChip(
                  key: Key('speed-$p'),
                  label: Text('${p}x'),
                  selected: current == p,
                  onSelected: (bool sel) {
                    if (!sel) return;
                    ref.read(appSettingsProvider.notifier).mutate(
                          (AppSettings s) =>
                              s.copyWith(defaultPlaybackSpeed: p),
                        );
                  },
                ),
            ],
          ),
        ),
        const NextLaunchHelper(),
      ],
    );
  }
}

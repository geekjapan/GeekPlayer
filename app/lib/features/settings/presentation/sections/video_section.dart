import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../app_settings_notifier.dart';
import '../settings_screen.dart';

/// 動画 section — default subtitle on/off. Per spec Requirement
/// "Video section controls subtitle default", sessions already running
/// MUST NOT change their subtitle track.
class VideoSection extends ConsumerWidget {
  const VideoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool value = ref.watch(
      appSettingsProvider.select(
        (AsyncValue<AppSettings> s) => s.value?.subtitlesByDefault ?? false,
      ),
    );
    return SettingsSection(
      id: 'video',
      title: l10n.settingsSectionVideo,
      children: <Widget>[
        SwitchListTile(
          key: const Key('subtitles-by-default'),
          title: Text(l10n.settingsSubtitlesByDefault),
          value: value,
          onChanged: (bool v) {
            ref
                .read(appSettingsProvider.notifier)
                .mutate((AppSettings s) => s.copyWith(subtitlesByDefault: v));
          },
        ),
        const NextLaunchHelper(),
      ],
    );
  }
}

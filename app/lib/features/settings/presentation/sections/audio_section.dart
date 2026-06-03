import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../app_settings_notifier.dart';
import '../settings_screen.dart';

/// 音楽 section — background playback + notification persistence.
///
/// Both switches reflect immediately per spec Requirement "Audio section
/// controls background and notification". Wiring to `audio_service` API
/// re-calls is delegated to `add-local-audio-playback`'s audio notifier;
/// here we only update the AppSettings value.
class AudioSection extends ConsumerWidget {
  const AudioSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool bg = ref.watch(
      appSettingsProvider.select(
        (AsyncValue<AppSettings> s) => s.value?.audioBackgroundPlayback ?? true,
      ),
    );
    final bool notif = ref.watch(
      appSettingsProvider.select(
        (AsyncValue<AppSettings> s) =>
            s.value?.audioNotificationPersistent ?? true,
      ),
    );

    return SettingsSection(
      id: 'audio',
      title: l10n.settingsSectionAudio,
      children: <Widget>[
        SwitchListTile(
          key: const Key('audio-background-playback'),
          title: Text(l10n.settingsAudioBackgroundPlayback),
          value: bg,
          onChanged: (bool v) {
            ref
                .read(appSettingsProvider.notifier)
                .mutate(
                  (AppSettings s) => s.copyWith(audioBackgroundPlayback: v),
                );
          },
        ),
        SwitchListTile(
          key: const Key('audio-notification-persistent'),
          title: Text(l10n.settingsAudioNotificationPersistent),
          value: notif,
          onChanged: (bool v) {
            ref
                .read(appSettingsProvider.notifier)
                .mutate(
                  (AppSettings s) => s.copyWith(audioNotificationPersistent: v),
                );
          },
        ),
      ],
    );
  }
}

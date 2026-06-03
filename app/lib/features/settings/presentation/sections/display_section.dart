import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../app_settings_notifier.dart';
import '../settings_screen.dart';

/// 表示 section — spec `app-settings` Requirement "Display section
/// controls theme mode".
class DisplaySection extends ConsumerWidget {
  const DisplaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeMode mode = ref.watch(
      appSettingsProvider.select(
        (AsyncValue<AppSettings> s) => s.value?.themeMode ?? ThemeMode.system,
      ),
    );

    return SettingsSection(
      id: 'display',
      title: l10n.settingsSectionDisplay,
      children: <Widget>[
        RadioGroup<ThemeMode>(
          groupValue: mode,
          onChanged: (ThemeMode? v) {
            if (v == null) return;
            ref
                .read(appSettingsProvider.notifier)
                .mutate((AppSettings s) => s.copyWith(themeMode: v));
          },
          child: Column(
            children: <Widget>[
              for (final ThemeMode m in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  key: Key('theme-${m.name}'),
                  title: Text(_label(l10n, m)),
                  value: m,
                ),
            ],
          ),
        ),
        ListTile(
          key: const Key('accent-color-placeholder'),
          enabled: false,
          title: Text(l10n.settingsAccentColorPlaceholder),
          trailing: Chip(
            label: Text(l10n.settingsAccentColorComingSoon),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  String _label(AppLocalizations l10n, ThemeMode m) => switch (m) {
    ThemeMode.system => l10n.settingsThemeSystem,
    ThemeMode.light => l10n.settingsThemeLight,
    ThemeMode.dark => l10n.settingsThemeDark,
  };
}

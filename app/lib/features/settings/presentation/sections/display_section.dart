import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_settings.dart';
import '../app_settings_notifier.dart';
import '../settings_screen.dart';

/// 表示 section — spec `app-settings` Requirement "Display section
/// controls theme mode".
class DisplaySection extends ConsumerWidget {
  const DisplaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(
      appSettingsProvider.select(
        (AsyncValue<AppSettings> s) =>
            s.value?.themeMode ?? ThemeMode.system,
      ),
    );

    return SettingsSection(
      id: 'display',
      title: '表示',
      children: <Widget>[
        RadioGroup<ThemeMode>(
          groupValue: mode,
          onChanged: (ThemeMode? v) {
            if (v == null) return;
            ref.read(appSettingsProvider.notifier).mutate(
                  (AppSettings s) => s.copyWith(themeMode: v),
                );
          },
          child: Column(
            children: <Widget>[
              for (final ThemeMode m in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  key: Key('theme-${m.name}'),
                  title: Text(_label(m)),
                  value: m,
                ),
            ],
          ),
        ),
        const ListTile(
          key: Key('accent-color-placeholder'),
          enabled: false,
          title: Text('アクセントカラー'),
          trailing: Chip(
            label: Text('v0.2 で対応'),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  String _label(ThemeMode m) => switch (m) {
        ThemeMode.system => 'システム',
        ThemeMode.light => 'ライト',
        ThemeMode.dark => 'ダーク',
      };
}

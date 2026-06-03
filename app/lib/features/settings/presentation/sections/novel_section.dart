import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../../domain/novel_writing_mode.dart';
import '../app_settings_notifier.dart';
import '../settings_screen.dart';

/// 小説 section — writing mode + font size + line height + font family +
/// per-theme background color. All controls reflect live in the open
/// reader (spec Requirement "Novel section controls reader appearance").
class NovelSection extends ConsumerWidget {
  const NovelSection({super.key});

  static const List<String> fontFamilies = <String>[
    'noto-serif-jp',
    'noto-sans-jp',
  ];

  /// Background color presets per theme. The reader can also accept any
  /// 0xAARRGGBB value persisted later; presets are a v0.1 affordance.
  static const Map<String, int> lightPresets = <String, int>{
    'クリーム': 0xFFFAF7EE,
    'ホワイト': 0xFFFFFFFF,
    'グレー': 0xFFEDEDED,
  };
  static const Map<String, int> darkPresets = <String, int>{
    'スレート': 0xFF1C1B1F,
    'ブラック': 0xFF000000,
    'ネイビー': 0xFF0C1A2B,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final AppSettings s = ref.watch(
      appSettingsProvider.select(
        (AsyncValue<AppSettings> a) => a.value ?? AppSettings.defaults(),
      ),
    );

    void mutate(AppSettings Function(AppSettings) f) {
      ref.read(appSettingsProvider.notifier).mutate(f);
    }

    return SettingsSection(
      id: 'novel',
      title: l10n.settingsSectionNovel,
      children: <Widget>[
        ListTile(
          key: const Key('novel-writing-mode'),
          title: Text(l10n.settingsNovelWritingMode),
          subtitle: Wrap(
            spacing: 8,
            children: <Widget>[
              for (final NovelWritingMode m in NovelWritingMode.values)
                ChoiceChip(
                  key: Key('writing-mode-${m.name}'),
                  label: Text(
                    m == NovelWritingMode.vertical
                        ? l10n.settingsNovelWritingModeVertical
                        : l10n.settingsNovelWritingModeHorizontal,
                  ),
                  selected: s.novelWritingMode == m,
                  onSelected: (bool sel) {
                    if (!sel) return;
                    mutate((AppSettings v) => v.copyWith(novelWritingMode: m));
                  },
                ),
            ],
          ),
        ),
        ListTile(
          key: const Key('novel-font-size'),
          title: Text(
            l10n.settingsNovelFontSize(s.novelFontSizeSp.toStringAsFixed(0)),
          ),
          subtitle: Slider(
            key: const Key('novel-font-size-slider'),
            min: 12.0,
            max: 32.0,
            divisions: 20,
            value: s.novelFontSizeSp.clamp(12.0, 32.0),
            label: s.novelFontSizeSp.toStringAsFixed(0),
            onChanged: (double v) =>
                mutate((AppSettings st) => st.copyWith(novelFontSizeSp: v)),
          ),
        ),
        ListTile(
          key: const Key('novel-line-height'),
          title: Text(
            l10n.settingsNovelLineHeight(s.novelLineHeight.toStringAsFixed(1)),
          ),
          subtitle: Slider(
            key: const Key('novel-line-height-slider'),
            min: 1.0,
            max: 3.0,
            divisions: 20,
            value: s.novelLineHeight.clamp(1.0, 3.0),
            label: s.novelLineHeight.toStringAsFixed(1),
            onChanged: (double v) =>
                mutate((AppSettings st) => st.copyWith(novelLineHeight: v)),
          ),
        ),
        ListTile(
          key: const Key('novel-font-family'),
          title: Text(l10n.settingsNovelFont),
          subtitle: DropdownButton<String>(
            key: const Key('novel-font-family-dropdown'),
            value: s.novelFontFamily,
            isExpanded: true,
            items: <DropdownMenuItem<String>>[
              for (final String f in fontFamilies)
                DropdownMenuItem<String>(value: f, child: Text(f)),
            ],
            onChanged: (String? v) {
              if (v == null) return;
              mutate((AppSettings st) => st.copyWith(novelFontFamily: v));
            },
          ),
        ),
        _BackgroundPicker(
          id: 'novel-bg-light',
          title: l10n.settingsNovelBgLight,
          presets: lightPresets,
          current: s.novelBackgroundLight,
          onPick: (int argb) => mutate(
            (AppSettings st) => st.copyWith(novelBackgroundLight: argb),
          ),
        ),
        _BackgroundPicker(
          id: 'novel-bg-dark',
          title: l10n.settingsNovelBgDark,
          presets: darkPresets,
          current: s.novelBackgroundDark,
          onPick: (int argb) => mutate(
            (AppSettings st) => st.copyWith(novelBackgroundDark: argb),
          ),
        ),
      ],
    );
  }
}

class _BackgroundPicker extends StatelessWidget {
  const _BackgroundPicker({
    required this.id,
    required this.title,
    required this.presets,
    required this.current,
    required this.onPick,
  });

  final String id;
  final String title;
  final Map<String, int> presets;
  final int current;
  final void Function(int) onPick;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key(id),
      title: Text(title),
      subtitle: Wrap(
        spacing: 8,
        children: <Widget>[
          for (final MapEntry<String, int> e in presets.entries)
            ChoiceChip(
              key: Key('$id-${e.key}'),
              label: Text(e.key),
              selected: current == e.value,
              avatar: CircleAvatar(backgroundColor: Color(e.value)),
              onSelected: (bool sel) {
                if (!sel) return;
                onPick(e.value);
              },
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/app_settings.dart';
import 'app_settings_notifier.dart';
import 'sections/about_section.dart';
import 'sections/audio_section.dart';
import 'sections/cache_section.dart';
import 'sections/display_section.dart';
import 'sections/library_section.dart';
import 'sections/novel_section.dart';
import 'sections/online_services_section.dart';
import 'sections/playback_section.dart';
import 'sections/r18_section.dart';
import 'sections/video_section.dart';

/// Top-level settings screen. Renders 10 sections in the fixed order
/// declared by spec `app-settings` Requirement "Settings screen
/// accessible from the home screen":
///
///   表示 / 再生 / 動画 / 音楽 / 小説 / ライブラリ / キャッシュ /
///   オンラインサービス / R18 / About
///
/// Flushes any pending writes from [AppSettingsNotifier] on dispose so
/// debounced changes survive a quick "back" press.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void deactivate() {
    // Fire-and-forget flush while the widget tree is still intact —
    // running this here (instead of in `dispose`) keeps `ref` usable
    // because the widget is not yet finalized. Pending writes drain
    // via drift's transaction queue afterwards.
    // ignore: discarded_futures
    ref.read(appSettingsProvider.notifier).flush();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final AsyncValue<AppSettings> async = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.settingsLoadError(e)),
          ),
        ),
        data: (_) => ListView(
          key: const Key('settings-list'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: const <Widget>[
            DisplaySection(),
            PlaybackSection(),
            VideoSection(),
            AudioSection(),
            NovelSection(),
            LibrarySection(),
            CacheSection(),
            OnlineServicesSection(),
            R18Section(),
            AboutSection(),
          ],
        ),
      ),
    );
  }
}

/// Section scaffold reused by every concrete section. Renders a Material
/// 3 Card with a title header and a column of [children] tiles.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.id,
    required this.title,
    required this.children,
  });

  /// Used as the Key for widget tests (`Key('section-<id>')`).
  final String id;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('section-$id'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Subtle helper text shown under tiles whose policy is "next launch only".
class NextLaunchHelper extends StatelessWidget {
  const NextLaunchHelper({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        l10n.settingsNextLaunchHelper,
        style: style?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}

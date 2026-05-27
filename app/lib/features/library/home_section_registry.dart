import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../about/presentation/about_app_bar_action.dart';
import '../audio/presentation/audio_home_section.dart';
import '../novel/presentation/novel_home_section.dart';
import '../novel_kakuyomu/presentation/kakuyomu_home_sections.dart';
import '../settings/presentation/recent_items_pruner.dart';
import '../settings/presentation/settings_app_bar_action.dart';
import '../video/presentation/video_home_section.dart';
import 'home_section.dart';

part 'home_section_registry.g.dart';

/// Aggregate of every [HomeSection] each feature publishes via its own
/// sub-provider. Spreading from sub-providers means later changes only
/// add a single `...ref.watch(...)` line — no other source touches this
/// list, satisfying ADR-0004's conflict-free contract.
@Riverpod(keepAlive: true)
List<HomeSection> homeSections(Ref ref) {
  // Trigger the recent-items prune lazily on home render. The pruner
  // provider re-runs whenever `recentItemsCap` changes in AppSettings
  // (spec add-app-settings Requirement "Library section caps recent
  // items and supports history clear" — "the next time the home screen
  // renders, the system MUST prune `recent_items` down to the new cap").
  ref.watch(recentItemsPruneProvider);

  final List<HomeSection> all = <HomeSection>[
    ...ref.watch(videoHomeSectionsProvider),
    ...ref.watch(audioHomeSectionsProvider),
    ...ref.watch(novelHomeSectionsProvider),
    // Wave 3 — narou/kakuyomu fold their tabs under the novel section.
    ...ref.watch(kakuyomuHomeSectionsProvider),
  ];
  all.sort((HomeSection a, HomeSection b) => a.order.compareTo(b.order));
  return List<HomeSection>.unmodifiable(all);
}

/// AppBar action aggregator. Settings (gear) and About (info) icons will
/// register here in Wave 3 / Wave 4.
@Riverpod(keepAlive: true)
List<HomeAppBarAction> homeAppBarActions(Ref ref) {
  final List<HomeAppBarAction> all = <HomeAppBarAction>[
    ...ref.watch(settingsAppBarActionsProvider),
    ...ref.watch(aboutAppBarActionsProvider),
  ];
  all.sort(
    (HomeAppBarAction a, HomeAppBarAction b) => a.order.compareTo(b.order),
  );
  return List<HomeAppBarAction>.unmodifiable(all);
}

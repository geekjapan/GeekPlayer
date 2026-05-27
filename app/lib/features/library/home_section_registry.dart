import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../video/presentation/video_home_section.dart';
import 'home_section.dart';

part 'home_section_registry.g.dart';

/// Aggregate of every [HomeSection] each feature publishes via its own
/// sub-provider. Spreading from sub-providers means later changes only
/// add a single `...ref.watch(...)` line — no other source touches this
/// list, satisfying ADR-0004's conflict-free contract.
@Riverpod(keepAlive: true)
List<HomeSection> homeSections(Ref ref) {
  final List<HomeSection> all = <HomeSection>[
    ...ref.watch(videoHomeSectionsProvider),
    // Wave 2 — audio: ...ref.watch(audioHomeSectionsProvider),
    // Wave 2 — novel-library: ...ref.watch(novelHomeSectionsProvider),
    // Wave 3 — narou/kakuyomu fold their tabs under the novel section.
  ];
  all.sort((HomeSection a, HomeSection b) => a.order.compareTo(b.order));
  return List<HomeSection>.unmodifiable(all);
}

/// AppBar action aggregator. Settings (gear) and About (info) icons will
/// register here in Wave 3 / Wave 4.
@Riverpod(keepAlive: true)
List<HomeAppBarAction> homeAppBarActions(Ref ref) {
  final List<HomeAppBarAction> all = <HomeAppBarAction>[
    // Wave 3 — app-settings: ...ref.watch(settingsAppBarActionsProvider),
    // Wave 4 — about-and-licenses: ...ref.watch(aboutAppBarActionsProvider),
  ];
  all.sort(
    (HomeAppBarAction a, HomeAppBarAction b) => a.order.compareTo(b.order),
  );
  return List<HomeAppBarAction>.unmodifiable(all);
}

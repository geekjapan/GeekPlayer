import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/novel/models/site.dart';

part 'site_filter_state.g.dart';

/// Currently-selected Site filter for [NovelHomeSection].
///
/// `null` means "show all sites". Backed by a [Notifier] so the chip
/// widgets can flip it without rebuilding the entire HomeSection
/// graph.
@Riverpod(keepAlive: true)
class SiteFilterState extends _$SiteFilterState {
  @override
  Site? build() => null;

  void set(Site site) => state = site;
  void clear() => state = null;
}

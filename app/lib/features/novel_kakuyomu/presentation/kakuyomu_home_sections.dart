import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../library/home_section.dart';
import 'kakuyomu_home_section.dart';

part 'kakuyomu_home_sections.g.dart';

/// `HomeSection` adapter that places the [KakuyomuSection] card just
/// below the shared `NovelHomeSection` (order 400). We reserve
/// **order 410** for Kakuyomu so the narou-reader change can take 405
/// without conflict.
class KakuyomuHomeSection implements HomeSection {
  const KakuyomuHomeSection();

  @override
  String get id => 'kakuyomu';

  @override
  int get order => 410;

  @override
  Widget build(BuildContext context, WidgetRef ref) => const KakuyomuSection();
}

/// Sub-provider aggregated by `homeSectionsProvider`.
@Riverpod(keepAlive: true)
List<HomeSection> kakuyomuHomeSections(Ref ref) {
  return const <HomeSection>[KakuyomuHomeSection()];
}

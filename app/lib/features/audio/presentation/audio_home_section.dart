import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../library/home_section.dart';
import 'home_section.dart';
import 'mini_player.dart';

part 'audio_home_section.g.dart';

/// Reserved order = 300 per ADR-0004.
class AudioHomeSection implements HomeSection {
  const AudioHomeSection();

  @override
  String get id => 'audio';

  @override
  int get order => 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AudioHomeSectionBody();
  }
}

/// Reserved order = 100 per ADR-0004 (sticky-ish at the top of the
/// scroll body). The mini player itself returns `SizedBox.shrink()`
/// when no session is active, so the row simply takes 0 height.
class MiniPlayerHomeSection implements HomeSection {
  const MiniPlayerHomeSection();

  @override
  String get id => 'audio.miniPlayer';

  @override
  int get order => 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) => const MiniPlayer();
}

@Riverpod(keepAlive: true)
List<HomeSection> audioHomeSections(Ref ref) {
  return const <HomeSection>[MiniPlayerHomeSection(), AudioHomeSection()];
}

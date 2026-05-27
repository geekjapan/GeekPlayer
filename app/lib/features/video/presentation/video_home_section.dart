import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../library/home_section.dart';
import 'home_section.dart';

part 'video_home_section.g.dart';

/// HomeSection contributed by the local-video-playback feature. Reserved
/// order 200 per ADR-0004.
class VideoHomeSection implements HomeSection {
  const VideoHomeSection();

  @override
  String get id => 'video';

  @override
  int get order => 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const VideoHomeSectionBody();
  }
}

@Riverpod(keepAlive: true)
List<HomeSection> videoHomeSections(Ref ref) {
  return const <HomeSection>[VideoHomeSection()];
}

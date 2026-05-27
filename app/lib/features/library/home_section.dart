import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contract every home-screen section implements. See ADR-0004 for the
/// rationale (avoids merge conflict in `home_screen.dart` across the
/// six Wave-2/3 changes that need to surface UI on the home screen).
///
/// Reserved `order` values (ADR-0004 §"order 値の規約"):
///   100  MiniPlayer (audio)
///   200  Video
///   300  Audio
///   400  Novel
///   500  Book (v0.2)
///   600  Manga (v0.2)
abstract class HomeSection {
  const HomeSection();
  String get id;
  int get order;
  Widget build(BuildContext context, WidgetRef ref);
}

/// Mirror of [HomeSection] for AppBar `actions`. Used by settings (gear)
/// and about (info) icons added in Wave 3/4.
abstract class HomeAppBarAction {
  const HomeAppBarAction();
  String get id;
  int get order;
  Widget build(BuildContext context, WidgetRef ref);
}

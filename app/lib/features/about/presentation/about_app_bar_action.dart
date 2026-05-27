import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../library/home_section.dart';
import 'about_screen.dart';

part 'about_app_bar_action.g.dart';

/// AppBar info icon contributed by `add-about-and-licenses`.
///
/// Reserved `order = 1100` (after the settings gear at `1000`) so the
/// info icon sits to the right of the settings gear. Picks up the home
/// screen via ADR-0004's `homeAppBarActionsProvider` registry — we never
/// edit `home_screen.dart` directly.
class AboutAppBarAction implements HomeAppBarAction {
  const AboutAppBarAction();

  @override
  String get id => 'about.info';

  @override
  int get order => 1100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const Key('home-app-bar-about'),
      icon: const Icon(Icons.info_outline),
      tooltip: 'アプリ情報',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
        );
      },
    );
  }
}

@Riverpod(keepAlive: true)
List<HomeAppBarAction> aboutAppBarActions(Ref ref) {
  return const <HomeAppBarAction>[AboutAppBarAction()];
}

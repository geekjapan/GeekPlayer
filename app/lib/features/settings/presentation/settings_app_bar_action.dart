import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../library/home_section.dart';
import 'settings_screen.dart';

part 'settings_app_bar_action.g.dart';

/// AppBar gear icon contributed by `add-app-settings`.
///
/// Reserved `order = 1000` (well above existing actions) so settings sits
/// to the right of any feature-specific AppBar action a later change
/// might add. Picks up the home screen via ADR-0004's
/// `homeAppBarActionsProvider` registry.
class SettingsAppBarAction implements HomeAppBarAction {
  const SettingsAppBarAction();

  @override
  String get id => 'settings.gear';

  @override
  int get order => 1000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const Key('home-app-bar-settings'),
      icon: const Icon(Icons.settings),
      tooltip: '設定',
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      },
    );
  }
}

@Riverpod(keepAlive: true)
List<HomeAppBarAction> settingsAppBarActions(Ref ref) {
  return const <HomeAppBarAction>[SettingsAppBarAction()];
}

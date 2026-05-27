import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_section.dart';
import 'home_section_registry.dart';

/// Aggregating home screen. Renders whatever the section registry holds
/// for `HomeSection` and `HomeAppBarAction`. Do not edit the children
/// directly — add a new section via your feature's sub-provider (see
/// ADR-0004).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<HomeSection> sections = ref.watch(homeSectionsProvider);
    final List<HomeAppBarAction> actions = ref.watch(homeAppBarActionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeekPlayer'),
        actions: actions
            .map((HomeAppBarAction a) => a.build(context, ref))
            .toList(growable: false),
      ),
      body: ListView(
        children: sections
            .map((HomeSection s) => s.build(context, ref))
            .toList(growable: false),
      ),
    );
  }
}

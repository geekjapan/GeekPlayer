import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_quick_jump.dart';
import 'home_section.dart';
import 'home_section_registry.dart';

/// Aggregating home screen. Renders whatever the section registry holds
/// for `HomeSection` and `HomeAppBarAction`. Do not edit the children
/// directly — add a new section via your feature's sub-provider (see
/// ADR-0004).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _sectionKeys = <String, GlobalKey>{};

  void _jumpTo(String id) {
    final context = _sectionKeys[id]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<HomeSection> sections = ref.watch(homeSectionsProvider);
    final List<HomeAppBarAction> actions = ref.watch(homeAppBarActionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeekPlayer'),
        actions: actions
            .map((HomeAppBarAction a) => a.build(context, ref))
            .toList(growable: false),
      ),
      body: Column(
        children: [
          HomeQuickJumpBar(sections: sections, onSelected: _jumpTo),
          Expanded(
            child: ListView(
              children: [
                // Keep distant section anchors mounted for ensureVisible.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final section in sections)
                      KeyedSubtree(
                        key: _sectionKeys.putIfAbsent(
                          section.id,
                          GlobalKey.new,
                        ),
                        child: section.build(context, ref),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

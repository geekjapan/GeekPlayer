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
  String? _destination;
  bool _positioning = false;
  bool _correctionScheduled = false;

  void _jumpTo(String id) {
    _destination = id;
    _revealDestination();
  }

  void _revealDestination() {
    final context = _sectionKeys[_destination]?.currentContext;
    if (context == null) return;
    _positioning = true;
    try {
      Scrollable.ensureVisible(context);
    } finally {
      _positioning = false;
    }
  }

  bool _onSectionResize(SizeChangedLayoutNotification notification) {
    if (_destination != null && !_correctionScheduled) {
      _correctionScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _correctionScheduled = false;
        if (mounted) _revealDestination();
      });
    }
    return false;
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
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (notification) {
                if (notification.depth == 0 && !_positioning) {
                  _destination = null;
                }
                return false;
              },
              child: NotificationListener<SizeChangedLayoutNotification>(
                onNotification: _onSectionResize,
                child: ListView(
                  children: [
                    // Keep distant section anchors mounted for ensureVisible.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final section in sections)
                          SizeChangedLayoutNotifier(
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
            ),
          ),
        ],
      ),
    );
  }
}

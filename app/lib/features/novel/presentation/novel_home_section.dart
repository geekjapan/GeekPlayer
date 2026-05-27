import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work.dart';
import '../../library/home_section.dart';
import '../../novel_narou/presentation/narou_home_section.dart';
import '../data/consent_repository.dart';
import '../domain/list_library_use_case.dart';
import 'novel_settings_screen.dart';
import 'site_filter_state.dart';

part 'novel_home_section.g.dart';

/// HomeSection contributed by the online-novel-library feature.
///
/// Reserved order 400 per ADR-0004 §"order 値の規約" and CONVENTIONS.md
/// HomeSection table. Adds the Library grid + Site filter chips +
/// per-site "consent disabled" group headers.
class NovelHomeSection implements HomeSection {
  const NovelHomeSection();

  @override
  String get id => 'novel';

  @override
  int get order => 400;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _NovelHomeSectionBody();
  }
}

@Riverpod(keepAlive: true)
List<HomeSection> novelHomeSections(Ref ref) {
  return const <HomeSection>[NovelHomeSection()];
}

class _NovelHomeSectionBody extends ConsumerWidget {
  const _NovelHomeSectionBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Site? filter = ref.watch(siteFilterStateProvider);
    final ListLibraryUseCase listUseCase = ref.watch(
      listLibraryUseCaseProvider,
    );
    final ConsentRepository consent = ref.watch(consentRepositoryProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'オンライン小説 Library',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('open-novel-settings'),
                  icon: const Icon(Icons.settings),
                  tooltip: 'オンライン小説設定',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NovelSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SiteFilterChips(current: filter),
          const SizedBox(height: 8),
          // Wave 3 (`add-narou-novel-reader`) が提供する「なろう」パネル。
          // 検索 / ランキング / R18 入口を NovelHomeSection 内に折り込む
          // (ADR-0004: HomeScreen 本体は触らない)。
          const NarouHomeSection(),
          const SizedBox(height: 8),
          FutureBuilder<_NovelLibraryState>(
            future: _load(consent, listUseCase, filter),
            builder:
                (BuildContext context, AsyncSnapshot<_NovelLibraryState> snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final _NovelLibraryState st = snap.data!;
                  if (st.works.isEmpty) {
                    return const _EmptyPlaceholder();
                  }
                  return _LibraryGrid(state: st);
                },
          ),
        ],
      ),
    );
  }

  Future<_NovelLibraryState> _load(
    ConsentRepository consent,
    ListLibraryUseCase listUseCase,
    Site? filter,
  ) async {
    final List<Work> works = await listUseCase.call(site: filter);
    final Map<Site, bool> grants = <Site, bool>{};
    for (final Site s in Site.values) {
      grants[s] = await consent.hasFreshConsent(s);
    }
    return _NovelLibraryState(works: works, grants: grants);
  }
}

class _NovelLibraryState {
  const _NovelLibraryState({required this.works, required this.grants});

  final List<Work> works;
  final Map<Site, bool> grants;
}

class _SiteFilterChips extends ConsumerWidget {
  const _SiteFilterChips({required this.current});

  final Site? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          ChoiceChip(
            key: const Key('filter-all'),
            label: const Text('すべて'),
            selected: current == null,
            onSelected: (_) =>
                ref.read(siteFilterStateProvider.notifier).clear(),
          ),
          for (final Site s in Site.values)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                key: ValueKey<String>('filter-${s.code}'),
                label: Text(s.displayName),
                selected: current == s,
                onSelected: (_) =>
                    ref.read(siteFilterStateProvider.notifier).set(s),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Library に小説はまだありません。'),
          SizedBox(height: 8),
          // The search screen is contributed by site-specific changes
          // (add-narou-novel-reader / add-kakuyomu-novel-reader). Disabled
          // for now per spec scenario "Empty Library shows placeholder".
          OutlinedButton(
            key: Key('open-search-disabled'),
            onPressed: null,
            child: Text('検索画面を開く (後続 change で有効化)'),
          ),
        ],
      ),
    );
  }
}

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({required this.state});

  final _NovelLibraryState state;

  @override
  Widget build(BuildContext context) {
    // Group by site so consent-disabled groups can carry the
    // "同意が無効化されています" header (spec online-novel-library:
    // 'consent-disabled groups').
    final Map<Site, List<Work>> bySite = <Site, List<Work>>{};
    for (final Work w in state.works) {
      bySite.putIfAbsent(w.id.site, () => <Work>[]).add(w);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final Site s in Site.values)
          if (bySite[s] != null && bySite[s]!.isNotEmpty)
            _SiteGroup(
              site: s,
              works: bySite[s]!,
              granted: state.grants[s] ?? false,
            ),
      ],
    );
  }
}

class _SiteGroup extends StatelessWidget {
  const _SiteGroup({
    required this.site,
    required this.works,
    required this.granted,
  });

  final Site site;
  final List<Work> works;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                site.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              if (!granted)
                const Chip(
                  key: Key('consent-disabled-banner'),
                  label: Text('同意が無効化されています — 設定で再同意'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final Work w in works)
                _WorkCard(work: w, disabled: !granted),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.work, required this.disabled});

  final Work work;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Card(
        key: ValueKey<String>(
          'work-${work.id.site.code}-${work.id.externalId}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Chip(
                      label: Text(
                        work.id.site.code,
                        style: const TextStyle(fontSize: 10),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  work.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(work.author, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  '${work.episodeCount} 話',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

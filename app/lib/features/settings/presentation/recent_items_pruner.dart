import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/database.dart';
import '../../../core/storage/providers.dart';
import '../domain/app_settings.dart';
import 'app_settings_notifier.dart';

part 'recent_items_pruner.g.dart';

/// Side-effect provider: when the home screen is mounted (or whenever
/// `recentItemsCap` changes via the settings screen), prune the
/// `recent_items` table down to the configured cap.
///
/// Spec `app-settings` Requirement "Library section caps recent items
/// and supports history clear" mandates lazy pruning at next home
/// render time — this provider implements that lazy prune as a
/// rebuild-on-cap-change `Future`.
@Riverpod(keepAlive: true)
Future<int> recentItemsPrune(Ref ref) async {
  final AsyncValue<AppSettings> async = ref.watch(appSettingsProvider);
  final int cap = async.value?.recentItemsCap ?? 50;
  final RecentItemsDao dao = ref.read(recentItemsDaoProvider);
  int total = 0;
  for (final String kind in const <String>['video', 'audio', 'novel']) {
    total += await dao.pruneOlderThan(kind, cap);
  }
  return total;
}

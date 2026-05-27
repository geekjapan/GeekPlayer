import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/app_settings_repository.dart';
import '../domain/app_settings.dart';

part 'app_settings_notifier.g.dart';

/// Debounce window between the last `update(...)` call and the actual
/// drift write. Spec `settings-persistence` Requirement "AppSettingsNotifier
/// persists changes with debounced writes" mandates 250 ms.
const Duration kAppSettingsWriteDebounce = Duration(milliseconds: 250);

/// Single Riverpod gate for reading and writing user settings.
///
/// `build()` hydrates the snapshot via [AppSettingsRepository.readAll].
/// `update(...)` performs an in-memory state change synchronously and
/// schedules a debounced `writeDiff` against the previously committed
/// snapshot. Rapid sequences (e.g. dragging a slider) coalesce to a
/// single write per `key`.
///
/// On disposal the notifier flushes any pending write so user changes
/// survive app shutdown (spec scenario "Dispose flushes pending writes").
@Riverpod(keepAlive: true)
class AppSettingsNotifier extends _$AppSettingsNotifier {
  Timer? _debounce;

  /// The last snapshot known to have been persisted. `writeDiff` compares
  /// the current target against this so partial / coalesced writes never
  /// re-persist a key that already made it to disk.
  AppSettings? _committed;

  /// The freshest target. While the debounce timer is alive, this is the
  /// snapshot we will write on the next flush.
  AppSettings? _pending;

  @override
  Future<AppSettings> build() async {
    // Capture the repo BEFORE registering onDispose so the dispose path
    // can flush without using `ref` (Riverpod forbids `ref.read` inside
    // lifecycle callbacks).
    final AppSettingsRepository repo = ref.read(appSettingsRepositoryProvider);
    ref.onDispose(() => _onDispose(repo));
    final AppSettings hydrated = await repo.readAll();
    _committed = hydrated;
    return hydrated;
  }

  /// Synchronously update the in-memory snapshot and schedule a debounced
  /// write. The transform [f] is given the current snapshot (defaults if
  /// hydration is still in flight) and must return the new snapshot.
  ///
  /// Named `mutate` (not `update`) because `AsyncNotifier.update` already
  /// exists on the base class with a different signature.
  void mutate(AppSettings Function(AppSettings) f) {
    final AppSettings current =
        state.value ?? (_pending ?? AppSettings.defaults());
    final AppSettings next = f(current);
    if (next == current) return;
    state = AsyncData<AppSettings>(next);
    _pending = next;
    _debounce?.cancel();
    _debounce = Timer(kAppSettingsWriteDebounce, _flush);
  }

  /// Flush any pending write synchronously (e.g. user is leaving the
  /// settings screen). Public so screen-level `dispose` can call it.
  Future<void> flush() async {
    _debounce?.cancel();
    _debounce = null;
    await _flush();
  }

  Future<void> _flush() async {
    final AppSettings? pending = _pending;
    final AppSettings? committed = _committed;
    if (pending == null || committed == null) return;
    if (pending == committed) {
      _pending = null;
      return;
    }
    try {
      await ref
          .read(appSettingsRepositoryProvider)
          .writeDiff(committed, pending);
      _committed = pending;
      _pending = null;
    } catch (e, st) {
      // Roll back state to the last committed snapshot and surface the
      // error so the UI can show a banner. Spec `settings-persistence`
      // Requirement "Write path is transactional".
      state = AsyncError<AppSettings>(e, st);
      _pending = null;
    }
  }

  void _onDispose(AppSettingsRepository repo) {
    _debounce?.cancel();
    _debounce = null;
    // Best-effort synchronous flush: schedule the write but don't block
    // dispose on its completion. The repository was captured in build()
    // so we don't touch `ref` here (Riverpod forbids that inside
    // lifecycle callbacks).
    final AppSettings? pending = _pending;
    final AppSettings? committed = _committed;
    if (pending == null || committed == null || pending == committed) {
      return;
    }
    // Fire-and-forget so we don't await inside a sync teardown.
    unawaited(repo.writeDiff(committed, pending));
  }
}

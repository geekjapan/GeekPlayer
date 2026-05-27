import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/settings/domain/app_settings.dart';
import 'package:geekplayer/features/settings/presentation/app_settings_notifier.dart';

ProviderContainer _container(AppDatabase db) {
  return ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
  );
}

AppDatabase _freshDb() {
  return AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hydrates defaults on first build', () async {
    final AppDatabase db = _freshDb();
    addTearDown(db.close);
    final ProviderContainer c = _container(db);
    addTearDown(c.dispose);

    final AppSettings s = await c.read(appSettingsProvider.future);
    expect(s, AppSettings.defaults());
  });

  test('mutate updates state synchronously and persists after debounce',
      () async {
    final AppDatabase db = _freshDb();
    addTearDown(db.close);
    final ProviderContainer c = _container(db);
    addTearDown(c.dispose);

    // Force hydration.
    await c.read(appSettingsProvider.future);

    c.read(appSettingsProvider.notifier).mutate(
          (AppSettings s) => s.copyWith(themeMode: ThemeMode.dark),
        );

    // State updates immediately.
    final AsyncValue<AppSettings> live = c.read(appSettingsProvider);
    expect(live.value!.themeMode, ThemeMode.dark);

    // Repository hasn't seen the write yet — confirm by reading the DB.
    expect((await db.appSettingsDao.getAll()), isEmpty);

    // Advance past the debounce.
    await Future<void>.delayed(
      kAppSettingsWriteDebounce + const Duration(milliseconds: 50),
    );
    final rows = await db.appSettingsDao.getAll();
    expect(rows.length, 1);
    expect(rows.single.key, 'theme.mode');
    expect(rows.single.value, 'dark');
  });

  test('rapid mutations coalesce into a single write per key', () async {
    final AppDatabase db = _freshDb();
    addTearDown(db.close);
    final ProviderContainer c = _container(db);
    addTearDown(c.dispose);

    await c.read(appSettingsProvider.future);
    final notifier = c.read(appSettingsProvider.notifier);

    // Simulate slider drag: 7 quick updates.
    for (final double sp in <double>[16.5, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0]) {
      notifier.mutate((AppSettings s) => s.copyWith(novelFontSizeSp: sp));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    // Before debounce fires, nothing persisted.
    expect((await db.appSettingsDao.getAll()), isEmpty);

    await Future<void>.delayed(
      kAppSettingsWriteDebounce + const Duration(milliseconds: 50),
    );

    final rows = await db.appSettingsDao.getAll();
    expect(rows.length, 1);
    expect(rows.single.key, 'novel.font_size_sp');
    expect(rows.single.value, '22.0');

    // Live state matches the latest value.
    expect(
      c.read(appSettingsProvider).value!.novelFontSizeSp,
      22.0,
    );
  });

  test('flush() persists immediately without waiting for the debounce',
      () async {
    final AppDatabase db = _freshDb();
    addTearDown(db.close);
    final ProviderContainer c = _container(db);
    addTearDown(c.dispose);

    await c.read(appSettingsProvider.future);
    c.read(appSettingsProvider.notifier).mutate(
          (AppSettings s) => s.copyWith(subtitlesByDefault: true),
        );

    expect((await db.appSettingsDao.getAll()), isEmpty);

    await c.read(appSettingsProvider.notifier).flush();

    final rows = await db.appSettingsDao.getAll();
    expect(rows.length, 1);
    expect(rows.single.key, 'video.subtitles_default');
    expect(rows.single.value, 'true');
  });

  test('write failure surfaces an AsyncError on the notifier', () async {
    final AppDatabase db = _freshDb();
    final ProviderContainer c = _container(db);
    addTearDown(c.dispose);

    await c.read(appSettingsProvider.future);
    // Close the DB to make subsequent writes fail.
    await db.close();

    c.read(appSettingsProvider.notifier).mutate(
          (AppSettings s) => s.copyWith(themeMode: ThemeMode.dark),
        );

    await Future<void>.delayed(
      kAppSettingsWriteDebounce + const Duration(milliseconds: 50),
    );

    final live = c.read(appSettingsProvider);
    expect(live.hasError, isTrue);
  });
}

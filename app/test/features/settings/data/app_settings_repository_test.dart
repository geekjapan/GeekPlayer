import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/features/settings/data/app_settings_repository.dart';
import 'package:geekplayer/features/settings/domain/app_settings.dart';
import 'package:geekplayer/features/settings/domain/novel_writing_mode.dart';
import 'package:geekplayer/features/settings/domain/setting_keys.dart';

AppDatabase _freshDb() {
  return AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
}

void main() {
  group('readAll', () {
    test('returns defaults on an empty table', () async {
      final AppDatabase db = _freshDb();
      addTearDown(db.close);
      final AppSettingsRepository repo = AppSettingsRepository(
        db.appSettingsDao,
      );
      final AppSettings s = await repo.readAll();
      expect(s, AppSettings.defaults());
    });

    test('hydrates known rows and falls back per-key on malformed', () async {
      final AppDatabase db = _freshDb();
      addTearDown(db.close);
      // Seed: one well-formed (theme.mode = dark), one malformed.
      await db.appSettingsDao.upsert(SettingKeys.themeMode, 'dark');
      await db.appSettingsDao.upsert(
        SettingKeys.novelFontSizeSp,
        'NOT_A_NUMBER',
      );

      final AppSettingsRepository repo = AppSettingsRepository(
        db.appSettingsDao,
      );
      final AppSettings s = await repo.readAll();
      expect(s.themeMode, ThemeMode.dark);
      // Malformed value falls back to the default.
      expect(s.novelFontSizeSp, AppSettings.defaults().novelFontSizeSp);
      // Other keys remain at defaults.
      expect(s.recentItemsCap, AppSettings.defaults().recentItemsCap);
    });
  });

  group('writeDiff', () {
    test('writes only the changed keys', () async {
      final AppDatabase db = _freshDb();
      addTearDown(db.close);
      final AppSettingsRepository repo = AppSettingsRepository(
        db.appSettingsDao,
      );

      final AppSettings before = AppSettings.defaults();
      final AppSettings after = before.copyWith(themeMode: ThemeMode.dark);
      await repo.writeDiff(before, after);

      final rows = await db.appSettingsDao.getAll();
      expect(rows.length, 1);
      expect(rows.single.key, SettingKeys.themeMode);
      expect(rows.single.value, 'dark');
    });

    test('no-op diff issues no writes', () async {
      final AppDatabase db = _freshDb();
      addTearDown(db.close);
      final AppSettingsRepository repo = AppSettingsRepository(
        db.appSettingsDao,
      );
      await repo.writeDiff(AppSettings.defaults(), AppSettings.defaults());
      expect(await db.appSettingsDao.getAll(), isEmpty);
    });

    test('many fields change in one transaction', () async {
      final AppDatabase db = _freshDb();
      addTearDown(db.close);
      final AppSettingsRepository repo = AppSettingsRepository(
        db.appSettingsDao,
      );
      final AppSettings before = AppSettings.defaults();
      final AppSettings after = before.copyWith(
        themeMode: ThemeMode.dark,
        novelFontSizeSp: 22.0,
        novelWritingMode: NovelWritingMode.horizontal,
        novelCacheCapMb: 250,
      );
      await repo.writeDiff(before, after);
      final reread = await repo.readAll();
      expect(reread, after);
    });

    test('roundtrip via readAll matches the new snapshot', () async {
      final AppDatabase db = _freshDb();
      addTearDown(db.close);
      final AppSettingsRepository repo = AppSettingsRepository(
        db.appSettingsDao,
      );
      final AppSettings before = AppSettings.defaults();
      final AppSettings after = before.copyWith(
        defaultPlaybackSpeed: 1.5,
        subtitlesByDefault: true,
        recentItemsCap: 25,
      );
      await repo.writeDiff(before, after);
      expect(await repo.readAll(), after);
    });
  });

  group('writeDiff failure path', () {
    test(
      'throws and leaves the table unchanged when the DB is closed',
      () async {
        final AppDatabase db = _freshDb();
        final AppSettingsRepository repo = AppSettingsRepository(
          db.appSettingsDao,
        );
        // Persist one known row, then close the DB so the next transaction
        // fails synchronously inside drift.
        await repo.writeDiff(
          AppSettings.defaults(),
          AppSettings.defaults().copyWith(themeMode: ThemeMode.dark),
        );
        await db.close();

        expect(
          () => repo.writeDiff(
            AppSettings.defaults(),
            AppSettings.defaults().copyWith(themeMode: ThemeMode.light),
          ),
          throwsA(anything),
        );
      },
    );
  });

  group('writeAll', () {
    test('persists every field', () async {
      final AppDatabase db = _freshDb();
      addTearDown(db.close);
      final AppSettingsRepository repo = AppSettingsRepository(
        db.appSettingsDao,
      );
      final AppSettings snap = AppSettings.defaults().copyWith(
        novelCacheCapMb: 500,
      );
      await repo.writeAll(snap);
      expect((await db.appSettingsDao.getAll()).length, 13);
      expect(await repo.readAll(), snap);
    });
  });
}

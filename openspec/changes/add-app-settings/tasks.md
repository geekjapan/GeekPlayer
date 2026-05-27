> **Conventions**: [docs/CONVENTIONS.md](../../../docs/CONVENTIONS.md) と
> [ADR-0004 (HomeScreen registry)](../../../docs/adr/0004-home-screen-section-registry.md)
> を着手前に読むこと。Settings 画面の AppBar エントリ（gear アイコン）は
> `homeAppBarActionsProvider` にサブプロバイダとして登録する（`HomeScreen` 直接編集禁止）。

## 1. 依存とプロジェクト準備

- [ ] 1.1 `app/pubspec.yaml` に `package_info_plus` を追加（About セクションの
  バージョン表示用）し、`flutter pub get` がクリーン
- [ ] 1.2 `app/pubspec.yaml` の `flutter.fonts` に `noto-serif-jp` / `noto-sans-jp`
  を登録、フォントアセットを `app/assets/fonts/` に配置
- [ ] 1.3 `flutter analyze` と `flutter test` が依存変更後にクリーン

## 2. ストレージ層と migration (`core/storage`)

- [ ] 2.1 `app/lib/core/storage/tables/app_settings.dart` に drift テーブル
  `AppSettings(key TEXT PK NOT NULL, value TEXT NOT NULL)` を定義
- [ ] 2.2 `app/lib/core/storage/database.dart` の `@DriftDatabase.tables` に
  `AppSettings` を追加し、`schemaVersion` を 3 に引き上げ
- [ ] 2.3 `MigrationStrategy.onUpgrade` に `if (from < 3) await m.createTable(appSettings);`
  分岐を追加（既存の v1→v2 分岐があれば温存。冪等性を維持）
- [ ] 2.4 `app/lib/core/storage/migrations/v2_to_v3.dart` にマイグレーションロジック
  を切り出し、ユニットテスト用に export
- [ ] 2.5 `flutter pub run build_runner build --delete-conflicting-outputs` を
  実行し `database.g.dart` を再生成
- [ ] 2.6 in-memory drift で v1→v3 / v2→v3 のスキップマイグレーションを検証する
  ユニットテストを `app/test/core/storage/migration_v3_test.dart` に追加
- [ ] 2.7 fresh install（onCreate）で `app_settings` が空テーブルとして作成される
  ことを検証するテストを追加

## 3. ドメイン層 (`features/settings/domain`)

- [ ] 3.1 `app/lib/features/settings/domain/setting_keys.dart` に dotted-namespace
  の `SettingKeys` const map を定義（`theme.mode`, `playback.default_speed`,
  `video.subtitles_default`, `audio.background_playback`,
  `audio.notification_persistent`, `novel.writing_mode`, `novel.font_size_sp`,
  `novel.line_height`, `novel.font_family`, `novel.background_light`,
  `novel.background_dark`, `library.recent_cap`, `cache.cap_mb`）
- [ ] 3.2 `app/lib/features/settings/domain/app_settings.dart` に `AppSettings`
  値オブジェクトと `.defaults()` / `.copyWith(...)` / `==` / `hashCode` を実装
- [ ] 3.3 `NovelWritingMode` enum を `app/lib/features/settings/domain/novel_writing_mode.dart`
  に定義（`vertical` / `horizontal`）
- [ ] 3.4 `SettingKeys.all` が `^[a-z][a-z_]*(\.[a-z][a-z_]*)+$` regex に
  マッチすることを検証するユニットテストを追加
- [ ] 3.5 `AppSettings.defaults()` が spec で定義された全 13 フィールドの初期値
  を返すことを検証するテストを追加

## 4. データ層 (`features/settings/data`)

- [ ] 4.1 `app/lib/features/settings/data/settings_codec.dart` に
  `SettingCodec<T>` interface と `BoolCodec` / `IntCodec` / `DoubleCodec` /
  `NullableIntCodec` / `EnumCodec<ThemeMode>` / `EnumCodec<NovelWritingMode>` /
  `StringCodec` を実装
- [ ] 4.2 各 codec のユニットテストを `app/test/features/settings/data/settings_codec_test.dart`
  に追加（roundtrip / `FormatException` / null distinct encoding）
- [ ] 4.3 `app/lib/features/settings/data/app_settings_repository.dart` に
  `AppSettingsRepository`（`readAll()` / `writeDiff(old, new)`）を実装、drift
  DAO とトランザクションを扱う
- [ ] 4.4 `readAll()` が空テーブル / 不正値で defaults にフォールバックし、構造化
  ログを発する挙動をテスト
- [ ] 4.5 `writeDiff` が差分キーのみを 1 トランザクションで upsert することを
  in-memory drift で検証
- [ ] 4.6 `writeDiff` の失敗時にトランザクションがロールバックすることをテスト

## 5. プレゼンテーション層 — Notifier と画面骨格

- [ ] 5.1 `app/lib/features/settings/presentation/app_settings_notifier.dart` に
  `AppSettingsNotifier`（Riverpod v2 / `keepAlive: true`）を実装、`build()`
  で `readAll()` を呼ぶ
- [ ] 5.2 `update(AppSettings Function(AppSettings))` を実装、state を即時更新
  しつつ `writeDiff` を **key 単位 250ms debounce** で呼ぶ
- [ ] 5.3 Notifier の `dispose` で debounce 中の保留書き込みを flush
- [ ] 5.4 debounce / flush / partial-failure rollback のユニットテストを
  `app/test/features/settings/presentation/app_settings_notifier_test.dart` に追加
- [ ] 5.5 `app/lib/features/settings/presentation/settings_screen.dart` を実装
  （Material 3 `ListView` + 10 セクションを spec の順序で配置）
- [ ] 5.6 `MaterialApp.themeMode` を `appSettingsNotifierProvider.select((s) => s.value?.themeMode ?? ThemeMode.system)`
  で配線（`app/lib/main.dart:1` の `MaterialApp` を更新）

## 6. プレゼンテーション層 — 各セクション実装

- [ ] 6.1 `display_section.dart`: テーマモードのラジオ + アクセントカラー placeholder
  （disabled + "v0.2 で対応" バッジ）
- [ ] 6.2 `playback_section.dart`: デフォルト再生速度プリセット選択 + 次回起動
  helper text
- [ ] 6.3 `video_section.dart`: 字幕デフォルト switch + 次回起動 helper text
- [ ] 6.4 `audio_section.dart`: バックグラウンド再生 / 通知継続表示の 2 switch、
  即時反映（`audio_service` API 呼び直しを `add-local-audio-playback` 完了後
  に配線、本 change では値変更のみ実装）
- [ ] 6.5 `novel_section.dart`: 縦/横書き、文字サイズスライダー、行間スライダー、
  フォント選択、明暗別背景色ピッカー（即時反映）
- [ ] 6.6 `library_section.dart`: "最近開いた" 上限選択（10/25/50/100）+ 履歴
  クリアボタン（確認ダイアログ）。`recent_items` の prune は次回ホーム画面
  描画時に走るよう `HomeScreen` 側にフックを追加
- [ ] 6.7 `cache_section.dart`: キャッシュサイズ表示（`SUM(LENGTH(body_html))`
  を `AsyncValue` で取得）、上限設定、サイト別 / 全クリアボタン、超過時の
  警告バナーと "古い順に削除" ボタン
- [ ] 6.8 `online_services_section.dart`: ADR-0001 §注意書き-3 の常時表示文言、
  サイト別 consent switch、revoke 時にキャッシュ削除確認ダイアログを表示
- [ ] 6.9 `r18_section.dart`: 現在の同意状態表示と "年齢確認をやり直す" ボタン
  + 確認ダイアログ、`SiteConsentRepository.revoke(SiteId.narou18)` 呼び出し
- [ ] 6.10 `about_section.dart`: バージョン行（`package_info_plus` 連携）、
  ライセンス行 / OSS Notices 行（"未実装 (add-about-and-licenses)" placeholder
  画面へ遷移）

## 7. 既存 feature への統合

- [ ] 7.1 `app/lib/features/library/home_screen.dart:1` の `AppBar` に歯車
  `IconButton` を追加し、`SettingsScreen` への `Navigator.push` を配線
- [ ] 7.2 `app/lib/features/library/home_screen.dart` の "最近開いた" 表示前に
  `recent_items` を `AppSettings.recentItemsCap` に prune する処理を追加
- [ ] 7.3 `app/lib/features/video/presentation/player_screen.dart:1` の `MediaSession`
  初期化箇所で `AppSettings.defaultPlaybackSpeed` と `AppSettings.subtitlesByDefault`
  を初期値に使う
- [ ] 7.4 `app/lib/features/audio/presentation/audio_player_notifier.dart:1` で
  `AppSettings.audioBackgroundPlayback` / `audioNotificationPersistent` を購読
  し `audio_service` の設定を更新（`add-local-audio-playback` 完了前は
  スタブ呼び出しで配線）
- [ ] 7.5 `app/lib/features/novel/presentation/novel_reader_screen.dart:1` で
  小説関連 5 フィールド（writing mode / font size / line height / font family
  / background）を `.select` で個別購読し即時反映（`add-online-novel-library`
  完了前は配線のみ）

## 8. ウィジェットテストと統合テスト

- [ ] 8.1 `SettingsScreen` の widget test: 10 セクションが宣言順でレンダリング
  されることを検証
- [ ] 8.2 表示テーマ変更が `MaterialApp.themeMode` に即時反映される widget test
- [ ] 8.3 デフォルト再生速度を変更しても "現在再生中の動画" は変わらないことを
  検証する widget test（モック `VideoSession`）
- [ ] 8.4 小説フォントサイズスライダー操作で 250ms 後に repository.writeDiff
  が呼ばれることを検証する widget test
- [ ] 8.5 オンラインサービスで kakuyomu を OFF にすると、キャッシュ削除確認
  ダイアログが出る widget test
- [ ] 8.6 R18 リセットボタンが確認ダイアログを出し、確認後に `SiteConsentRepository.revoke`
  が呼ばれる widget test
- [ ] 8.7 履歴クリアボタンが確認ダイアログを出し、確認後に `recent_items` が
  空になる widget test
- [ ] 8.8 About バージョン行が pubspec の `version:` と一致する文字列を表示する
  widget test
- [ ] 8.9 `flutter analyze` / `flutter test` / `dart format --set-exit-if-changed .`
  が CI でも green

## 9. ドキュメントと締め

- [ ] 9.1 `README.md` の「設定」セクションに本 change で追加した項目を一覧で
  記載（必要なら）
- [ ] 9.2 `docs/adr/` に schema versioning policy ADR を追加（v1=video,
  v2=novel-library, v3=app-settings の順序前提を残す）
- [ ] 9.3 すべての task の `- [ ]` を `- [x]` に更新し、`/opsx:archive` で本
  change をアーカイブ

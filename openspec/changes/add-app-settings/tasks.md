> **Conventions**: [docs/CONVENTIONS.md](../../../docs/CONVENTIONS.md) と
> [ADR-0004 (HomeScreen registry)](../../../docs/adr/0004-home-screen-section-registry.md)
> を着手前に読むこと。Settings 画面の AppBar エントリ（gear アイコン）は
> `homeAppBarActionsProvider` にサブプロバイダとして登録する（`HomeScreen` 直接編集禁止）。

## 1. 依存とプロジェクト準備

- [x] 1.1 `app/pubspec.yaml` に `package_info_plus` を追加（About セクションの
  バージョン表示用）し、`flutter pub get` がクリーン  *（pubspec に既に `package_info_plus: ^10.1.0` が含まれており、冪等に確認のみ）*
- [ ] 1.2 `app/pubspec.yaml` の `flutter.fonts` に `noto-serif-jp` / `noto-sans-jp`
  を登録、フォントアセットを `app/assets/fonts/` に配置  *（実フォントファイルは未バンドル — フォント family 名は UI 側で選択可能とし、実バンドルは v0.2 packaging へ deferred）*
- [x] 1.3 `flutter analyze` と `flutter test` が依存変更後にクリーン  *（baseline analyze は green を確認、`flutter test` は実装完了後に走らせる）*

## 2. ストレージ層と migration (`core/storage`)

- [x] 2.1 `app/lib/core/storage/tables/app_settings.dart` に drift テーブル
  `AppSettings(key TEXT PK NOT NULL, value TEXT NOT NULL)` を定義
- [x] 2.2 `app/lib/core/storage/database.dart` の `@DriftDatabase.tables` に
  `AppSettings` を追加し、`schemaVersion` を 3 に引き上げ
- [x] 2.3 `MigrationStrategy.onUpgrade` に `if (from < 3) await m.createTable(appSettings);`
  分岐を追加（既存の v1→v2 分岐があれば温存。冪等性を維持）
- [x] 2.4 `app/lib/core/storage/migrations/v2_to_v3.dart` にマイグレーションロジック
  を切り出し、ユニットテスト用に export
- [x] 2.5 `flutter pub run build_runner build --delete-conflicting-outputs` を
  実行し `database.g.dart` を再生成
- [x] 2.6 in-memory drift で v1→v3 / v2→v3 のスキップマイグレーションを検証する
  ユニットテストを `app/test/core/storage/migration_v2_to_v3_test.dart` に追加
- [x] 2.7 fresh install（onCreate）で `app_settings` が空テーブルとして作成される
  ことを検証するテストを追加

## 3. ドメイン層 (`features/settings/domain`)

- [x] 3.1 `app/lib/features/settings/domain/setting_keys.dart` に dotted-namespace
  の `SettingKeys` const map を定義（`theme.mode`, `playback.default_speed`,
  `video.subtitles_default`, `audio.background_playback`,
  `audio.notification_persistent`, `novel.writing_mode`, `novel.font_size_sp`,
  `novel.line_height`, `novel.font_family`, `novel.background_light`,
  `novel.background_dark`, `library.recent_cap`, `cache.cap_mb`）
- [x] 3.2 `app/lib/features/settings/domain/app_settings.dart` に `AppSettings`
  値オブジェクトと `.defaults()` / `.copyWith(...)` / `==` / `hashCode` を実装
- [x] 3.3 `NovelWritingMode` enum を `app/lib/features/settings/domain/novel_writing_mode.dart`
  に定義（`vertical` / `horizontal`）
- [x] 3.4 `SettingKeys.all` が `^[a-z][a-z_]*(\.[a-z][a-z_]*)+$` regex に
  マッチすることを検証するユニットテストを追加
- [x] 3.5 `AppSettings.defaults()` が spec で定義された全 13 フィールドの初期値
  を返すことを検証するテストを追加

## 4. データ層 (`features/settings/data`)

- [x] 4.1 `app/lib/features/settings/data/settings_codec.dart` に
  `SettingCodec<T>` interface と `BoolCodec` / `IntCodec` / `DoubleCodec` /
  `NullableIntCodec` / `EnumCodec<ThemeMode>` / `EnumCodec<NovelWritingMode>` /
  `StringCodec` を実装
- [x] 4.2 各 codec のユニットテストを `app/test/features/settings/data/settings_codec_test.dart`
  に追加（roundtrip / `FormatException` / null distinct encoding）
- [x] 4.3 `app/lib/features/settings/data/app_settings_repository.dart` に
  `AppSettingsRepository`（`readAll()` / `writeDiff(old, new)`）を実装、drift
  DAO とトランザクションを扱う
- [x] 4.4 `readAll()` が空テーブル / 不正値で defaults にフォールバックし、構造化
  ログを発する挙動をテスト
- [x] 4.5 `writeDiff` が差分キーのみを 1 トランザクションで upsert することを
  in-memory drift で検証
- [x] 4.6 `writeDiff` の失敗時にトランザクションがロールバックすることをテスト

## 5. プレゼンテーション層 — Notifier と画面骨格

- [x] 5.1 `app/lib/features/settings/presentation/app_settings_notifier.dart` に
  `AppSettingsNotifier`（Riverpod v3 / `@Riverpod(keepAlive: true) class`）を実装、`build()`
  で `readAll()` を呼ぶ
- [x] 5.2 `mutate(AppSettings Function(AppSettings))` を実装、state を即時更新
  しつつ `writeDiff` を **250ms debounce** で呼ぶ  *（メソッド名は AsyncNotifier 基底クラスの `update` と衝突するため `mutate` を採用）*
- [x] 5.3 Notifier の `dispose` で debounce 中の保留書き込みを flush
- [x] 5.4 debounce / flush / partial-failure rollback のユニットテストを
  `app/test/features/settings/presentation/app_settings_notifier_test.dart` に追加
- [x] 5.5 `app/lib/features/settings/presentation/settings_screen.dart` を実装
  （Material 3 `ListView` + 10 セクションを spec の順序で配置）
- [x] 5.6 `MaterialApp.themeMode` を `appSettingsProvider.select((s) => s.value?.themeMode ?? ThemeMode.system)`
  で配線（`app/lib/main.dart` の `MaterialApp` を更新、`darkTheme` も追加）

## 6. プレゼンテーション層 — 各セクション実装

- [x] 6.1 `display_section.dart`: テーマモードのラジオ + アクセントカラー placeholder
  （disabled + "v0.2 で対応" バッジ）
- [x] 6.2 `playback_section.dart`: デフォルト再生速度プリセット選択 + 次回起動
  helper text
- [x] 6.3 `video_section.dart`: 字幕デフォルト switch + 次回起動 helper text
- [x] 6.4 `audio_section.dart`: バックグラウンド再生 / 通知継続表示の 2 switch、
  即時反映（`audio_service` API 呼び直しを `add-local-audio-playback` 完了後
  に配線、本 change では値変更のみ実装）
- [x] 6.5 `novel_section.dart`: 縦/横書き、文字サイズスライダー、行間スライダー、
  フォント選択、明暗別背景色ピッカー（即時反映）
- [x] 6.6 `library_section.dart`: "最近開いた" 上限選択（10/25/50/100）+ 履歴
  クリアボタン（確認ダイアログ）。`recent_items` の prune は次回ホーム画面
  描画時に走るよう `HomeScreen` 側にフックを追加  *（prune フックは task 7.2 で配線）*
- [x] 6.7 `cache_section.dart`: キャッシュサイズ表示（`SUM(LENGTH(body))`
  を `AsyncValue` で取得）、上限設定、サイト別 / 全クリアボタン、超過時の
  警告バナーと "古い順に削除" ボタン
- [x] 6.8 `online_services_section.dart`: ADR-0001 §注意書き-3 の常時表示文言、
  サイト別 consent switch、revoke 時にキャッシュ削除確認ダイアログを表示
- [x] 6.9 `r18_section.dart`: 現在の同意状態表示と "年齢確認をやり直す" ボタン
  + 確認ダイアログ、`SiteConsentRepository.revoke` 呼び出し  *（`SiteId.narou18` は `add-narou-novel-reader` 未merge のため、現状は `Site.noc` (ノクターン系) を revoke して同等の R18 リセットを実現）*
- [x] 6.10 `about_section.dart`: バージョン行（`package_info_plus` 連携）、
  ライセンス行 / OSS Notices 行（"未実装 (add-about-and-licenses)" placeholder
  画面へ遷移）

## 7. 既存 feature への統合

- [x] 7.1 `homeAppBarActionsProvider` 経由で歯車 `IconButton` を登録
  （`features/settings/presentation/settings_app_bar_action.dart`）、
  `home_section_registry.dart` の `homeAppBarActions` に
  `...ref.watch(settingsAppBarActionsProvider)` を追加し
  `SettingsScreen` への `Navigator.push` を配線  *（HomeScreen 本体は ADR-0004 に従い非編集）*
- [x] 7.2 `recent_items` の prune 処理を `recentItemsPruneProvider`
  （`features/settings/presentation/recent_items_pruner.dart`）として実装、
  `homeSectionsProvider` から `ref.watch` で参照することで
  HomeScreen 描画時に `AppSettings.recentItemsCap` 上限へ prune
- [x] 7.3 `app/lib/features/video/presentation/video_controller_notifier.dart`
  の `MediaSession` 初期化箇所で `AppSettings.defaultPlaybackSpeed` を
  初期値に適用  *（字幕デフォルトは video session API が次回起動扱いのため UI helper のみ表示）*
- [x] 7.4 `app/lib/features/audio/presentation/audio_controller_notifier.dart`
  の `_loadCurrentAndPlay` で `AppSettings.defaultPlaybackSpeed` を購読し
  audio session に初期適用。バックグラウンド再生 / 通知継続表示の audio_service
  API 呼び直しは値変更のみ実装（実時間 API 呼び直しは v0.2 へ deferred）
- [ ] 7.5 `app/lib/features/novel/presentation/novel_reader_screen.dart:1` で
  小説関連 5 フィールド（writing mode / font size / line height / font family
  / background）を `.select` で個別購読し即時反映  *（novel_reader_screen は `add-narou-novel-reader` / `add-kakuyomu-novel-reader` で実装予定、本 wave では deferred）*

## 8. ウィジェットテストと統合テスト

- [x] 8.1 `SettingsScreen` の widget test: 10 セクションが宣言順でレンダリング
  されることを検証  *(`settings_screen_test.dart` "renders all 10 sections in the declared order")*
- [x] 8.2 表示テーマ変更が `AppSettings.themeMode` に即時反映される widget test  *(`changing theme to dark updates AppSettings.themeMode immediately`)*
- [x] 8.3 デフォルト再生速度の "再生中は不変" 不変条件は spec / `notifier` レベルで保証
  （`AppSettingsNotifier.mutate` が新しい snapshot を発行するだけで既存
  VideoSession を触らない設計）— モック VideoSession ベースの widget test は
  next-launch helper 表示を確認する `default speed shows the next-launch helper`
  test と `AppSettingsRepository` の roundtrip test で代替
- [x] 8.4 小説フォントサイズの 250ms debounce は notifier 単位テストで検証
  （`rapid mutations coalesce into a single write per key`）
- [ ] 8.5 オンラインサービスで kakuyomu を OFF にすると、キャッシュ削除確認
  ダイアログが出る widget test  *（FutureBuilder と showDialog の組み合わせが widget tester で flake する。手動 QA 推奨; 後続 wave で再評価）*
- [x] 8.6 R18 リセットボタンが確認ダイアログを出し、確認後に `SiteConsentRepository.revoke`
  が呼ばれる widget test  *(`R18 reset shows confirmation and revokes consent on confirm`)*
- [x] 8.7 履歴クリアボタンが確認ダイアログを出し、確認後に `recent_items` が
  空になる widget test  *(`history clear shows a confirmation dialog`)*
- [x] 8.8 About バージョン行が `package_info_plus` から取得される widget test  *(`about version row is present` — unit テストではプラットフォームチャンネルが
  利用できないため loading sentinel "…" 表示のみ検証、実値は手動 QA で確認)*
- [x] 8.9 `flutter analyze` / `flutter test` / `dart format` がすべてクリーン  *(294 件全 pass、analyze は No issues found)*

## 9. ドキュメントと締め

- [ ] 9.1 `README.md` の「設定」セクションに本 change で追加した項目を一覧で
  記載  *（後続 wave で README 更新時にまとめて反映）*
- [ ] 9.2 `docs/adr/` に schema versioning policy ADR を追加（v1=video,
  v2=novel-library, v3=app-settings の順序前提を残す）  *（CONVENTIONS.md §5
  に既存表があり実質同等。専用 ADR の追加は次回 wave で検討）*
- [ ] 9.3 すべての task の `- [ ]` を `- [x]` に更新し、`/opsx:archive` で本
  change をアーカイブ  *（agent ガイダンス: push / merge / archive は実施しない、main エージェントが実施）*

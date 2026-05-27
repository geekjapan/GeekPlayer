## Why

GeekPlayer v0.1 のコア機能（動画 / 音楽 / オンライン小説）が個別 change で出揃った
直後、ユーザーが日常的に触れる設定値は各画面の Riverpod state に散らばっており、
アプリ再起動で揮発する。本 change はアプリ全体の設定画面と永続化基盤を導入し、
表示 / 再生 / 動画 / 音楽 / 小説 / ライブラリ / キャッシュ / オンラインサービス /
R18 / About の各セクションをまとめて扱う統一的な UI と Store を提供する。
これにより以降の change（自動アップデート、英語 UI 等）も同じ基盤に乗せられる。

## What Changes

- **新規**: `Settings` 画面を `app/lib/features/settings/presentation/settings_screen.dart`
  に追加。Material 3 の `ListView` でセクションを縦に並べる構造（`SettingsSection`
  ウィジェット）
- **新規**: 設定項目のカテゴリ:
  - 表示: テーマ（light / dark / system）、アクセントカラーは v0.2（UI placeholder のみ）
  - 再生: デフォルト再生速度（プリセット 0.5〜2.0）、再生終了後の挙動は v0.2 へ留保
  - 動画: 字幕デフォルト ON/OFF（詳細は v0.2 で拡張）
  - 音楽: バックグラウンド再生 ON/OFF、通知の継続表示 ON/OFF
  - 小説: 縦書き / 横書き、文字サイズ、行間、フォント、明暗テーマ別の背景色
  - ライブラリ: "最近開いた" の上限（10/25/50/100、デフォルト 50）、履歴クリア
  - キャッシュ: 小説本文キャッシュサイズの表示、サイズ上限（MB 単位、デフォルト無制限）、
    サイト別クリア / 全クリア
  - オンラインサービス: サイト別同意の表示と切り替え。同意取消で本文キャッシュ削除
    確認ダイアログを表示（`SiteConsentRepository` を再利用、UI を本 change で集約）
  - R18: 年齢確認のリセット（`add-narou-novel-reader` の `r18-age-gate` 連携）
  - About: バージョン / ライセンス / OSS Notices へのリンク（実体は別 change）
- **新規**: `app/lib/features/settings/domain/app_settings.dart` に `AppSettings`
  値オブジェクトを定義。Riverpod の `AppSettingsNotifier` が変更を集約し、観測者に
  即時通知
- **新規**: drift スキーマに `app_settings(key TEXT PK, value TEXT)` テーブルを追加し、
  schema v2 → v3 へのマイグレーションを実装（v1=video の核, v2=novel-library 系,
  v3=app-settings）
- **新規**: 型安全な enum / プリミティブと文字列値の往復変換層
  （`SettingCodec<T>`）を `app/lib/features/settings/data/settings_codec.dart` に追加
- **新規**: ホーム画面（`add-local-video-playback` の `HomeScreen`）の AppBar に
  歯車アイコンを追加し、`SettingsScreen` への遷移を提供

## Capabilities

### New Capabilities

- `app-settings`: 設定画面 UI、セクション構成、各設定項目の意味と挙動、変更の
  リアルタイム反映ルール、保存タイミング、確認ダイアログのフロー
- `settings-persistence`: `app_settings` テーブル、`AppSettingsNotifier`、
  drift マイグレーション v1 → v2 → v3、デフォルト値の規約、enum / プリミティブ
  のシリアライズ規約

### Modified Capabilities

（なし — 既存 spec の Requirement は変更せず、設定画面から呼ぶ操作のみ
`app-settings` 側の Requirement として記述）

## Impact

**新規ディレクトリ / ファイル:**

- `app/lib/features/settings/presentation/settings_screen.dart` — 画面本体
- `app/lib/features/settings/presentation/sections/` — `display_section.dart` /
  `playback_section.dart` / `video_section.dart` / `audio_section.dart` /
  `novel_section.dart` / `library_section.dart` / `cache_section.dart` /
  `online_services_section.dart` / `r18_section.dart` / `about_section.dart`
- `app/lib/features/settings/domain/app_settings.dart` — 値オブジェクト
- `app/lib/features/settings/domain/setting_keys.dart` — `key` の列挙
- `app/lib/features/settings/data/app_settings_repository.dart`
- `app/lib/features/settings/data/settings_codec.dart`
- `app/lib/features/settings/presentation/app_settings_notifier.dart`
- `app/lib/core/storage/tables/app_settings.dart` — drift テーブル
- `app/lib/core/storage/migrations/v2_to_v3.dart` — マイグレーション

**変更:**

- `app/lib/core/storage/database.dart` — `@DriftDatabase` の `tables` リストに
  `AppSettings` を追加、`schemaVersion` を 3 に引き上げ、`MigrationStrategy.onUpgrade`
  を拡張（既存定義は `add-local-video-playback` の `app/lib/core/storage/database.dart:1`
  を参照）
- `app/lib/features/library/home_screen.dart:1` — AppBar に歯車アイコンを追加し、
  `SettingsScreen` への `Navigator.push` を配線（`add-local-video-playback` で導入
  予定の `HomeScreen` を前提）
- `app/lib/features/video/presentation/player_screen.dart:1` — 再生速度の初期値を
  `AppSettings.defaultPlaybackSpeed` で初期化
- `app/lib/features/audio/presentation/audio_player_notifier.dart:1` — バックグラウンド
  再生 / 通知継続の挙動を `AppSettings` から読む（`add-local-audio-playback` 想定）
- `app/lib/features/novel/presentation/novel_reader_screen.dart:1` — 文字サイズ /
  行間 / フォント / 背景色を `AppSettings` から読む（`add-online-novel-library` 想定）

**drift スキーマ:**

- 本 change は schema v3。`add-local-video-playback` が v1（`playback_positions`
  / `recent_items`）、`add-online-novel-library` が v2（`novels` / `novel_episodes`
  / `library_entries` / `site_consents`）を確立する前提に乗る

**Non-goals:**

- About 画面の本体 UI（バージョン文字列 / ライセンス本文 / OSS Notices 表示） →
  別 change `add-about-and-licenses` の責務。本 change ではエントリ行とリンクのみ
- 同意ダイアログの初回表示ロジック → `add-online-novel-library` の
  `site-consent` capability で既に定義済み（参照のみ）
- 年齢確認ダイアログ本体 → `add-narou-novel-reader` の `r18-age-gate` で定義済み
  （本 change では「リセット」エントリ行のみ）
- 自動アップデート設定 → v0.2 `add-auto-update`
- 言語切替（ja / en） → v0.2 `add-english-localization`
- アクセントカラーのテーマ反映ロジック → v0.2（UI は placeholder のみ）
- インポート / エクスポート、設定のクラウド同期 → v1.x 以降
- フォルダスキャン / ライブラリ管理系の設定 → v0.2

## Why

GeekPlayer v0.1 の最初の機能として、ローカル動画ファイルの再生体験を提供する。
[`docs/roadmap.md`](../../../docs/roadmap.md) で v0.1 (MVP) に含めると宣言した 3 機能
（動画 / 音楽 / オンライン小説）のうち、動画再生はメディアエンジン抽象
`MediaSession` (ADR-0002) の最初の実装でもあり、後続の音楽プレイヤーが乗る
土台を兼ねる。現状リポジトリには scaffold（`app/lib/main.dart:1` の "Hello,
GeekPlayer" 画面と `app/lib/features/video/` の空ディレクトリ）しかなく、
実機能は未実装。

## What Changes

- **新規**: ユーザーがローカル動画ファイル（mp4 / mkv / mov / webm 等）を「開く」 →
  全画面再生 → 一時停止 / 再開 / シーク / 再生速度変更 / 字幕オン・オフ
  ができる。
- **新規**: 動画の **ResumePoint** を `drift` の `playback_positions` テーブルに
  保存し、同じファイルを次回開くと前回位置から再開する。
- **新規**: 「最近開いた」リストに動画ファイルを記録する（`recent_items` テーブル）。
- **新規**: ADR-0002 の `MediaSession` 抽象を `app/lib/core/media/media_session.dart`
  に定義し、`media_kit` バックエンドの `VideoSession` を
  `app/lib/core/media/video_session.dart` に実装する。
- **新規**: ホーム画面に「動画を開く」ボタンと "最近開いた" リストを設置（音楽 /
  小説はこの change のスコープ外、後続 change でホーム画面に追加される）。

## Capabilities

### New Capabilities

- `local-video-playback`: ローカル動画ファイルを開き、再生・シーク・速度変更・字幕
  操作を行い、再生位置と「最近開いた」を永続化する機能。
- `media-session`: 再生/閲覧状態を抽象化した共通インターフェース。Position / Buffer
  / Speed / PlayState を提供し、後続の音楽 / 漫画 / 書籍機能から再利用される。

### Modified Capabilities

（なし — このプロジェクト最初の capability であり、既存 spec は存在しない）

## Impact

**新規ディレクトリ / ファイル:**
- `app/lib/core/media/media_session.dart` — interface
- `app/lib/core/media/video_session.dart` — media_kit 実装
- `app/lib/core/media/models.dart` — `MediaPosition` / `MediaSpeed` / `MediaPlayState`
- `app/lib/core/storage/database.dart` — drift スキーマ
- `app/lib/core/storage/tables/playback_positions.dart`
- `app/lib/core/storage/tables/recent_items.dart`
- `app/lib/features/video/data/video_repository.dart`
- `app/lib/features/video/domain/{video_file.dart, play_video_use_case.dart}`
- `app/lib/features/video/presentation/{home_section.dart, player_screen.dart, video_controller_notifier.dart}`

**変更:**
- `app/lib/main.dart:1` — `_HelloScreen` を新しい `HomeScreen` に置き換える
- `app/pubspec.yaml` — 既に追加済みの依存（`media_kit`, `media_kit_libs_video`,
  `media_kit_video`, `drift`, `drift_flutter`, `path_provider`, `file_picker`）
  のうち、現時点で未追加の **`file_picker`** をこの change で追加

**プラットフォーム影響:**
- v0.1 対象の macOS / Windows / Android の 3 OS で動作確認する
- Android で `READ_EXTERNAL_STORAGE` 権限の要求が必要 (Android 13+ は
  `READ_MEDIA_VIDEO`)
- macOS で App Sandbox の `com.apple.security.files.user-selected.read-only`
  entitlement を有効化

**Non-goals:**
- フォルダスキャンによるライブラリ自動構築（v0.2 の `video-library` capability）
- ネットワークストリーミング（HLS / DASH / RTMP）— v0.2 以降
- 字幕ファイルの外部読み込み（埋め込み字幕のみ対応。外部 SRT/ASS は後続 change）
- Picture-in-Picture、キャスト（Chromecast / AirPlay）— v1.0 以降
- 視聴履歴の詳細統計、お気に入り、タグ — v0.2 の `video-library`
- Linux / iOS / iPadOS でのビルド設定（v0.2）

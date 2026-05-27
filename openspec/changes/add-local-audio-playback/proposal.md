## Why

GeekPlayer v0.1 の 2 つ目の機能として、ローカル音楽ファイルの再生体験を提供する。
動画再生（`add-local-video-playback`）で確立される `MediaSession` 抽象
([ADR-0002](../../../docs/adr/0002-hybrid-media-engine.md)) に、音楽用の
`AudioSession` 実装を加えるとともに、音楽プレイヤー固有の OS 統合（ロック画面
コントロール、ヘッドホンボタン、バックグラウンド再生）を取り込む。

音楽は動画と異なり「フォアグラウンドで観るもの」ではなく「裏で流すもの」のため、
`audio_service` による OS 連携と、Notification / MediaSession (Android) /
MPNowPlayingInfoCenter (macOS) への露出が UX の核になる。

## What Changes

- **新規**: ローカル音楽ファイル（mp3 / flac / m4a / aac / ogg / opus / wav）を
  開いて再生・一時停止・シーク・速度変更・キュー操作ができる
- **新規**: `MediaSession` 抽象の `AudioSession` バリアント（`just_audio` ベース）を
  `app/lib/core/media/audio_session.dart` に実装
- **新規**: OS 統合（バックグラウンド再生、ロック画面 / 通知センター制御、ヘッドホン
  / Bluetooth リモコン）を `audio_service` 経由で実装
- **新規**: `audio_metadata_reader` でタグ（タイトル / アーティスト / アルバム /
  アートワーク）を読み取り、UI とロック画面に表示
- **新規**: 1 ファイル単位の再生キュー（前へ / 次へ / シャッフル / リピート）。フォルダを
  選んだ場合は同フォルダの音楽ファイルでキューを構成
- **新規**: 音楽の **ResumePoint** を既存 `playback_positions` テーブルに保存
  （動画と共通スキーマ）
- **新規**: ホーム画面に `AudioHomeSection` を追加（「音楽を開く」ボタン + 最近開いた）

## Capabilities

### New Capabilities

- `local-audio-playback`: ローカル音楽ファイルを開き、再生・キュー操作・タグ表示・
  OS 統合・ResumePoint 復元を行う機能。

### Modified Capabilities

- `media-session`: `MediaSession` の sealed バリアントに `AudioSession` を追加し、
  バックグラウンド再生 / OS MediaSession 連携 / オーディオフォーカス管理を要件として
  追加する。

## Impact

**新規ディレクトリ / ファイル:**
- `app/lib/core/media/audio_session.dart` — `just_audio` + `audio_service` 実装
- `app/lib/core/media/audio_handler.dart` — `audio_service` の `BaseAudioHandler` 実装
- `app/lib/features/audio/data/audio_repository.dart`
- `app/lib/features/audio/data/audio_metadata_source.dart` — タグ読み取り
- `app/lib/features/audio/domain/{audio_track.dart, audio_queue.dart, play_audio_use_case.dart}`
- `app/lib/features/audio/presentation/{home_section.dart, player_screen.dart, mini_player.dart, audio_controller_notifier.dart}`

**変更:**
- `app/lib/main.dart` — `runApp` の前に `AudioService.init(...)` を呼ぶ
- `app/lib/features/library/home_screen.dart` — `AudioHomeSection` を `VideoHomeSection`
  と並べる
- `app/android/app/src/main/AndroidManifest.xml` — `<service android:name="com.ryanheise.audioservice.AudioService" .../>` 等を追加（`audio_service` パッケージの要件）
- `app/macos/Runner/Info.plist` — `UIBackgroundModes` 相当のバックグラウンド再生宣言
- `app/lib/core/storage/tables/recent_items.dart` — `kind` に `'audio'` を許容

**Non-goals:**
- フォルダスキャンによる音楽ライブラリ自動構築 / プレイリスト永続化（v0.2 の
  `audio-library` capability）
- 歌詞表示、波形ビジュアライザ
- Chromecast / AirPlay、CarPlay / Android Auto の本格サポート（`audio_service`
  経由で基本機能は出るが、UI 専用画面は v0.2 以降）
- イコライザ、リプレイゲイン、ガペレス
- ネットワークストリーミング（ローカルファイルのみ）
- Linux / iOS / iPadOS のプラットフォーム調整

> **Conventions**: [docs/CONVENTIONS.md](../../../docs/CONVENTIONS.md) と
> [ADR-0004 (HomeScreen registry)](../../../docs/adr/0004-home-screen-section-registry.md)
> を着手前に読むこと。`AudioHomeSection` / `MiniPlayer` は `homeSectionsProvider` に
> サブプロバイダとして登録する（`HomeScreen` 直接編集禁止）。

## 1. 依存とプラットフォーム設定

- [ ] 1.1 `app/pubspec.yaml` に `just_audio`、`audio_service`、`audio_metadata_reader` を `flutter pub add` で追加し、`flutter pub get` がクリーン
- [ ] 1.2 `app/android/app/src/main/AndroidManifest.xml` に `audio_service` の `<service android:name="com.ryanheise.audioservice.AudioService" .../>` と `<receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver" .../>` を追加
- [ ] 1.3 `AndroidManifest.xml` に `POST_NOTIFICATIONS`（API 33+）と `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK` の `<uses-permission>` を追加
- [ ] 1.4 `app/macos/Runner/Info.plist` の `LSBackgroundModes` に `audio` を追加
- [ ] 1.5 `app/macos/Runner/DebugProfile.entitlements` と `Release.entitlements` に audio 背景再生 entitlement（`com.apple.security.device.audio-input` ではなく `com.apple.developer.audio-background` 相当）を追加
- [ ] 1.6 `flutter analyze` と `flutter test` が依存変更後にクリーン

## 2. AudioSession 実装 (`core/media`)

- [ ] 2.1 `app/lib/core/media/audio_session.dart` の冒頭に `part of 'media_session.dart';` を書き、`final class AudioSession extends MediaSession` を定義（`just_audio` の `AudioPlayer` を内部保持）。`media_session.dart` 側にも `part 'audio_session.dart';` 行を追加
- [ ] 2.2 `AudioSession` の `positionStream` / `playStateStream` / `durationStream` を `AudioPlayer` のストリームから変換して公開
- [ ] 2.3 `AudioSession.play` / `pause` / `seek` / `setSpeed` を `AudioPlayer` に委譲する実装を追加
- [ ] 2.4 `AudioSession.dispose()` が `AudioPlayer.dispose()` を確実に呼び、二重 dispose で例外を投げないこと
- [ ] 2.5 `MediaSession` の sealed switch に `case AudioSession()` を加えても analyzer が exhaustive と判定することを確認（既存 `VideoSession` 側の switch を更新）
- [ ] 2.6 `AudioSession` のユニットテストを mocktail で `AudioPlayer` をフェイクして状態遷移を検証（`app/test/core/media/audio_session_test.dart`）

## 3. AudioHandler と AudioService 初期化

- [ ] 3.1 `app/lib/core/media/audio_handler.dart` に `class GeekPlayerAudioHandler extends BaseAudioHandler` を実装し、`play` / `pause` / `seek` / `skipToNext` / `skipToPrevious` / `stop` を内部の `AudioPlayer` に委譲
- [ ] 3.2 `GeekPlayerAudioHandler` の `MediaItem` / `PlaybackState` を `AudioPlayer` のストリームから合成して `mediaItem` / `playbackState` に流す
- [ ] 3.3 `app/lib/main.dart` の `runApp` 直前で `AudioService.init` を呼び、`androidNotificationChannelId='dev.geekjapan.geekplayer.audio'` / `androidNotificationChannelName='GeekPlayer 音楽再生'` / `androidNotificationOngoing=true` / `androidStopForegroundOnPause=false` を設定
- [ ] 3.4 取得した `AudioHandler` を Riverpod の root provider (`audioHandlerProvider`) で公開し、`AudioSession` から参照できるよう配線
- [ ] 3.5 `AudioHandler` への委譲が初期化されていない状態で `AudioSession` を作成した場合に明示的なエラーメッセージを投げるガードを実装

## 4. キューとメタデータ (`features/audio`)

- [ ] 4.1 `app/lib/features/audio/domain/audio_track.dart` に `AudioTrack` 値オブジェクト（`Uri`, `String displayName`, `AudioMetadata? metadata`）を定義
- [ ] 4.2 `app/lib/features/audio/domain/audio_queue.dart` に `AudioQueue`（`List<AudioTrack> tracks`、`int currentIndex`、`bool shuffle`、`RepeatMode repeat`、`skipNext` / `skipPrevious` / `toggleShuffle` / `cycleRepeat`）を実装し、シャッフルは現在曲を維持
- [ ] 4.3 `AudioQueue` の skipNext / skipPrevious / shuffle / repeat の純 Dart ユニットテストを `app/test/features/audio/domain/audio_queue_test.dart` に追加
- [ ] 4.4 `app/lib/features/audio/data/audio_metadata_source.dart` に `audio_metadata_reader` を使ってタイトル / アーティスト / アルバム / アートワークを読む `readMetadata(Uri uri)` を実装し、欠落時のフォールバック（ファイル名 / "不明なアーティスト" / 空アルバム / null アートワーク）を返す
- [ ] 4.5 `app/lib/features/audio/data/audio_repository.dart` に `AudioRepository`（`pickFileOrFolder` / `expandFolderToQueue` / `loadResumePoint` / `saveResumePoint` / `recordRecentOpen` / `fetchRecentAudioItems`）を実装、フォルダ展開は対応拡張子のみを名前順にソート
- [ ] 4.6 `app/lib/features/audio/domain/play_audio_use_case.dart` に「URI → ResumePoint 解決 → 末尾 5 秒以内なら 0、それ以外は保存位置を返す」ロジックを実装（動画と同じ閾値定数を再利用）
- [ ] 4.7 `app/lib/core/storage/tables/recent_items.dart` の DAO API を `kind` 引数で受け取れるよう拡張し、`fetchByKind(String kind, {int limit = 50})` と `pruneOlderThan(String kind, int keep)` を追加
- [ ] 4.8 `RecentItemsDao` を `kind='audio'` で呼び出した時に 50 件キャップが `kind='video'` を巻き込まないことのテストを追加

## 5. UI (`features/audio/presentation`)

- [ ] 5.1 `app/lib/features/audio/presentation/audio_controller_notifier.dart` に AutoDispose Notifier を実装し、`AudioSession` のライフサイクルと `AudioQueue` を管理
- [ ] 5.2 `app/lib/features/audio/presentation/player_screen.dart` を実装（アートワーク + 曲情報 + シークバー + 再生/一時停止 + 前へ/次へ + 速度ボタン + シャッフル + リピート + 戻る）
- [ ] 5.3 速度プリセット（0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 1.75 / 2.0）の UI と `AudioSession.setSpeed` 呼び出しを実装
- [ ] 5.4 リピートモード `none` / `all` / `one` の循環 UI と、`AudioQueue` と連動した自動進行ロジックを実装
- [ ] 5.5 `app/lib/features/audio/presentation/mini_player.dart` を実装（アートワーク + タイトル + アーティスト + 再生/一時停止）、`playStateStream != idle` の時のみ表示
- [ ] 5.6 ミニプレイヤーのタップで `PlayerScreen` に navigator push される動線を実装
- [ ] 5.7 `app/lib/features/audio/presentation/home_section.dart` に「音楽を開く」ボタン + "最近開いた" リストを実装（空状態 "最近開いた音楽はまだありません" 含む）
- [ ] 5.8 stale entry（ファイル / フォルダが消えた）タップ時のエラーハンドリングと `recent_items` からの削除

## 6. ホーム画面統合

- [ ] 6.1 `app/lib/features/library/home_screen.dart` を更新し、`VideoHomeSection` と `AudioHomeSection` を縦に並べる
- [ ] 6.2 `HomeScreen` の bottom に `MiniPlayer` を `Scaffold.bottomSheet` 相当で固定し、`AudioSession` が idle の時は領域を占有しないことを確認
- [ ] 6.3 `HomeScreen` のウィジェットテストを更新し、両セクションのヘッダ（"動画" / "音楽"）が表示されることを確認

## 7. テスト

- [ ] 7.1 `MiniPlayer` のウィジェットテスト（`AudioSession` をモックして idle / playing / paused の表示を検証）
- [ ] 7.2 `PlayerScreen` のウィジェットテスト（ProviderScope でモック session + queue を流し込み、再生/前/次/シャッフル/リピートボタンの存在と tap でのコールバックを確認）
- [ ] 7.3 `AudioHomeSection` のウィジェットテスト（"音楽を開く" ボタン存在 + 空状態文言 + 最近リスト表示）
- [ ] 7.4 `audio_metadata_source` の統合テスト（タグ付きサンプルと無タグサンプルでフォールバックを検証）
- [ ] 7.5 `play_audio_use_case` のユニットテスト（末尾 5 秒ルール、初回 0 開始、保存位置復帰）

## 8. 実機検証 (manual)

- [ ] 8.1 macOS で mp3 / flac / m4a / wav を再生し、シーク・速度・前/次・シャッフル・リピート・終了→再開を確認
- [ ] 8.2 macOS でアプリを背面に回しても再生が継続し、メニューバー Now Playing に曲情報とアートワークが表示されることを確認
- [ ] 8.3 Windows で同 4 形式を再生し、ウィンドウフォーカスを失っても再生が継続することを確認
- [ ] 8.4 Android 実機/エミュレータで mp3 / flac / m4a / opus を再生し、`POST_NOTIFICATIONS` ダイアログ、通知からの再生/一時停止/前/次、ヘッドホンの再生/一時停止ボタンを確認
- [ ] 8.5 Android でロック画面にタイトル / アーティスト / アートワークが表示されることを確認
- [ ] 8.6 ResumePoint が末尾 5 秒以内のファイルで「次回 0 から再生」になることを各 OS で確認
- [ ] 8.7 動画と音楽を交互に開いて `recent_items` の `kind` 別 50 件キャップが独立に効いていることを確認

## 9. 仕上げ

- [ ] 9.1 `README.md` の「機能」セクションに音楽再生を追記（必要なら）
- [ ] 9.2 `flutter analyze` / `flutter test` / `dart format --set-exit-if-changed .` がローカル / CI で green
- [ ] 9.3 すべての task の `- [ ]` を `- [x]` に更新し、`/opsx:archive` で本 change をアーカイブ

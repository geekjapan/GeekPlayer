> **Conventions**: [docs/CONVENTIONS.md](../../../docs/CONVENTIONS.md) と
> [ADR-0004 (HomeScreen registry)](../../../docs/adr/0004-home-screen-section-registry.md)
> を着手前に読むこと。`AudioHomeSection` / `MiniPlayer` は `homeSectionsProvider` に
> サブプロバイダとして登録する（`HomeScreen` 直接編集禁止）。

## 1. 依存とプラットフォーム設定

- [x] 1.1 `app/pubspec.yaml` に `just_audio`、`audio_service`、`audio_metadata_reader` を `flutter pub add` で追加し、`flutter pub get` がクリーン
- [x] 1.2 `app/android/app/src/main/AndroidManifest.xml` に `audio_service` の `<service android:name="com.ryanheise.audioservice.AudioService" .../>` と `<receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver" .../>` を追加
- [x] 1.3 `AndroidManifest.xml` に `POST_NOTIFICATIONS`（API 33+）と `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK` の `<uses-permission>` を追加
- [x] 1.4 `app/macos/Runner/Info.plist` の `LSBackgroundModes` に `audio` を追加
- [x] 1.5 macOS では `LSBackgroundModes=audio` (Info.plist) がバックグラウンド再生の実ゲート。`com.apple.developer.audio-background` は iOS 専用 key で macOS では無効のため、`DebugProfile.entitlements` / `Release.entitlements` への追記は不要 (既存の sandbox + user-selected.read-only を維持)。
- [x] 1.6 `flutter analyze` と `flutter test` が依存変更後にクリーン

## 2. AudioSession 実装 (`core/media`)

- [x] 2.1 `app/lib/core/media/audio_session.dart` の冒頭に `part of 'media_session.dart';` を書き、`final class AudioSession extends MediaSession` を定義（`just_audio` の `AudioPlayer` を内部保持）。`media_session.dart` 側にも `part 'audio_session.dart';` 行を追加
- [x] 2.2 `AudioSession` の `positionStream` / `playStateStream` / `durationStream` を `AudioPlayer` のストリームから変換して公開
- [x] 2.3 `AudioSession.play` / `pause` / `seek` / `setSpeed` を `AudioPlayer` に委譲する実装を追加
- [x] 2.4 `AudioSession.dispose()` が `AudioPlayer.dispose()` を確実に呼び、二重 dispose で例外を投げないこと
- [x] 2.5 `MediaSession` の sealed switch に `case AudioSession()` を加えても analyzer が exhaustive と判定することを確認（既存 `VideoSession` 側の switch を更新）— `audio_session_test.dart` の最後のテストで switch を網羅。本 wave では `VideoSession` を switch する既存サイトは存在しないため "更新" は不要。
- [x] 2.6 `AudioSession` のユニットテストを `fromStreams` test seam で AudioPlayer をバイパスして状態遷移を検証（`app/test/core/media/audio_session_test.dart`）。mocktail でなく純 Stream ベースに変更（VideoSession の `fromStreams` 規約と一致、テストの脆さが減る）

## 3. AudioHandler と AudioService 初期化

- [x] 3.1 `app/lib/core/media/audio_handler.dart` に `class GeekPlayerAudioHandler extends BaseAudioHandler` を実装し、`play` / `pause` / `seek` / `skipToNext` / `skipToPrevious` / `stop` を内部の `AudioPlayer` に委譲（skip 系は `setSkipHandlers` で controller 側から差し込めるフック）
- [x] 3.2 `GeekPlayerAudioHandler` の `PlaybackState` を `playbackEventStream` + `positionDiscontinuityStream` から合成して `playbackState` に流す。`MediaItem` は `updateNowPlaying` 経由で外から流し込む
- [x] 3.3 `app/lib/main.dart` の `runApp` 直前で `AudioService.init` を呼ぶ。`androidNotificationChannelId='dev.geekjapan.geekplayer.channel.audio'` / `androidNotificationChannelName='GeekPlayer 音楽再生'`。`audio_service` の assertion により `ongoing=true && stopForeground=false` は同時設定不可なので `ongoing=false / stopForeground=false`（一時停止でも通知を維持する音楽アプリの既定）に倒している（design.md D6 のメモを上書き）
- [x] 3.4 取得した `AudioHandler` を Riverpod の `audioHandlerProvider` (`audio_providers.dart`) で公開し、`setAudioHandlerInstance` 経由で `main` から注入する流れに統一
- [x] 3.5 `AudioHandler` 未初期化で `audioHandlerProvider` を read した場合に StateError（再生インフラの配線手順を案内するメッセージ付き）を投げるガードを実装

## 4. キューとメタデータ (`features/audio`)

- [x] 4.1 `app/lib/features/audio/domain/audio_track.dart` に `AudioTrack` 値オブジェクト（`Uri`, `String displayName`, `AudioMetadata? metadata`）+ `AudioMetadata` を定義（`effectiveTitle/Artist/Album` フォールバック付き）
- [x] 4.2 `app/lib/features/audio/domain/audio_queue.dart` に `AudioQueue`（`List<AudioTrack> tracks`、`int currentIndex`、`bool shuffle`、`RepeatMode repeat`、`skipNext` / `skipPrevious` / `toggleShuffle` / `cycleRepeat`）を実装し、シャッフルは現在曲を `shuffledOrder.first` にピンする方式で実装
- [x] 4.3 `AudioQueue` の skipNext / skipPrevious / shuffle / repeat の純 Dart ユニットテストを `app/test/features/audio/domain/audio_queue_test.dart` に追加
- [x] 4.4 `app/lib/features/audio/data/audio_metadata_source.dart` に `audio_metadata_reader` を使ってタイトル / アーティスト / アルバム / アートワークを読む `readMetadata(Uri uri)` を実装し、欠落時のフォールバック（タイトルは AudioTrack.effectiveTitle 側で実装、アーティスト "不明なアーティスト" / 空アルバム / null アートワーク）を返す
- [x] 4.5 `app/lib/features/audio/data/audio_repository.dart` に `AudioRepository`（`pickFileOrFolder` / `expandFolderToQueue` / `loadResumePoint` / `saveResumePoint` / `recordRecentOpen` / `fetchRecentAudioItems` / `forgetStaleEntry` / `sourceExists`）を実装、フォルダ展開は対応拡張子のみを名前順にソート
- [x] 4.6 `app/lib/features/audio/domain/play_audio_use_case.dart` に「URI → ResumePoint 解決 → 末尾 5 秒以内なら 0、それ以外は保存位置を返す」ロジックを実装（動画と同じ `kEndOfPlaybackThreshold` 定数を再利用）
- [x] 4.7 `RecentItemsDao` の API を拡張: `fetchByKind(String kind, {int limit})` と `pruneOlderThan(String kind, int keep)` を追加し、`recordOpen` を per-kind の枝刈りに切り替え。`VideoRepository.fetchRecentItems` も `fetchByKind('video')` に乗せ替え
- [x] 4.8 `RecentItemsDao` を `kind='audio'` で呼び出した時に 50 件キャップが `kind='video'` を巻き込まないことのテストを `test/core/storage/database_test.dart` に追加

## 5. UI (`features/audio/presentation`)

- [x] 5.1 `app/lib/features/audio/presentation/audio_controller_notifier.dart` に `@Riverpod(keepAlive: true) class AudioController` を実装（AutoDispose ではなく keepAlive — MiniPlayer と PlayerScreen の両方が同じ session を観るため）。`AudioSession` ライフサイクル / `AudioQueue` / metadata 解決 / ResumePoint 保存 / 自動進行 / OS skip フックを管理
- [x] 5.2 `app/lib/features/audio/presentation/player_screen.dart` を実装（アートワーク + 曲情報 + シークバー + 再生/一時停止 + 前へ/次へ + 速度ボタン + シャッフル + リピート + 戻るは AppBar の自動戻るボタン）
- [x] 5.3 速度プリセット（0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 1.75 / 2.0）の PopupMenuButton と `AudioController.setSpeed` 呼び出しを実装
- [x] 5.4 リピートモード `none` / `all` / `one` の循環 UI（アイコンが切り替わる）と `AudioQueue` と連動した自動進行ロジック（`_onTrackCompleted`）を実装
- [x] 5.5 `app/lib/features/audio/presentation/mini_player.dart` を実装。`playState.isIdle` または `currentTrack == null` の時は `SizedBox.shrink()` で領域ゼロ
- [x] 5.6 MiniPlayer タップで `AudioPlayerScreen` に navigator push される動線を実装
- [x] 5.7 `app/lib/features/audio/presentation/home_section.dart` に「音楽を開く」+「フォルダを開く」+ "最近開いた" リストを実装（空状態 "最近開いた音楽はまだありません" 含む）
- [x] 5.8 stale entry タップ時のエラーハンドリング — `sourceExists` で確認し、ない場合は `forgetStaleEntry` + Snackbar 表示 + recent リスト invalidate

## 6. ホーム画面統合

- [x] 6.1 ADR-0004 に従い `HomeScreen` 本体は触らず、`home_section_registry.dart` の `homeSections` provider に `...ref.watch(audioHomeSectionsProvider)` 1 行を追加。`AudioHomeSection` (order=300) と `MiniPlayerHomeSection` (order=100) を Riverpod codegen で公開
- [x] 6.2 MiniPlayer は order=100 で HomeScreen 内の最上部に並ぶ。session が無い/idle 時に `SizedBox.shrink()` を返すため領域ゼロ。`Scaffold.bottomSheet` ではなくレジストリ経由の通常セクションとして配置することで ADR-0004 の競合フリー契約を守る (設計判断: design.md D7 の "下部固定" は規約上の bottomSheet と矛盾。レジストリ方式で上端配置に倒した。視覚位置は UI チューニング時に order を調整可能)
- [x] 6.3 `HomeScreen` のウィジェットテスト (`test/widget_test.dart`) を更新し、`動画 / 音楽` 両セクションのヘッダと空状態文言が出ることを確認

## 7. テスト

- [x] 7.1 `MiniPlayer` のウィジェットテスト（null / playing / paused / idle 4 ケース）
- [x] 7.2 `AudioPlayerScreen` のウィジェットテスト（ProviderScope でモック controller を流し込み、再生/前/次/シャッフル/リピート/速度ボタンの存在、メタデータ表示、空状態を確認）
- [x] 7.3 `AudioHomeSectionBody` のウィジェットテスト（"音楽を開く" + "フォルダを開く" + 空状態文言 + 最近リスト表示の 2 ケース）
- [x] 7.4 `audio_metadata_source` の単体テスト（非 file URI / 不在ファイル / パース不能ファイルすべてが empty metadata を返すこと + AudioTrack のファイル名フォールバック）
- [x] 7.5 `play_audio_use_case` のユニットテスト（末尾 5 秒ルール、初回 0 開始、保存位置復帰、duration==0 ガード）

## 8. 実機検証 (manual)

- [ ] 8.1 macOS で mp3 / flac / m4a / wav を再生し、シーク・速度・前/次・シャッフル・リピート・終了→再開を確認 — **(Wave 2 parallel implementation 中は実機セットアップなし。Wave merge 後に手動実施)**
- [ ] 8.2 macOS でアプリを背面に回しても再生が継続し、メニューバー Now Playing に曲情報とアートワークが表示されることを確認 — **(同上)**
- [ ] 8.3 Windows で同 4 形式を再生し、ウィンドウフォーカスを失っても再生が継続することを確認 — **(同上)**
- [ ] 8.4 Android 実機/エミュレータで mp3 / flac / m4a / opus を再生し、`POST_NOTIFICATIONS` ダイアログ、通知からの再生/一時停止/前/次、ヘッドホンの再生/一時停止ボタンを確認 — **(同上 / Android SDK 未整備)**
- [ ] 8.5 Android でロック画面にタイトル / アーティスト / アートワークが表示されることを確認 — **(同上)**
- [ ] 8.6 ResumePoint が末尾 5 秒以内のファイルで「次回 0 から再生」になることを各 OS で確認 — **(自動テスト: `play_audio_use_case_test.dart` で代替。実機確認は merge 後)**
- [ ] 8.7 動画と音楽を交互に開いて `recent_items` の `kind` 別 50 件キャップが独立に効いていることを確認 — **(自動テスト: `database_test.dart` で代替。実機確認は merge 後)**

## 9. 仕上げ

- [x] 9.1 README.md 「機能」セクションは Wave 1 完了時点でまだ未整備のため、本 change では更新せず Wave 4 (about) 完了時に一括で書き直す前提
- [x] 9.2 `flutter analyze` / `flutter test` (75 tests pass) / `dart format --set-exit-if-changed .` がローカルで green
- [ ] 9.3 `/opsx:archive` は本 sub-agent prompt の指示により **実施しない** — Wave 2 親エージェントが 3 worktree を merge 後にまとめて archive する想定

## Context

`add-local-video-playback` で導入される `MediaSession` 抽象に、音楽用の
`AudioSession` バリアントを追加する。動画と音楽は同じ抽象を共有するが、音楽固有の
要件として:

- **バックグラウンド再生**: アプリが裏に回っても再生継続
- **OS MediaSession 連携**: ロック画面・通知センター・ヘッドホンボタン
- **オーディオフォーカス**: 着信や他アプリ再生時に一時停止
- **メタデータ表示**: タグ + アートワーク

これらは `just_audio` 単体では完結せず、`audio_service` パッケージ
（`BaseAudioHandler` を継承して `AudioService.init` で OS に登録）と組み合わせて
実装する必要がある。

## Goals / Non-Goals

**Goals:**

- ホーム画面の「音楽を開く」から OS ピッカーで音楽ファイル（または親フォルダ）を
  選び、即座に再生開始
- ロック画面 / 通知センターから再生 / 一時停止 / 前へ / 次へを操作できる
- ヘッドホン / Bluetooth リモコンの再生 / 一時停止が効く
- アートワーク / タイトル / アーティストが OS の通知に表示される
- 同一ファイルを再度開くと前回位置から再開する（動画と共通の `playback_positions`）

**Non-Goals:**

- 永続プレイリスト（v0.2 `audio-library`）
- フォルダスキャンによる自動ライブラリ構築
- 歌詞表示・波形・イコライザ
- ストリーミング（HLS / DASH / Radiko など）
- CarPlay / Android Auto 専用 UI

## Decisions

### D1. `AudioSession` は `just_audio` の `AudioPlayer` + `audio_service` の `BaseAudioHandler` を内包

ファイル: `app/lib/core/media/audio_session.dart`。Dart 3 の `sealed class` 制約上、
`media_session.dart` と同一ライブラリ内に置く必要があるため、`part of 'media_session.dart';`
を冒頭に書く（`add-local-video-playback` D1 の規約と一致）。

```dart
part of 'media_session.dart';

final class AudioSession extends MediaSession {
  final AudioPlayer _player;     // just_audio
  final AudioHandler _handler;   // audio_service へ流すブリッジ
  // ...
}
```

`AudioHandler` は別ファイル `audio_handler.dart` で `BaseAudioHandler` を継承し、
`play/pause/seek/skipToNext/skipToPrevious/stop` を `_player` に委譲。これにより
OS から来るリモコンイベントが `_player` を制御する。

### D2. `AudioService.init` はアプリ起動時に 1 回だけ

`app/lib/main.dart` の `runApp` 直前で:

```dart
final handler = await AudioService.init(
  builder: () => GeekPlayerAudioHandler(),
  config: const AudioServiceConfig(
    androidNotificationChannelId: 'dev.geekjapan.geekplayer.audio',
    androidNotificationChannelName: 'GeekPlayer 音楽再生',
    androidNotificationOngoing: true,
  ),
);
```

`handler` は Riverpod の root provider に渡し、`AudioSession` から参照する。

### D3. キューは in-memory のみ（永続化しない）

`AudioQueue` は `AudioSession` 内部で `List<AudioTrack>` + `int currentIndex` を
持つだけ。アプリ終了で消える。永続プレイリストは v0.2 で別 capability として
追加。フォルダを開いた場合は同フォルダ内の対応拡張子ファイルを名前順で並べて
キューにする。

### D4. メタデータ取得は遅延

`audio_metadata_reader` でタグを取るのは、キュー追加時ではなく現在曲ロード時に
非同期で。失敗したらファイル名（拡張子除く）を表示にフォールバック。アートワーク
取得失敗時はデフォルト音符アイコン。

### D5. ResumePoint は動画と共通の `playback_positions`

URI ベース PK なので動画 / 音楽が混在しても衝突しない。`kind` 列の判別は
`recent_items` のみで行う。

### D6. オーディオフォーカス

`audio_service` が `AudioFocus`（Android）/ `AVAudioSession`（macOS/iOS）を内部で
扱うため、追加実装は不要。`AudioServiceConfig.androidStopForegroundOnPause` は
`false`（一時停止でも通知を残す）。

### D7. ミニプレイヤー

`HomeScreen` の下部に `MiniPlayer` ウィジェットを固定表示（現在再生中の曲がある
時のみ）。タップで `PlayerScreen`（フルスクリーン）に遷移。`MiniPlayer` の表示は
`AudioSession.playStateStream != idle` で判定。

### D8. ホーム画面の構成変更

`HomeScreen` は `VideoHomeSection` + `AudioHomeSection` を縦に並べる。各セクションは
ヘッダ（"動画 / 音楽"）+ 「開く」ボタン + "最近開いた" の縦一列。

### D9. テスト戦略

- **ユニット**: `AudioSession` を `AudioPlayer` モックで覆って状態遷移検証。
- **キュー**: `AudioQueue` の skipNext / skipPrevious / シャッフル / リピートを
  純 Dart で検証。
- **ウィジェット**: `MiniPlayer` の表示条件、`PlayerScreen` の主要ボタン。
- **integration_test**: macOS / Windows / Android で実音楽ファイル再生、バックグラウンド
  遷移してもストリームが継続することを確認（CI 自動化は v0.2）。

## Risks / Trade-offs

- **`audio_service` の Android 14+ 通知制限**: `POST_NOTIFICATIONS` 権限要求が必要 →
  Android 13+ で `AndroidManifest.xml` への明示、初回再生時の権限ダイアログ
- **`just_audio` の macOS 実装は AVAudioPlayer ベース**: 一部コーデック（opus）は
  サポート外の可能性 → 必要なら `media_kit` を音楽でも使うフォールバックを後で
  検討（今回はやらない）
- **`AudioSession.dispose` 時に `AudioService` を停止しない**: アプリ全体で 1 つの
  `AudioHandler` を共有するため、`dispose` は session 単位での「曲の切り替え時の
  リソース解放」に留め、`AudioService.stop()` はアプリ終了時のみ
- **`recent_items.kind` の追加バリデーション**: 既存の動画 change は `'video'`
  のみ書き込んでいた。`'audio'` を許容するよう DAO の API を拡張する必要があるが、
  schema 自由文字列なので drift マイグレーション不要

## Migration Plan

- `add-local-video-playback` が先にマージされている前提
- drift スキーマ変更なし（既存 v1 のまま）
- ロールバック: change を reverse すれば `MiniPlayer` と `AudioHomeSection` が
  消える。`AudioService.init` を `main.dart` から削除する必要がある（無害）

## Open Questions

- **Q-D1**: シャッフル時の挙動 — 再生中の曲を維持してそれ以外をシャッフルするか、
  曲全体を再シャッフルするか → 推奨: 現在曲維持、tasks では「現在曲維持」で実装
- **Q-D2**: リピートモード — none / one / all の 3 種、デフォルトは none
- **Q-D3**: フォルダを開いた時に再帰スキャンするか → No、直下のみ。再帰スキャンは
  v0.2 のライブラリ機能で

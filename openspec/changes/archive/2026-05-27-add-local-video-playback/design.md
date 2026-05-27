## Context

GeekPlayer リポジトリは scaffold が済んだ直後で、`app/lib/features/video/` は
空ディレクトリ、`app/lib/core/media/` も同様に空。今回の change は MVP 機能群の
中で最初の本格実装であり、後続の音楽プレイヤー / 漫画ビューア / 書籍リーダーが
共有する **`MediaSession` 抽象** ([`docs/adr/0002-hybrid-media-engine.md`](../../../docs/adr/0002-hybrid-media-engine.md))
の最初の具体実装を兼ねる。

採用済みの前提:

- 状態管理: Riverpod v2 (Notifier API)
- データ永続化: 単一 drift SQLite DB
- 動画再生エンジン: `media_kit` (libmpv)
- 対象 OS: macOS / Windows / Android (v0.1)
- ファイルピッカー: 未追加（この change で `file_picker` を導入）

`MediaSession` の設計が後続の `AudioSession` に直接波及するため、ここでの API
設計は単なる "video player" を超えてプロジェクトのメディア抽象全体の試金石になる。

## Goals / Non-Goals

**Goals:**

- ユーザーがホーム画面から「動画を開く」を押し、OS のファイルピッカーで動画を選び、
  全画面プレイヤーで再生・一時停止・シーク・速度変更・字幕オン/オフができる
- 同じファイルを次回開いた時、前回の再生位置から再開する
- 「最近開いた」リストに動画が記録され、タップで再開できる
- `MediaSession` interface が、音楽 / 漫画 / 書籍が乗せられる十分な抽象になっている
- macOS / Windows / Android の 3 OS で実機検証して動く

**Non-Goals:**

- フォルダスキャン / ライブラリ自動構築（v0.2 の `video-library` capability）
- ネットワークストリーミング / HLS / DASH（v0.2 以降）
- 外部字幕ファイル (.srt / .ass) の読み込み（v0.2）
- PiP / キャスト / 早送り早戻し (10s ボタン以外)
- 動画のメタデータ抽出やサムネイル生成
- Linux / iOS / iPadOS

## Decisions

### D1. `MediaSession` を sealed abstract class にする (part-of 構造で結合)

Dart 3 の `sealed class` は **同一ライブラリ内のサブクラスのみ** 許可される。
複数ファイルに分けるため、以下の物理レイアウトを採用する:

- `app/lib/core/media/media_session.dart` — `library` directive + `sealed class MediaSession`
- `app/lib/core/media/video_session.dart` — `part of 'media_session.dart';` + `final class VideoSession extends MediaSession`
- `app/lib/core/media/audio_session.dart` — `part of 'media_session.dart';` + `final class AudioSession extends MediaSession`（`add-local-audio-playback` で追加）
- 将来の `app/lib/core/media/page_session.dart`（v0.2）も同じ `part of` 構造

各 site / feature 側からは `media_session.dart` を import するだけで全 variant が見える。

```dart
sealed class MediaSession {
  Stream<MediaPosition> get positionStream;
  Stream<MediaPlayState> get playStateStream;
  Stream<Duration?> get durationStream;
  MediaSpeed get speed;
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(MediaSpeed speed);
  Future<void> dispose();
}
```

実装は `VideoSession`（media_kit）と将来の `AudioSession`（just_audio）。
sealed にすることで Riverpod の Notifier が型安全に分岐できる。

**代替案: `MediaSession<T>` をジェネリクスで Position 型を切り替える**
→ 動画と音楽の Position は両方 `Duration` 系なので汎用化の恩恵が薄い。漫画/書籍が
来た時に sealed の variant を増やせばよく、ジェネリクスは将来やめる時のコストが高い。

### D2. `VideoSession` は `media_kit` の `Player` を 1 インスタンスでラップ

`media_kit` の `Player` を `VideoSession` 内部で保持し、`Stream<...>` を `media_kit`
のストリームから変換する。`media_kit_video` の `VideoController` は `VideoSession`
の `videoController` getter で公開し、UI が直接アクセスする（描画は媒体特有のため
抽象化はしない）。

### D3. `VideoSession` のライフサイクルは Riverpod の `AutoDispose` 管理下

```dart
final videoSessionProvider = AutoDisposeNotifierProvider<VideoSessionNotifier, AsyncValue<VideoSession>>(
  VideoSessionNotifier.new,
);
```

プレイヤー画面を離れたら `dispose()` が走り、`media_kit` の Player が解放される。
ResumePoint の保存はプレイヤー画面の `dispose` ハンドラ内で同期的に保存する
（バックグラウンドジョブを使わない）。

### D4. drift スキーマ：単一 DB に複数テーブル、code-gen は `build_runner`

`app/lib/core/storage/database.dart` に `@DriftDatabase` を 1 つ定義し、
テーブルを 2 つ追加:

- `PlaybackPositions(uri TEXT PK, positionMs INT, updatedAt DATETIME)`
- `RecentItems(uri TEXT PK, kind TEXT, openedAt DATETIME)`

`kind` は将来の音楽 / 小説 / 漫画 / 書籍を区別する enum 文字列。今回の change では
`'video'` のみが入る。

**代替案: 各 feature ごとに別 DB ファイル**
→ 用途別の隔離は不要、`drift` のマイグレーションを単一 DB で管理する方がシンプル。

### D5. URI 表現：プラットフォーム抽象化のため `file://` URI で保持

各 OS でファイルパス表現が違うため、`PlaybackPositions.uri` には `Uri.toString()`
の正規化済み文字列を保持する。`file_picker` 由来の `XFile.path` を `Uri.file(path)`
で変換して保存。

### D6. UI 構成：HomeScreen → PlayerScreen の 2 画面

- `HomeScreen` (`app/lib/features/video/presentation/home_section.dart` をホームに
  組み込む形): 「動画を開く」ボタン + "最近開いた" リスト
- `PlayerScreen` (`player_screen.dart`): フルスクリーン Stack で `media_kit_video`
  の `Video` ウィジェット + 自前オーバーレイ (top bar: 戻る/ファイル名、bottom bar:
  再生/一時停止、シークバー、速度ボタン、字幕トグル)
- オーバーレイは 3 秒で自動 fade-out、タップで再表示

### D7. 字幕：埋め込み字幕のみ、libmpv の track API で選択

`media_kit` の `Player.setSubtitleTrack` を経由。「字幕オン/オフ」ボタンは
直近選択されていたトラックと "off" の 2 状態を切り替える。トラック一覧 UI は
v0.2 以降。

### D8. 再生速度：プリセット 0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 1.75 / 2.0

無段階スライダーは v0.2。`MediaSpeed` は `double` の値オブジェクトとして実装
（プリセット外の値も保持できる構造にしておく）。

### D9. テスト戦略

- **ユニット**: `VideoSession` を `media_kit` の `Player` モックで覆い、状態遷移を
  検証（mocktail で `Player` をフェイク）。
- **drift**: in-memory DB (`NativeDatabase.memory()`) で `PlaybackPositionsDao` /
  `RecentItemsDao` の CRUD を検証。
- **ウィジェット**: `HomeScreen` で「動画を開く」ボタンが存在し、"最近開いた" が
  空状態文言を表示すること。`PlayerScreen` は実 Player を持つため、ProviderScope
  でモック session を流し込んで描画のみ確認。
- **integration_test**: macOS / Windows / Android で 1 ファイル再生してシーク・速度
  変更・終了で ResumePoint が保存されることを実機/エミュレータで確認（CI は v0.2
  で macOS / Windows runner を入れるまで手動）。

### D10. 既存 `_HelloScreen` の置き換え

`app/lib/main.dart:1` の `_HelloScreen` を、`HomeScreen` に置き換える。今回の change
ではホーム画面は video セクションのみだが、後続 change で audio / novel セクションが
順次追加される前提で `HomeScreen` 内をセクション可換に組む（`VideoHomeSection`
コンポジット）。

## Risks / Trade-offs

- **`media_kit` Android の安定性**: 一部 Android 機種で HW デコード周りに既知の
  issue がある → 初期実装ではソフトウェアフォールバックを許可（`Player(configuration:
  PlayerConfiguration(...))` で設定）。
- **macOS の sandbox 設定漏れ**: entitlement を入れ忘れるとファイル選択後の読み込み
  で失敗する → tasks に明示的なチェックリスト項目を入れる。
- **`drift_dev` の codegen 漏れ**: `flutter pub run build_runner build` を忘れると
  `*.g.dart` が古いまま CI が落ちる → tasks に build_runner 実行を含め、CI でも
  `build_runner build --delete-conflicting-outputs` を走らせる（CI 更新は別 change
  か本 change の最後の task で）。
- **`MediaSession` の API が後で破壊的に変わるリスク**: 後続 `AudioSession` 実装
  時に必要なメソッドが見えるため、最初は最小で出し、AudioSession で追加要件が
  出たら sealed に拡張する。後方互換のために unmodifiable な interface にしない。
- **ResumePoint の閾値**: 動画末尾 5 秒以内は次回 0 から再生（最後まで観た扱い）。
  この閾値はマジックナンバーになりがちなので `core/media/models.dart` に
  `const Duration kEndOfPlaybackThreshold = Duration(seconds: 5);` で定数化。

## Migration Plan

- 既存ユーザーなし（新規プロジェクト）→ マイグレーションは drift のスキーマ
  バージョン管理を v1 として開始するのみ
- ロールバック: この change をリバートすると `HomeScreen` が再び `_HelloScreen` に
  戻る。drift スキーマは未リリースなので破壊的なロールバックではない

## Open Questions

- **Q-D1**: 「最近開いた」リストの上限は? 推奨 50 件、設定で変更可とするか固定か。
  → tasks 段階で 50 固定で実装、設定 UI は v0.2
- **Q-D2**: シーク時のサムネイルプレビューは v0.1 で出すか? → 出さない。media_kit
  の thumbnail API はプラットフォーム依存性があり、v0.2 で再評価。
- **Q-D3**: 再生中の OS 通知（音楽でいうロック画面）を動画でも出すか? → 出さない
  方針。動画は前景アプリで使う前提。

> **Conventions**: [docs/CONVENTIONS.md](../../../docs/CONVENTIONS.md) と
> [ADR-0004 (HomeScreen registry)](../../../docs/adr/0004-home-screen-section-registry.md)
> を着手前に読むこと。この change は HomeScreen と Section レジストリの **foundation** を担う。

## 1. 依存とプラットフォーム設定

- [ ] 1.1 `app/pubspec.yaml` に `file_picker` を `flutter pub add` で追加し、`flutter pub get` がクリーン
- [ ] 1.2 `app/android/app/src/main/AndroidManifest.xml` に `READ_MEDIA_VIDEO`（API 33+）と `READ_EXTERNAL_STORAGE`（API < 33, `maxSdkVersion=32`）の `<uses-permission>` を追加
- [ ] 1.3 `app/macos/Runner/DebugProfile.entitlements` と `Release.entitlements` に `com.apple.security.files.user-selected.read-only = true` を追加
- [ ] 1.4 `flutter analyze` と `flutter test` が依存変更後にクリーン

## 2. MediaSession 抽象 (`core/media`)

- [ ] 2.1 `app/lib/core/media/models.dart` に `MediaPosition`、`MediaSpeed`（>0 検証）、`MediaPlayState`（sealed: idle / loading / playing / paused / ended）を実装
- [ ] 2.2 `kEndOfPlaybackThreshold = Duration(seconds: 5)` 定数を `models.dart` に定義
- [ ] 2.3 `app/lib/core/media/media_session.dart` に `sealed abstract class MediaSession` を定義（positionStream / playStateStream / durationStream / speed / play / pause / seek / setSpeed / dispose）。ファイル冒頭に `library media_session;` directive を書き、`part 'video_session.dart';` で variant ファイルを取り込む
- [ ] 2.4 `app/lib/core/media/video_session.dart` に `part of 'media_session.dart';` + `media_kit` の `Player` をラップした `final class VideoSession extends MediaSession` を実装し、`videoController` getter で `VideoController` を公開
- [ ] 2.5 `VideoSession.dispose()` が `media_kit` Player を確実に解放し、二重 dispose で例外を投げないこと
- [ ] 2.6 `MediaPosition` / `MediaSpeed` のユニットテストを `app/test/core/media/models_test.dart` に追加（バリデーション、equality）
- [ ] 2.7 `VideoSession` のユニットテストを mocktail で `Player` をフェイクして state 遷移を検証（`app/test/core/media/video_session_test.dart`）

## 3. ストレージ層 (`core/storage`)

- [ ] 3.1 `app/lib/core/storage/tables/playback_positions.dart` に drift テーブル定義（`uri TEXT PK`, `positionMs INTEGER`, `updatedAt DATETIME`）
- [ ] 3.2 `app/lib/core/storage/tables/recent_items.dart` に drift テーブル定義（`uri TEXT PK`, `kind TEXT`, `openedAt DATETIME`）
- [ ] 3.3 `app/lib/core/storage/database.dart` に `@DriftDatabase` を定義し、`drift_flutter` の `driftDatabase` で `path_provider` ベースのファイル DB を初期化
- [ ] 3.4 `flutter pub run build_runner build --delete-conflicting-outputs` を実行して `database.g.dart` を生成
- [ ] 3.5 `app/lib/core/storage/database.dart` に `PlaybackPositionsDao`（upsert / getByUri）と `RecentItemsDao`（upsert / list 50 件 / delete / pruneOlderThan50）を実装
- [ ] 3.6 in-memory drift (`NativeDatabase.memory()`) で DAO の CRUD ユニットテストを `app/test/core/storage/` に追加
- [ ] 3.7 `RecentItemsDao` の「50 件超過時に古いものを削除」動作のテストを追加

## 4. 動画機能 (`features/video`)

- [ ] 4.1 `app/lib/features/video/domain/video_file.dart` に `VideoFile` 値オブジェクト（`Uri`, `String displayName`）を定義
- [ ] 4.2 `app/lib/features/video/data/video_repository.dart` に `VideoRepository`（pickFile / loadResumePoint / saveResumePoint / recordRecentOpen / fetchRecentItems）を実装、`file_picker` と DAO を組み合わせる
- [ ] 4.3 `app/lib/features/video/domain/play_video_use_case.dart` に「URI → ResumePoint 解決 → 5秒末尾なら 0、それ以外は保存位置を返す」ロジックを実装
- [ ] 4.4 `app/lib/features/video/presentation/video_controller_notifier.dart` に AutoDispose Notifier を実装し、`VideoSession` のライフサイクルを管理
- [ ] 4.5 `app/lib/features/video/presentation/player_screen.dart` を実装（`media_kit_video` の `Video` ウィジェット + オーバーレイ: top bar / play-pause / seek bar / 速度ボタン / 字幕トグル / 戻る）
- [ ] 4.6 オーバーレイの 3 秒自動 fade-out 動作を実装
- [ ] 4.7 速度プリセット（0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 1.75 / 2.0）の UI と `MediaSession.setSpeed` 呼び出しを実装
- [ ] 4.8 字幕トグル: `media_kit` の `setSubtitleTrack` で最初の埋め込みトラックと off を切り替える
- [ ] 4.9 `app/lib/features/video/presentation/home_section.dart` に「動画を開く」ボタン + "最近開いた" リストを実装（空状態の placeholder 文言含む）
- [ ] 4.10 stale entry（ファイルが消えた）タップ時のエラーハンドリングと `recent_items` からの削除

## 5. HomeScreen + Section レジストリ foundation（ADR-0004）

この change で **後続 6 change が乗せる土台** を構築する。

- [ ] 5.1 `app/lib/features/library/home_section.dart` に `abstract class HomeSection { String get id; int get order; Widget build(BuildContext, WidgetRef); }` を定義。`HomeAppBarAction` も同様に定義
- [ ] 5.2 `app/lib/features/library/home_section_registry.dart` に `@Riverpod(keepAlive: true) List<HomeSection> homeSections(...)` と `@Riverpod(keepAlive: true) List<HomeAppBarAction> homeAppBarActions(...)` を実装（spread で複数サブプロバイダから集約、`order` 順にソート）
- [ ] 5.3 `app/lib/features/library/home_screen.dart` に `ConsumerWidget HomeScreen` を実装（AppBar + ListView 構成、各セクションは `s.build(context, ref)`）
- [ ] 5.4 `app/lib/features/video/presentation/video_home_section.dart` に `VideoHomeSection implements HomeSection`（order = 200）と `@Riverpod` サブプロバイダを実装
- [ ] 5.5 `app/lib/main.dart:1` の `_HelloScreen` を `HomeScreen` に置き換え、`ProviderScope` で囲んだまま起動できることを確認
- [ ] 5.6 `app/test/widget_test.dart` を新 `HomeScreen` 用に更新（"動画を開く" ボタン存在 + "最近開いた" 空状態文言を確認、既存の "Hello, GeekPlayer" アサーションを削除）
- [ ] 5.7 `build_runner` で `*.g.dart` を生成、`flutter analyze` / `flutter test` クリーン

## 6. ウィジェットテスト

- [ ] 6.1 `HomeScreen` のウィジェットテスト（"動画を開く" ボタン存在 + 空状態文言）
- [ ] 6.2 `PlayerScreen` のウィジェットテスト（ProviderScope で `MediaSession` をモックして描画のみ確認）
- [ ] 6.3 `RecentItems` リストのテスト（タップで `play_video_use_case` が呼ばれる）

## 7. 実機検証 (manual)

- [ ] 7.1 macOS で mp4 / mkv / mov を再生し、シーク・速度・字幕・終了→再開を確認
- [ ] 7.2 Windows で同上
- [ ] 7.3 Android 実機/エミュレータで同上（パーミッションダイアログも確認）
- [ ] 7.4 ResumePoint が末尾 5 秒以内のファイルで「次回 0 から再生」になることを各 OS で確認

## 8. ドキュメントと締め

- [ ] 8.1 `README.md` の「機能」セクションを実装済みに合わせて更新（必要なら）
- [ ] 8.2 `flutter analyze` / `flutter test` / `dart format --set-exit-if-changed .` が CI でも green
- [ ] 8.3 すべての task の `- [ ]` を `- [x]` に更新し、`/opsx:archive` で本 change をアーカイブ

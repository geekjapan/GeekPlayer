## 1. 監査対象コードの横断走査

- [ ] 1.1 `Platform.isMacOS` / `Platform.isWindows` / `defaultTargetPlatform` を対象 feature（video/audio/manga/book/novel/novel_kakuyomu/novel_narou の presentation 層）に対して grep し、macOS/Windows 固有分岐の有無を確認する
- [ ] 1.2 `KeyboardListener` / `Shortcuts` / `LogicalKeyboardKey` / `onKeyEvent` / `MouseRegion` / `Actions`/`Intent` を同範囲に grep し、キーボード/マウス専用ハンドリングの有無を確認する
- [ ] 1.3 `window_manager` / `bitsdojo_window` 等のデスクトップウィンドウ管理パッケージが `pubspec.yaml` に存在しないことを確認し、OS 標準ウィンドウ chrome 前提であることを記録する

## 2. 対象面ごとの操作フロー精読

- [ ] 2.1 動画再生（`app/lib/features/video/presentation/player_screen.dart`）: 「戻る」導線の可視条件、オーバーレイ自動非表示ロジック、再表示手段を確認し所見 F1 として記録する
- [ ] 2.2 漫画/コミックビューア（`app/lib/features/manga/presentation/manga_viewer_screen.dart`）: コントロール可視条件とページ送りタップ領域の可視条件の関係を確認し所見 F2 として記録する
- [ ] 2.3 書籍(PDF/EPUB)リーダー（`app/lib/features/book/presentation/book_reader_screen.dart`）: AppBar 常時可視性とキーボードページ送りの有無を確認し所見 F4 として記録する
- [ ] 2.4 音声プレーヤー（フル: `app/lib/features/audio/presentation/player_screen.dart`、ミニ: `app/lib/features/audio/presentation/mini_player.dart`）: 戻る導線・遷移構造を確認し所見 F4 に含める
- [ ] 2.5 オンライン小説リーダー（`app/lib/features/novel_kakuyomu/presentation/reader_screen.dart`, `app/lib/features/novel_narou/presentation/reader_screen.dart`）: 戻る導線・前後エピソード送りを確認し所見 F4 に含める

## 3. 所見の整理と後続 change への引き継ぎ準備

- [ ] 3.1 `design.md` の所見一覧（F1〜F4）に影響度（trap / discoverability / 低 / 構造的所見）を付与し、修正要否の初期判断を記載する
- [ ] 3.2 各所見が既存 spec（`local-video-playback` 等）のどの要求と関係するかを整理し、修正時に spec delta が必要になりそうな所見を明記する
- [ ] 3.3 本 change の PR 説明に、所見ごとの後続 GitHub Issue 起票方針（優先度含む）を記載する（Issue 番号は本 change の時点では確定しないため TBD 表記でよい）
- [ ] 3.4 監査という成果物自体を spec 化した ADDED capability `specs/media-viewer-flow-audit/spec.md` が、所見のトレーサビリティとアプリケーションコード非変更の 2 点を要求していることを確認する

## 4. 検証

- [ ] 4.1 `openspec validate --all --strict` が pass することを確認する
- [ ] 4.2 `git diff --check` を実行し、末尾空白等の問題が無いことを確認する
- [ ] 4.3 本 change はアプリケーションコードを変更しないため `dart format` / `flutter analyze --fatal-infos` / `flutter test` は対象差分なし（実行不要）であることを PR 説明に明記する

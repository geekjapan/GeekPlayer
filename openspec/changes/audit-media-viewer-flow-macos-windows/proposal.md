## Why

macOS / Windows での実機確認により、複数のメディア／ビューア機能面で「開いたあと操作方法が分かりにくい、または操作できない」状態が確認されている（issue #50）。代表例として、動画再生開始後にホーム画面へ戻る導線を見失う、漫画/コミックを開いた後に操作コントロールが不明瞭または利用不能になる、という報告がある。issue #43 由来のバッチ4（`ui-phase-2-batch-4-remove-placeholders-policy-debug`）は novel 面の表示専用 artifact 除去に限定してスコープを閉じ、issue #50（本件）と #51（ホーム IA）を明示的に Non-goals として先送りにした。本 change はその続きとして #50 に着手する。

ローカル Flutter ツールチェーンが使えない環境がある（milestone #1 の運用方針「Keep each batch small because local Flutter is unavailable and CI is the checker」）ため、まず対象面のコードを読み合わせて具体的な問題箇所を特定する「監査（audit）」を単独の小さいバッチとして完了させる。実際の修正は監査結果を踏まえて後続 change に分割する。

## What Changes

- **監査対象面**: 以下の feature の「開く → 操作 → 戻る/閉じる → ホーム/ライブラリに戻る」という基本操作フローを、macOS / Windows を主眼にコードレベルで精査する。
  - 動画再生: `app/lib/features/video/presentation/player_screen.dart`
  - 漫画/コミックビューア: `app/lib/features/manga/presentation/manga_viewer_screen.dart`
  - 書籍(PDF/EPUB)リーダー: `app/lib/features/book/presentation/book_reader_screen.dart`
  - 音声再生（フルスクリーン/ミニプレイヤー）: `app/lib/features/audio/presentation/player_screen.dart`, `app/lib/features/audio/presentation/mini_player.dart`
  - オンライン小説リーダー（カクヨム/なろう）: `app/lib/features/novel_kakuyomu/presentation/reader_screen.dart`, `app/lib/features/novel_narou/presentation/reader_screen.dart`
- **監査の具体的な成果物**: 各面について次を確認し、コード引用（`file_path:line_number`）付きで `design.md` に所見（Findings）として記録する。
  - 「戻る」導線が常時可視（AppBar 常設）か、自動非表示オーバーレイの中にしか存在しないか。
  - キーボード操作（Esc で閉じる、Space で再生/一時停止、矢印キーでシーク/ページ送り）の有無。
  - マウス/トラックパッド操作（クリックでのオーバーレイ表示/非表示、ホイールでのページ送りなど）の macOS/Windows 特有の差異。
  - デスクトップ用ウィンドウ管理（タイトルバー、閉じるボタン）への影響有無。
- **本 change のスコープ**: コード監査と、監査結果を反映した `design.md` 内の所見一覧の作成、およびその監査自体を spec 化する新規 capability `media-viewer-flow-audit`（ADDED）の作成のみ。実装修正は行わない。
- **後続 change への切り出し**: 監査で確認した問題は優先度をつけて `design.md` に記録し、修正は本 change のスコープ外として個別の後続 GitHub Issue / OpenSpec change に切り出す。

## Capabilities

### New Capabilities

- `media-viewer-flow-audit`: macOS/Windows の media/viewer 操作フロー監査そのものを対象とする capability。「監査記録が `file_path:line_number` 付きの具体的所見として存在し、かつ本 change ではアプリケーションコードを一切変更しない」ことを要求する。既存の製品挙動 capability（`local-video-playback` 等）とは独立しており、監査という成果物自体を spec 化することで、本 change を「監査のみ」の単独バッチとして OpenSpec の delta 要件（1 change につき最低 1 delta）を満たしつつ、実装修正を後続 change に委ねる。

### Modified Capabilities

(なし — 本 change は既存の製品挙動 capability（`local-video-playback` / `local-manga-zip-viewer` / `local-book-reader` / `local-audio-playback` / `kakuyomu-novel-reader-ui` / `narou-novel-reader-ui` 等）の要求事項を変更しない。監査で見つかった問題を修正する後続 change で、必要な spec delta を別途作成する。)

## Non-goals

- 監査対象面の実装修正（動画/漫画/書籍/音声/オンライン小説の操作フロー・キーボードショートカット・コントロール表示ロジックの変更）。これらは監査結果に基づく後続 change で扱う。
- ホーム画面の情報設計（IA）改善（issue #51 のスコープ）。
- novel feature の表示専用 artifact 除去（issue #43 / バッチ4で対応済み）。
- Android / Linux / iOS など macOS・Windows 以外のプラットフォーム固有の操作フロー監査（issue の主眼が macOS/Windows であるため対象外。監査中に他プラットフォームへの影響が明らかな場合のみ所見に記録する）。
- 独自ウィンドウ管理（タイトルバーカスタマイズ等）の導入。本アプリは `window_manager` 等を導入しておらず OS 標準のウィンドウ chrome を前提としており、本 change はこれを変更しない。

## Impact

- **変更ファイル（成果物のみ）**:
  - `openspec/changes/audit-media-viewer-flow-macos-windows/proposal.md`（本ファイル）
  - `openspec/changes/audit-media-viewer-flow-macos-windows/design.md`（監査所見一覧を含む）
  - `openspec/changes/audit-media-viewer-flow-macos-windows/tasks.md`
  - `openspec/changes/audit-media-viewer-flow-macos-windows/specs/media-viewer-flow-audit/spec.md`（ADDED — 監査という成果物自体を spec 化）
- **アプリケーションコードへの変更**: なし（監査のみ、実装修正なし）。
- **spec delta**: `media-viewer-flow-audit`（ADDED）のみ。既存の製品挙動 capability への delta なし。
- **依存関係追加なし**・**破壊的変更なし**。
- **GitHub Issue**: #50（milestone #1: UI Phase 2: correctness and accessibility）。

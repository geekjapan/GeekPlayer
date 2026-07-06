## Why

`docs/roadmap.md`（v1.0 セクション、`docs/roadmap.md:113-118`）は v1.x の「動画 AI パイプライン」として
Anime4K リアルタイムシェーダ・Real-ESRGAN 動画オフライン書き出し・RIFE フレーム補間の 3 項目を
未着手のまま列挙している。これらは ADR-0007（`docs/adr/0007-ai-upscaling-runtime-strategy.md`）が
確立した「画像アップスケーリングの基盤（`ImageUpscaler` / `MlRuntime` / `MlBackend` の preferred/effective
分離、Experimental 既定 OFF、モデル配布方針）」の延長線上にあるが、対象がそれぞれ

- リアルタイム GPU シェーダ（動画再生パイプラインへの統合、`MediaSession`/`VideoSession` の描画経路）
- オフラインバッチ変換（ファイル入出力・進捗 UI・エンコード）
- フレーム補間（時間軸方向のモデル、オフライン書き出し隣接）

と性質がまったく異なり、単一の GitHub Issue / OpenSpec change にまとめて実装するには大きすぎ、
アーキテクチャ判断（既存 ADR-0007 の射程内か、シェーダ統合のための新しい ADR が要るか）が先に必要になる。
Issue #48 はこの分解作業そのものを依頼しており、実装ではなく「ADR 要否の判断」と「後続 OpenSpec change への
分割案」を成果物として求めている。

## What Changes

- 動画 AI パイプライン 3 項目（Anime4K リアルタイム / Real-ESRGAN 動画オフライン / RIFE 補間）を対象に、
  実装前に必要な設計判断を洗い出し、以下の分解案を提示する。
- **新規 ADR-0008「動画 AI パイプラインのレンダリング／バッチ処理方式」を起票する。**
  リアルタイムシェーダ経路（`VideoSession` の描画パイプラインに GPU シェーダを差し込む方式）と、
  オフラインバッチ経路（Real-ESRGAN 動画・RIFE を共通の「オフライン変換ジョブ」として扱えるか）の
  アーキテクチャ方針を、ADR-0002（hybrid media engine）・ADR-0007（AI upscaling runtime strategy）を
  踏まえて確定する必要があることを明記する。ADR は本 change では**起票（ドラフト）のみ**行い、
  Decision 本文の最終確定は本 change のスコープ外とする。
- 後続 OpenSpec change を 3 本（+ 共通基盤の要否を判断する 1 本）に分割する計画を `design.md` に記す:
  1. `add-anime4k-realtime-shader`（仮称）: Anime4K リアルタイムレンダリング統合
  2. `add-realesrgan-video-export`（仮称）: Real-ESRGAN オフライン動画書き出し
  3. `add-rife-frame-interpolation`（仮称）: RIFE フレーム補間（オフライン書き出し）
  4. 上記が共通で必要とする基盤（例:「オフライン変換ジョブ」抽象、GPU シェーダ実行基盤の拡張）があれば
     先行する共通基盤 change として切り出すかどうかを `design.md` で判断する。
- 各後続 change 着手前に必要な調査項目（プラットフォーム対応、GPU/ランタイム依存、ライセンス、
  バイナリサイズ影響、検証用ハードウェア）を整理し、`design.md` に記録する。

## Capabilities

### New Capabilities

- `video-ai-pipeline-decomposition`: 本 change の成果物（ADR-0008 の起票、後続 change 分割計画、
  roadmap への反映）そのものを検証可能な要件として記述する、計画専用の capability。
  実行時のアプリ挙動は導入しない（詳細は `design.md` の D3 を参照）。

### Modified Capabilities

なし。既存の実行時 capability（`ml-runtime`, `ai-image-upscaler`, `onnx-upscaler-runtime`,
`gpu-execution-providers`, `upscale-model-distribution`, `upscale-image-tiling`, `media-session` 等）の
要件変更は行わない。

## Non-goals

- Anime4K リアルタイムシェーダの実装は行わない。
- Real-ESRGAN 動画オフライン書き出しの実装は行わない。
- RIFE フレーム補間の実装は行わない。
- 既存の実験的画像アップスケーリング経路（`ai-image-upscaler` / `onnx-upscaler-runtime` /
  `upscale-model-distribution` / `gpu-execution-providers`）の変更は行わない。
- ADR-0008 の Decision を最終確定させることは本 change のスコープ外とする（起票・ドラフトまで）。
  最終確定は ADR レビュー、または最初の後続 change の design 段階で行う。

## Impact

- 影響ファイル: `docs/roadmap.md:113-118`（v1.x 動画 AI パイプラインの記述）を本 change の結果に基づき更新する。
- 新規: `docs/adr/0008-video-ai-pipeline-rendering-strategy.md`（ドラフト起票）。
- 影響なし: `app/lib/core/ml/`, `app/lib/core/media/`（既存コードの変更なし、後続 change 群の対象）。
- GitHub: Issue #48（milestone #4 "v1.x: video AI pipeline"）を、本 change のマージ後にクローズし、
  提案する後続 3〜4 Issue へのリンクを追記する。

GitHub Issue: #48

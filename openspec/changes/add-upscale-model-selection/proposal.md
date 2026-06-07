## Why

ADR-0007 の AI アップスケール基盤（`ml-runtime` / `onnx-upscaler-runtime` / `upscale-model-distribution` / `gpu-execution-providers`）は実装・配線済みだが、配布カタログ（`app/lib/core/ml/upscale_model_catalog.dart:75-94`）はいまだ **fixture（nearest-neighbor の placeholder ONNX）** を指している。実際の画質向上が一切得られず、v1.0「AI 高画質化」の中身が空のままになっている。実アニメ/イラスト向けモデルへ差し替え、初回 DL→検証→推論の経路を本物の品質で成立させる。

調査結果（`deep-research`、保存先 `/tmp/geekplayer-upscale-model-selection-2026-06-07.md`）により採用候補・ランタイム制約・タイリング要件が確定したため、いま着手できる。

## What Changes

- `upscale_model_catalog.dart:75-94` の fixture エントリ（`x2`/`x4`）を **実モデル**へ差し替える（配線・公開 API は不変、`modelId`/`version`/`url`/`sha256`/`scale`/`license` のみ更新）:
  - **4x**: RealESRGAN_x4plus_anime_6B（BSD-3-Clause、RRDBNet `num_block=6`、`.pth` ~18MB を opset 17・固定タイル形状で ONNX export）。
  - **2x**: waifu2x swin_unet（nagadomi/nunif、MIT、`waifu2x/export_onnx.py` で opset 17・固定タイル形状 export）。
- **固定形状タイル推論の前処理/後処理を新設**: NNAPI は動的入力形状非対応・CoreML は固定形状で高性能なため、固定タイルで推論し、アプリ側でタイル分割・パディング・継ぎ目なし再合成を行う。
  - 外周 uniform padding（全タイル等寸化）+ タイル毎 ~10px 内側 padding（畳み込みエッジ artifact 抑制）。
  - 条件付き mod-padding: scale=2 のみ mod 2 を reflect-pad、scale=4 は不要。出力でクロップ除去。
- **実アーキテクチャの CPU-EP smoke を追加**: ORT 1.15.1 CPU EP で実モデル系（`num_block=6` RRDBNet / swin_unet を opset 17・固定タイル形状で export したもの）がロード・1 タイル推論できることを検証する（どの調査 source も ORT 1.15.1 互換を直接確認していないため実証必須）。
- ユーザー側の外部作業を**手動タスク**として明示（export / upstream ライセンス確認 / GitHub Release ホスト / SHA-256 算出 → カタログ確定）。

## Capabilities

### New Capabilities
- `upscale-image-tiling`: 固定形状 ONNX に対するタイル分割・外周/内側パディング・条件付き mod-padding・継ぎ目なし再合成の前処理/後処理契約。

### Modified Capabilities
- `upscale-model-distribution`: 配布カタログのエントリが、寛容ライセンス（BSD-3-Clause / MIT）かつ ORT 1.15.1 互換 opset（≤19）の **anime-tuned 実モデル**を指さなければならない、というモデル選定要件を追加（fixture を恒久エントリにしてはならない）。
- `onnx-upscaler-runtime`: 既存の「fixture での CPU-EP smoke」に加え、**実モデルと同一アーキテクチャ/opset/固定タイル形状**の ONNX が ORT 1.15.1 CPU EP でロード・推論できる smoke を要求する。

## Impact

- コード: `app/lib/core/ml/upscale_model_catalog.dart`（エントリ差し替え）、`app/lib/core/ml/onnx_image_upscaler.dart` 周辺（タイリング前処理/後処理の追加）。
- テスト: `app/test/` に固定形状タイル推論の smoke と、タイル分割/パディング/再合成のユニットテスト追加。
- 依存: 新規 pub 依存は無し（既存 `onnxruntime: ^1.4.1` = ネイティブ ORT 1.15.1、`image` パッケージを利用）。モデルバイナリは同梱せず GitHub Releases 配布（既存方針）。
- 配布物: `geekjapan/GeekPlayer` の GitHub Release（例 tag `models-v1`）に export 済み `.onnx` を添付（ユーザー側手動）。
- 関連: ADR-0007（AI アップスケールランタイム戦略）、`docs/roadmap.md:111`（実モデル選定 follow-up）、`add-android-16kb-page-support`（onnxruntime 16KB 残課題は本変更で不変）。

## Non-goals

- 動画 AI（Anime4K / RIFE / 動画 Real-ESRGAN）は対象外（ADR-0007 §6、別トラック）。
- GPU EP の新規対応や DirectML 解禁は対象外（ADR-0007 amendment のとおり Windows は CPU 縮退のまま）。
- AI アップスケールの Experimental 卒業（既定 ON 化）や品質保証は対象外（既定 OFF・opt-in を維持）。
- モデルバイナリのリポジトリ同梱は行わない（サイズ方針により GitHub Releases DL を維持）。
- 標準タイルサイズの最終決定以外のパフォーマンスチューニング（量子化等）は対象外。

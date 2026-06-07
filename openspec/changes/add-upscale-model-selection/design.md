## Context

ADR-0007 の AI アップスケール基盤は配線済みで、画像経路は `OnnxImageUpscaler`（ORT CPU/GPU EP）と `ModelRepository`（初回 DL・SHA-256 検証・キャッシュ）、`UpscaleModelCatalog`（静的カタログ）で構成される。現状カタログ（`app/lib/core/ml/upscale_model_catalog.dart:75-94`）は fixture を指し、実画質向上が得られない。

調査（`deep-research`、`/tmp/geekplayer-upscale-model-selection-2026-06-07.md`）で確定した事実:

- 同梱ネイティブランタイムは **ONNX Runtime 1.15.1**（確証: pub-cache の `macos/libonnxruntime.1.15.1.dylib`、iOS podspec `onnxruntime-objc 1.15.1`）。opset 19 まで対応 → エクスポートは **opset 17** が安全。
- **既製の適合 ONNX は無い**: Qualcomm は NPU/ORT 1.25.0 向けで不適合、AMD は Research-only RAIL でライセンス不可。→ 自前 export 必須。
- **NNAPI は動的入力形状非対応・CoreML は固定形状で高性能** → 固定タイル形状で export し、アプリ側でタイリング。
- タイリングは外周 uniform padding + タイル毎 ~10px 内側 padding、条件付き mod-padding（scale=2 のみ mod 2、scale=4 不要）、出力でクロップ（Real-ESRGAN `utils.py` 準拠）。

制約: モデルバイナリ非同梱（GitHub Releases DL 維持）。新規 pub 依存なし。AI は Experimental・既定 OFF を維持。

## Goals / Non-Goals

**Goals:**
- fixture を実 anime-tuned モデル（2x=waifu2x swin_unet/MIT、4x=RealESRGAN_x4plus_anime_6B/BSD-3-Clause）へ差し替える（配線・公開 API 不変）。
- 固定形状タイル推論の前処理/後処理（分割・パディング・mod-padding・継ぎ目なし再合成）を `upscale-image-tiling` として新設し、決定的にテスト可能にする。
- 実アーキ/opset/固定形状の ONNX が ORT 1.15.1 CPU EP で動くことを smoke で実証する。

**Non-Goals:**
- 動画 AI、GPU EP 新規対応、DirectML 解禁、Experimental 卒業、量子化チューニング、モデル同梱（すべて対象外）。

## Decisions

### D1: モデル採用 — 2x=waifu2x swin_unet、4x=RealESRGAN_x4plus_anime_6B

- **理由**: 両者とも anime-tuned で寛容ライセンス（MIT / BSD-3-Clause）、ORT 1.15.1 互換 opset へ export 可能。既製 ONNX が使えない（Qualcomm=NPU/ORT1.25.0、AMD=RAIL）ため自前 export が唯一の経路。
- **代替案**: ① 既製 Qualcomm/AMD ONNX をそのまま採用 → ランタイム不整合/ライセンス不可で却下。② 単一モデルで 2x/4x 兼用 → 品質と固定形状要件の両立が難しく却下。③ waifu2x の scale4x を 4x にも使う → 候補として残すが、既定 4x は Real-ESRGAN の方がイラスト復元で評価が高いため第一候補。

### D2: エクスポート opset = 17、固定タイル入力形状

- **理由**: ORT 1.15.1 は opset≤19 対応。17 は PyTorch 2.x 既定で保守的かつ十分。NNAPI 非対応・CoreML 選好より、動的形状を避け固定タイル形状で export。
- **代替案**: 動的形状 export → CPU フォールバックで加速されず、NNAPI で未対応ノード化リスク。却下（floor は bicubic CPU が別途担保）。

### D3: 標準タイルサイズ = 256px（暫定既定、実測で確定）

- **理由**: 128 は継ぎ目/オーバーヘッド過多、512 は 4x 出力（2048px）でモバイルメモリ負荷大。256px を暫定既定とし、CoreML/NNAPI 加速・メモリ・品質の実測で確定する。export 時にタイルサイズが固定化されるため、サイズ変更は再 export を伴う。
- **タイリングユーティリティはタイル寸法を引数化**し、実寸法は D7 のとおり ONNX 入力メタデータから供給する（256 はあくまで product モデルの export 既定）。smoke fixture（D4）は別途 64×64 等の小タイルで足り、product タイルとは独立。
- **代替案**: 動的タイル → D2 と矛盾。複数タイルサイズの同梱 → カタログ/DL が増えるため初版は単一に限定。

### D4: 実モデル smoke は「縮小アーキ・同一 op 種別」のランダム重み ONNX で行う

- **理由**: 検証目的は「同じ op 種別（Conv / LeakyReLU / PixelShuffle or Resize / Concat 等）と opset 17・固定形状が ORT 1.15.1 CPU EP でロード・推論できる」こと。**パラメータ数の忠実性は不要**。`num_block=6` をそのままランダム初期化すると実モデルと同パラメータ数（~18MB）になり同梱不可なので、**block/channel を最小化した縮小版**（例: RRDBNet `num_block=1`・`num_feat` 縮小、swin_unet 最小構成、小タイル 64×64）をランダム初期化し opset 17 で export する。同じ op 種別を含めば互換実証になり、サイズは数百 KB 以下に収まる。
- **代替案**: ① `num_block=6` フル random → ~18MB で同梱不可、却下。② 実 weights を DL してテスト → ネットワーク依存で CI 不安定（既存方針「ネット取得テストは決定的フェイク」に反する）、却下。

### D7: 固定タイル寸法は `UpscaleModelEntry.tileSize` に明示的に持たせる

- **apply 中の発見で当初案を反転**: `onnxruntime` 1.4.1 Dart パッケージの `OrtSession` は `inputNames`/`outputNames`/`inputCount`/`outputCount` のみ公開し、**入力 shape/型を取得する API を持たない**（pub-cache `lib/src/ort_session.dart` で確認）。当初案「ONNX 入力メタデータからタイル寸法を読む」は本パッケージでは不可能。
- **決定**: `UpscaleModelEntry` に `int? tileSize` を追加する。固定形状の実モデルは正方タイル辺長（例 256）を持ち、動的入力モデル（nearest fixture など）は `null`。`OnnxImageUpscaler` は `tileSize` を注入され、非 null ならタイリング経路、null なら現行の「全画像 1 回 run」を採る（既存 fixture テストの挙動を保存）。
- **代替案**: 入力 shape API を持つ別 ORT パッケージへ移行 → 16KB 互換等の既存決定（方針 A）に波及し過大。却下。
- **波及**: `OnnxImageUpscaler.upscale()` は `tileSize != null` のとき「decode → タイル分割（util）→ タイル毎 run → 再合成（util）」へ分岐。spec 契約（出力 = 入力 × scale・モデルは注入）は不変。catalog↔モデルの tileSize 整合は §3 export 時に export タイル辺長と `tileSize` を一致させることで担保。
- **補足（mod-padding）**: 固定タイル辺長を 2 でも 4 でも割り切れる値（256 等）にすれば、各タイルは divisibility を自動的に満たし、scale 依存 mod-padding は実質 no-op になる。partial 末端タイルは外周パディングで tileSize に充填されるため同様。spec 要件は「divisibility を保証する」ことであり、タイル辺長選択でこれを満たす。

### D5: タイリングは `OnnxImageUpscaler` 前段の純粋ユーティリティに分離

- **理由**: 分割/パディング/mod-padding/クロップ/再合成を ONNX セッションから独立した純粋関数群にすれば、実モデルなしで決定的にテストできる（`upscale-image-tiling` の要件）。`OnnxImageUpscaler` はタイル単位推論に専念。
- **代替案**: 推論ループ内に直書き → テスト困難。却下。

### D6: カタログ差し替えは外部依存をユーザー側手動タスクとして分離

- **理由**: export・upstream LICENSE 確認・GitHub Release ホスト・SHA-256 算出はエージェント単独で完結できない。コード側（タイリング・smoke・配線）はホスト前に実装/テスト可能なので、手動タスクと自動タスクを tasks.md で明確に分離する。

## Risks / Trade-offs

- **[ORT 1.15.1 が export ONNX の特定 op を未対応]** → D4 の小型アーキ smoke を**最優先で先行実装**し、ロード/推論不能なら opset/op を調整（最悪 waifu2x 系へ寄せる）。どの調査 source も互換を直接確認していないため最大リスク。
- **[x4plus_anime_6B weights のライセンスが実際は BSD-3 でない]** → 調査の license 証拠が弱い（1-0）。ホスト前に xinntao repo の LICENSE を直接確認（`upscale-model-distribution` 要件で必須化）。NG なら waifu2x scale4x へ 4x を切替。
- **[タイル継ぎ目が見える]** → 内側 ~10px パディング + mod-padding クロップで抑制。往復テストと実機目視で確認。
- **[256px タイルが最適でない]** → 暫定既定として明示。実測後にタイルサイズ変更は再 export を伴う点を tasks に記載。
- **[16KB ページ互換]** → 本変更は onnxruntime 依存を変えないため `add-android-16kb-page-support` の方針 A（監査＋CI ゲート）は不変。

## Migration Plan

1. コード先行（ホスト前に可能）: タイリングユーティリティ + 小型アーキ smoke を実装・テスト。
2. ユーザー側: export → LICENSE 確認 → GitHub Release ホスト → SHA-256 算出。
3. カタログ確定: `upscale_model_catalog.dart` の `x2`/`x4` を実 URL/SHA-256/scale/license へ差し替え。
4. 実機検証: manga viewer で 2x/4x（Experimental ON）。
- **ロールバック**: カタログを fixture に戻せば旧挙動に復帰（配線不変のため低リスク）。Experimental・既定 OFF なので一般ユーザー影響なし。

## Open Questions

- 標準タイルサイズの最終値（256px 暫定 → 実機 CoreML/NNAPI 実測で確定）。
- 4x の既定を Real-ESRGAN にするか、export 簡便性から waifu2x scale4x に寄せるか（smoke と画質実測後に確定）。
- noise level（waifu2x の `noise{0..3}`）の既定値（漫画スキャンのノイズ特性に依存、初版は noise1 想定）。

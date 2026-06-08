## 1. ランタイム互換 smoke 先行（コード、ホスト前に実施・最優先リスク潰し）

- [x] 1.1 **縮小** RRDBNet（`num_block=1`・`num_feat` 縮小、小タイル 64×64、実モデルと同一 op 種別）をランダム初期化し opset 17 で export する fixture 生成スクリプトを `app/tool/export_smoke_fixtures.py` に用意（要ローカル PyTorch 実行・CI 不可）
- [x] 1.2 **縮小** swin_unet stand-in（conv x2、最小構成・小タイル）も同スクリプトで export（数百 KB 以下。faithful な swin op 検証は §3.4-3.6 の実 export で補完）
- [x] 1.3 生成した小型 ONNX（`smoke_realesrgan_x4_arch.onnx` 24.7KB / `smoke_waifu2x_x2_arch.onnx` 15.0KB）を `test/fixtures/ml/` に配置・commit（実 weights 非同梱）
- [x] 1.4 smoke（`onnx_real_arch_smoke_test.dart`）が **ORT 1.15.1 CPU EP で両 fixture をロード・1 タイル推論** green（opset17・IR9）。未対応 op なし
- [x] 1.5 **発見: ORT 1.15.1 は ONNX IR version ≤9 のみ対応**（torch 2.12/onnx は IR10 を吐き "Unsupported model IR version: 10" で失敗）。export 後に `ir_version=9` へクランプして解決（opset は 17 のまま不変）。op 種別の調整は不要 → design D1/D2 の picks 維持

## 2. タイリング前処理/後処理（新規 capability `upscale-image-tiling`）

- [x] 2.1 固定タイル分割 + 外周 uniform padding ユーティリティを純粋関数として実装（`lib/core/ml/upscale_tiling.dart` の `planTiles`）
- [x] 2.2 タイル毎 ~10px 内側パディング（edge-replicate）の付与と、scale 倍クロップ（`stitchTiles`）を実装
- [x] 2.3 scale 依存 divisibility 保証（`requiredModulus`/`tileSizeSatisfiesScale`、固定 256 タイルで満たす）を実装。固定タイル経路では reflect-pad は no-op（design D7 補足・spec 改訂）
- [x] 2.4 継ぎ目なし再合成（最終寸法 = 入力 × scale、全パディングクロップ）を `stitchTiles` で実装
- [x] 2.5 分割→恒等/最近傍擬似推論→再合成の往復テスト（`test/core/ml/upscale_tiling_test.dart`、12 ケース、実モデル/ネット/GPU 不要）。全パス
- [x] 2.6 `OnnxImageUpscaler.upscale()` を `tileSize != null` のとき「decode → タイル分割 → タイル毎 run → 再合成」へ分岐（null は従来の全画像 1-run を保存）
- [x] 2.7 固定タイル寸法は `UpscaleModelEntry.tileSize` 経由で注入（ONNX API が入力 shape 非公開のため design D7 を反転）。`resolveImageUpscaler`/`providers` に配線。nearest fixture で tiled==whole 一致を統合テストで実証（ORT 1.15.1 CPU EP 実走）

## 3. 実モデル export・ホスト（ユーザー側手動）

- [ ] 3.1 PyTorch 環境を用意（torchvision ≥0.15）
- [ ] 3.2 【4x】xinntao/Real-ESRGAN から `RealESRGAN_x4plus_anime_6B.pth` 取得し repo の LICENSE を直接確認（BSD-3-Clause であること）
- [ ] 3.3 【4x】`num_block=6` RRDBNet を再構成し opset 17・固定タイル形状で `.onnx` を export。**export 後に `ir_version=9` へクランプ必須**（ORT 1.15.1 は IR≤9。§1.5 の発見。`tool/export_smoke_fixtures.py` の `_export` と同手順）
- [ ] 3.4 【2x】nagadomi/nunif を clone し LICENSE（MIT）確認、事前学習 swin_unet `.pth` を取得
- [ ] 3.5 【2x】`waifu2x/export_onnx.py` で `noise1_scale2x.onnx` を opset 17・固定タイル形状で export（既定 noise level = **noise1**、grill Q2 確定）。**export 後に `ir_version=9` へクランプ必須**（§1.5）
- [ ] 3.6 export 済み実 `.onnx` を §1.4 と同じ CPU-EP smoke 経路でロード・推論できることを手元確認
- [ ] 3.7 `geekjapan/GeekPlayer` の GitHub Release（例 tag `models-v1`）に実 `.onnx` を添付
- [ ] 3.8 各ファイルの SHA-256 を算出（`shasum -a 256 *.onnx`）・実ファイルサイズを記録

## 4. カタログ確定（`upscale-model-distribution`）

- [ ] 4.1 `app/lib/core/ml/upscale_model_catalog.dart:75-94` の `x2`/`x4` を実 `modelId`/`version`/`url`/`sha256`/`scale`/`license` に差し替え（配線・公開 API 不変）
- [ ] 4.2 fixture が恒久エントリに残っていないこと、license フィールドが upstream LICENSE と一致することを確認（`upscale-model-distribution` の選定基準・追跡可能性要件）
- [ ] 4.3 採用モデルの出所・ライセンス根拠を変更成果物（design もしくは本 tasks の脚注）に記録

## 5. 検証・仕上げ

- [ ] 5.1 `cd app && flutter test` 全 611 テストパス済み（タイリング往復 + tiled==whole 統合を含む）。実アーキ smoke は §1.3 の fixture 生成後に green 化 ← **smoke の green は §1.3 待ち**
- [ ] 5.2 manga viewer で 2x/4x を Experimental トグル ON で実機確認（継ぎ目・画質・倍率）
- [ ] 5.3 標準タイルサイズ（256px 暫定）の妥当性を実機 CoreML/NNAPI で確認し、必要なら再 export して確定（design Open Q）
- [ ] 5.4 `docs/roadmap.md:111` の「実モデル選定・配置（follow-up）」を完了側へ更新
- [x] 5.5 Android 16KB ゲート非回帰を確認（本変更は `pubspec.yaml` の onnxruntime 依存も同梱 `.so` も変更せず Dart コード/テストのみ。`tool/check_so_alignment.py` は不変）

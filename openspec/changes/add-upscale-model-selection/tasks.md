## 1. ランタイム互換 smoke 先行（コード、ホスト前に実施・最優先リスク潰し）

- [x] 1.1 **縮小** RRDBNet（`num_block=1`・`num_feat` 縮小、小タイル 64×64、実モデルと同一 op 種別）をランダム初期化し opset 17 で export する fixture 生成スクリプトを `app/tool/export_smoke_fixtures.py` に用意（要ローカル PyTorch 実行・CI 不可）
- [x] 1.2 ~~縮小 swin_unet stand-in~~ → **D8 で不要化**: 2x も Real-ESRGAN RRDBNet（4x downscale）になり swin 経路が無くなったため、conv stand-in fixture（`smoke_waifu2x_x2_arch.onnx`）は撤去。RRDBNet fixture が採用 op 種別を網羅する
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

## 3. 実モデル export・ホスト

- [x] 3.1 PyTorch 環境を用意（隔離 venv: torch 2.12 CPU + onnx + onnxscript）
- [x] 3.2 【4x】xinntao/Real-ESRGAN から `RealESRGAN_x4plus_anime_6B.pth`（17,938,799 bytes）取得、repo LICENSE を直接確認 = **BSD 3-Clause, Copyright (c) 2021 Xintao Wang**（grill Q1 弱証拠リスク解消）
- [x] 3.3 【4x】`num_block=6` RRDBNet を self-contained 実装（`tool/export_real_realesrgan_x4.py`）で state_dict ロード（strict=True 成功）→ opset 17・固定 256 タイル・**IR9 クランプ**で `.onnx` export（18,404,340 bytes, self-contained）
- [x] 3.4 ~~【2x】nunif clone / swin_unet .pth 取得~~ → **D8 で supersede**: 2x は 4x モデルの downscale で供給（nunif swin は opset20・動的形状・offset=16 で不適合と実証）
- [x] 3.5 ~~【2x】waifu2x export~~ → **D8 で supersede**（2x = 4x downscale、waifu2x 不採用）
- [x] 3.6 export 済み実 4x `.onnx` を ORT 1.15.1 CPU EP で **256→1024 推論完走を実機確認**（一時テスト、確認後削除）
- [x] 3.7 GitHub Release `models-v1` に `realesrgan_x4plus_anime_6b_t256.onnx` を添付（認証 DL の SHA-256 = カタログ値一致を検証）。**⚠️ caveat: repo が private のため未認証 DL は 404。アプリの実行時 DL を機能させるには repo の public 化（OSS 方針）か public ホストが必要。それまでは fail-safe で bicubic に degrade（AI は Experimental・既定 OFF）**
- [x] 3.8 SHA-256 算出済み: `3f224bc597aaf484e387789790d4339053efa7272c01758173b8a1796193c3ee`（18,404,340 bytes）。カタログに反映済み

## 4. カタログ確定（`upscale-model-distribution`）

- [x] 4.1 `upscale_model_catalog.dart` の `x2`/`x4` を実モデルに差し替え（両スロット `realesrgan-x4plus-anime-6b` / 実 URL `models-v1` / 実 SHA-256 / tileSize 256 / `modelScale` 4。x2 は `downscaleFactor` 2。配線・公開 API 不変）
- [x] 4.2 fixture が恒久エントリに不在・license=BSD-3-Clause を `upscale_model_catalog_test.dart` で検証（選定基準・追跡可能性要件）。repo/provider テストはローカル fixture entry / 直接ステージへ退避
- [x] 4.3 出所・ライセンス根拠を design D1/D8・spec・本 tasks に記録

## 5. 検証・仕上げ

- [x] 5.1 `cd app && flutter test` 全 **619 テストパス**（タイリング往復 + tiled==whole 統合 + 実アーキ smoke green + downscale + catalog 検証）・`flutter analyze` クリーン
- [x] 5.2 **機能 E2E 検証済み**: repo public 化後、production カタログ + `ModelRepository`（`DioModelDownloader`）で公開リリース `models-v1` から実モデルを DL→SHA-256 検証→4x（100×80→400×320）・2x（→200×160）をフルパイプライン（タイリング+downscale）で ORT 1.15.1 CPU EP 実走（一時テスト、確認後削除）。**残: 実機 manga viewer での視覚品質確認（継ぎ目・画質）はユーザー実機作業**
- [x] 5.3 タイルサイズ **256px を既定確定**（固定 export 済み・E2E 機能 OK）。CoreML/NNAPI の実機パフォーマンス実測による微調整は将来課題（再 export を伴う、機能ブロッカーではない）
- [x] 5.4 `docs/roadmap.md` の「実モデル選定・配置」を ✅ 完了へ更新（採用モデル・D8・E2E 確認・残課題を明記）
- [x] 5.5 Android 16KB ゲート非回帰を確認（本変更は `pubspec.yaml` の onnxruntime 依存も同梱 `.so` も変更せず Dart コード/テストのみ。`tool/check_so_alignment.py` は不変）

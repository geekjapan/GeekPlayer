# Grill残課題 — add-upscale-model-selection (20260607)

self-grill で技術論点はインライン解消済み（design.md / tasks.md / specs を更新）:
- smoke fixture のサイズ矛盾（`num_block=6` random = ~18MB）→ **縮小アーキ・同一 op 種別**へ修正（D4 / spec onnx-upscaler-runtime / tasks 1.1-1.2）。
- 固定タイル寸法の取得 → **ONNX 入力メタデータから取得**、動的なら既定 256 fallback（新 D7 / tasks 2.7）。
- `OnnxImageUpscaler.upscale()` の全画像 1-run → タイルループへの実装変更を明文化（D7 / tasks 2.6）。
- タイリングはタイル寸法を引数化、smoke タイル（64）と product タイル（256）を分離（D3）。

横断（Phase 2）: アクティブ変更は本件のみ。既存 spec（onnx-upscaler-runtime / upscale-model-distribution）への ADDED は既存要件と非矛盾、`OnnxImageUpscaler`・`upscale_model_catalog.dart` を触る他変更なし → **横断残課題なし**。

---

## add-upscale-model-selection — Grill残課題 (20260607)

### Q1. 4x スロットの採用モデル（Real-ESRGAN x4plus_anime_6B / waifu2x scale4x）
- **対象**: proposal「What Changes」4x、design D1、tasks 3.2-3.3、spec upscale-model-distribution「実モデル選定基準」
- **なぜ重要**: §3 export と §4 カタログ確定で 4x の実モデルを 1 つに決める必要。画質傾向（Real-ESRGAN はイラスト復元が強い／waifu2x はノイズ・線画保持が穏当）と export 手間、ライセンス確認先（xinntao repo / nunif）が変わる。§1 smoke は両アーキを試すため code-first apply は非ブロックだが、product 決定はユーザー所有。
- **検討した選択肢**: A) Real-ESRGAN x4plus_anime_6B を既定、ライセンス確認 NG 時のみ waifu2x scale4x へ退避 / B) 最初から waifu2x scale4x（2x と同系統で export 一本化）/ C) 両方カタログ登録しユーザー選択
- **推奨案**: **A**。アニメ/イラスト 4x の品質評価が高く、BSD-3-Clause で寛容。調査の license 証拠が弱い（1-0）ため §3.2 で xinntao repo の LICENSE 直接確認を必須化済み、NG なら waifu2x に退避。C は初版のカタログ/DL を増やすため見送り。
- **不足インプット**: 4x の既定をどれにするか（品質優先 vs export 一本化）。
- **Status**: Resolved — A) RealESRGAN_x4plus_anime_6B を既定、LICENSE NG 時のみ waifu2x scale4x へ退避（design D1・tasks 3.2-3.3 の方針どおり、追加編集不要）

### Q2. waifu2x 2x の既定ノイズ除去レベル（noise0 / noise1 / noise2 / noise3）
- **対象**: design Open Q、tasks 3.5、spec upscale-model-distribution
- **なぜ重要**: waifu2x は noise level ごとに別モデル（別 .onnx）を export する。初版カタログに焼き込む 1 つを決める必要。漫画スキャンの圧縮ノイズ量に対し、低すぎるとノイズ残留、高すぎると線画ディテールが潰れる。
- **検討した選択肢**: noise0（ノイズ除去なし・最も保守的）/ noise1（軽度）/ noise2（中）/ noise3（強）
- **推奨案**: **noise1**。一般的な漫画スキャン/Web 配信画像の軽い JPEG ノイズに対しディテール保持とのバランスが良い既定。実機評価（§5.2）で必要なら変更。
- **不足インプット**: 対象コンテンツの典型ノイズ量の想定（保守的 noise0 か、積極的除去か）。
- **Status**: Resolved — noise1（軽度）を既定。**ただし apply 中の実証で D8 により supersede**: 2x は waifu2x ではなく Real-ESRGAN 4x モデルの ×0.5 縮小で供給することになり（nunif swin は opset20・動的形状・offset=16 で不適合）、waifu2x noise level の選択自体が moot になった（design D8 参照）

### Q3. product/export タイルサイズの確定値（256px 暫定）
- **対象**: design D3 / D7、tasks 5.3
- **なぜ重要**: export ONNX に焼き込まれるため、変更は再 export を伴う。
- **検討した選択肢**: 128 / 256 / 512
- **推奨案 / 自己解決**: **256px 暫定で apply 可**。タイリングは寸法引数化（D3）・寸法は ONNX 入力メタデータ取得（D7）なので code は非依存。最終値は §5.3 で実機 CoreML/NNAPI 実測により確定する運用とする。
- **Status**: Resolved — 256px 暫定で進め、§5.3 の実機実測で確定（design D3/D7・tasks 5.3 に反映済み。export 前に確定が必要な点を §3 着手時に再確認）

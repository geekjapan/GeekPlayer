# Grill残課題 — cross-cutting step4 (20260606)

## スコープ
active change は `enable-gpu-execution-providers` 単一。依存先 step1–3（`ml-runtime`/`onnx-upscaler-runtime`/`ai-image-upscaler`/`ai-upscaler-settings`/`upscale-model-distribution`）は archive 済みで main spec 同期済み。stacked feature branch（`feature/enable-gpu-execution-providers`、step3 コミット上）に step3 のコードが在る。

## 自己解決した cross 論点
- **DAG 整合**: MODIFIED 対象（onnx-upscaler-runtime / ml-runtime / ai-upscaler-settings）の delta ヘッダは同期済み main spec と完全一致（`openspec validate --strict` 通過）。循環なし。
- **共有契約**: 消費する seam（`MlRuntime.ExecutionProviderProbe`/`preferredBackend`、`resolveImageUpscaler`、`OnnxModelSource`、`UpscaleResult.backend`、`MlBackend` enum）はすべて step1–3 で定義済み。新規発明型なし（追加するのは GPU probe・`targetBackend` パラメータ・override enum/設定キー）。
- **ownership 重複**: `ml-runtime`「Riverpod providers」要件は step3 でも MODIFIED 済み。step4 はその「probe を ortCpu→統合 probe」へさらに更新（同一要件の前進的変更で矛盾なし、step3 の確定形を土台に上書き）。`ai-upscaler-settings` の override は step3 で「step4 に委ねる」と明記した箇所の回収で、所有の整合が取れている。
- **パス衝突**: 単一 change のため編集衝突なし。

## 残課題
cross-cutting 固有の未解決項目は **なし**（粒度/CI/ADR の論点は per-change Q1–Q3 に集約）。

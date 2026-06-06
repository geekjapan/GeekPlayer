# Grill残課題 — cross-cutting (20260606)

## スコープ
アクティブな change は `add-upscale-model-distribution` 単一。ADR-0007 シーケンスの step1/step2 は archive 済みで、その capability spec (`ml-runtime` / `onnx-upscaler-runtime` / `ai-image-upscaler`) は `openspec/specs/` の確定契約。step4 (`enable-gpu-execution-providers`) は未起案。

## 自己解決した cross 論点
- **DAG 整合**: 依存先（step1/step2）は archive 済み live spec。本 change の MODIFIED delta は live spec のヘッダと完全一致（`openspec validate --strict` 通過）。循環なし。
- **共有契約の整合**: 本 change が consume する `MlRuntime` の resolver seam（`ExecutionProviderProbe`/`ModelStateResolver`/`ExperimentalFlagResolver`）と `resolveImageUpscaler`/`OnnxModelSource` は step1/step2 で既に定義済み（`app/lib/core/ml/ml_runtime.dart`, `upscaler_selection.dart`, `onnx_model_source.dart`）。新規に発明する型はなく、契約ズレなし。
- **所有重複**: `imageUpscalerProvider` の async 性が `ml-runtime` と `ai-image-upscaler` の両 delta に重複 → `ml-runtime` を provider 配線に限定、選択セマンティクスを `ai-image-upscaler` 所有へ整理（inline 解決済み）。
- **ownership/パス衝突**: 単一 change のため編集パス衝突なし。

## ユーザー確認に集約した cross 項目
- **step4 との境界（上級 backend 上書き UI）**: 本 change と step4 のスコープ境界に跨る → per-change 残課題 **Q3** に集約済み（重複記録しない）。

## 残課題
cross-cutting 固有の未解決項目は **なし**（境界論点は Q3 に集約）。

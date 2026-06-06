## Why

ADR-0007 step 3 (`add-upscale-model-distribution`) で AI 画像アップスケーリングは end-to-end に発火するようになったが、実効上限は **ORT CPU EP** に留まる。`OnnxImageUpscaler` は CPU プロバイダしか append せず (`app/lib/core/ml/onnx_image_upscaler.dart:53-56`)、production の execution-provider probe は `ortCpuExecutionProviderProbe` のみで GPU EP を常に false と報告する (`app/lib/core/ml/ort_capability_probe.dart:25-30`、`app/lib/core/ml/providers.dart:42`)。ADR-0007 step 4 として、ONNX Runtime の **GPU Execution Provider**（CoreML / NNAPI）を有効化し、step 3 で送りにした上級 backend 上書き UI を追加して、実機 GPU で実 AI 品質を出せる経路を開く。

**調査結果 (前提)**: `onnxruntime` 1.4.1 パッケージは `appendCoreMLProvider(CoreMLFlags)` / `appendNnapiProvider(NnapiFlags)` / `appendCPUProvider(CPUFlags)` / `appendXnnpackProvider()` を公開し、`OrtProvider` enum は cpu/coreml/nnapi/xnnpack。append 失敗は `checkOrtStatus` 経由で **catchable** に throw する。**DirectML / CUDA は高レベル API 非公開**（CUDA は raw binding のみ）。よって **CoreML EP（macOS/iOS）と NNAPI EP（Android）は有効化可能**だが、**DirectML（Windows GPU）はこのパッケージでは不可** — Windows は既存フォールバック連鎖で ORT CPU EP に縮退する（ADR-0007 の degrade 設計内で吸収、ADR 変更不要）。

## What Changes

- **`OnnxImageUpscaler` を EP 対応にする**: コンストラクタに目標 `MlBackend` を受け取り、セッション生成時に対応 EP を append する — `coremlEp`→`appendCoreMLProvider`、`nnapiEp`→`appendNnapiProvider`、それ以外→ CPU。**GPU EP を先に append し CPU を fallback として残す**。GPU append が throw した場合は catch して CPU-only セッションに縮退する（hard-fail しない）。`UpscaleResult.backend` は実際に使われた EP を報告する。
- **GPU EP 可用性 probe を新設**: 使い捨て `OrtSessionOptions` に対象 EP を append してみて、throw しなければ available、throw すれば unavailable を返す（**never throws**）。モデル不要。`coremlEp`/`nnapiEp` を扱い、`directmlEp` は常に false。
- **production probe を統合 probe に配線**: `providers.dart` の `mlRuntimeProvider` が注入する `executionProviderProbe` を、ortCpu のみ → **CPU + GPU 統合 probe** に置き換える (`app/lib/core/ml/providers.dart:42`)。これにより `MlRuntime.probe()` の preferred EP 分岐（`ml_runtime.dart:96-100`）が実際に GPU を選べるようになる。
- **上級 backend 上書き UI**（step 3 から送り）: Experimental 設定セクションに backend 上書きを追加 — **Auto（既定）/ 強制 CPU / 強制 GPU** の 3 択（grill Q1=A）。`強制 GPU` の具体 EP はプラットフォームから自動決定。永続化し、上書きしても probe 駆動のフォールバック（利用不可なら bicubic floor へ縮退）を必ず尊重する。
- **設定の永続化**: backend 上書き値を `AppSettings` + `setting_keys.dart`（既存 key/value、schema 据え置き）に追加。
- **Localization**: 上書き UI の新規文字列は `AppLocalizations`（ja/en）経由。

## Capabilities

### New Capabilities

- `gpu-execution-providers`: ONNX Runtime の GPU EP（CoreML / NNAPI）可用性 probe（try-append・never-throw）、CPU+GPU 統合 probe、`directmlEp` 常時 unavailable、CI 許容（実 GPU 無しでも no-throw）。production の `executionProviderProbe` シームに差し込む。

### Modified Capabilities

- `onnx-upscaler-runtime`: 「ONNX Runtime CPU-EP image upscaler」要件を、**目標 `MlBackend` に応じた EP を append する EP 対応 upscaler** へ更新する（GPU-first + CPU fallback、GPU append 失敗時は catch して CPU-only に縮退、`UpscaleResult.backend` は実 EP を報告）。CPU EP 実推論 smoke は維持。
- `ml-runtime`: 「Riverpod providers for the ML runtime」要件を、**production `mlRuntimeProvider` が CPU+GPU 統合 probe を注入する**よう更新する（ortCpu-only からの差し替え）。`MlRuntime` クラス契約・フォールバック連鎖自体は不変。
- `ai-upscaler-settings`: backend 上書き UI（Auto / 強制 CPU / 特定 EP 強制）を ADDED し、その永続化と localization を追加。step 3 で「step4 に委ねる」とした「実効 backend は probe に従い floor へ劣化する」要件から委譲文を解消する（上書きしても floor 劣化保証は維持）。

## Impact

- **新規コード**: GPU EP probe（`app/lib/core/ml/` 配下、`ort_capability_probe.dart` 拡張または新ファイル）、統合 probe。
- **変更コード**: `onnx_image_upscaler.dart`（EP append + target backend）、`providers.dart:42`（統合 probe 注入）、`experimental_section.dart`（上書き UI）、`app_settings.dart`/`setting_keys.dart`/`app_settings_repository.dart`（上書きキー）、`app_*.arb`（ja/en）。
- **依存**: 追加なし（`onnxruntime` の既存 API を使用）。drift schema 据え置き。
- **プラットフォーム**: CoreML（macOS/iOS）・NNAPI（Android）で GPU 経路有効化。Windows/Linux は ORT CPU EP に縮退（DirectML 非対応・将来課題）。
- **CI**: GPU EP 実推論はデバイス無しで検証不能。probe ロジックは注入 probe で単体テスト、実 probe テストは no-throw を assert（可用性に寛容、既存 `ort_capability_probe_test` に倣う）、EP 実推論テストは EP 不在時 skip（既存 `OnnxImageUpscaler` フィクスチャテストに倣う）。

## Non-goals

- **DirectML（Windows GPU）/ CUDA / TensorRT EP** — `onnxruntime` 1.4.1 の高レベル API 非公開。将来のパッケージ更新かカスタムビルドで別 change。Windows は当面 ORT CPU EP。
- **Xnnpack EP** — CPU アクセラレータであり ADR-0007 の GPU EP スコープ外。本 change では扱わない。
- **実 Real-ESRGAN/waifu2x モデルの選定・配置** — step 3 同様 follow-up（フィクスチャモデルで EP 配線を検証）。
- **実験的機能の卒業（既定 ON 化・品質保証）** — 実測後に別途判断（ADR-0007 Decision 0）。
- **動画 AI** — `ImageUpscaler` 対象外・別トラック・別 ADR。
- **drift schema 変更** — 上書き設定は既存 key/value に載せる。
- **ADR-0007 の supersede** — GPU EP 有効化はフォールバック連鎖内であり決定（ONNX Runtime + EP 一本化）は不変。ただし Windows DirectML の現実（パッケージ非対応・ortCpu 縮退）は **ADR-0007 に amendment 節を追記**して明文化する（grill Q3=B、supersede ではなく追補）。

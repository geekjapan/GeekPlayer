## Context

ADR-0007 step1–3 で ML ランタイムは完成域にある:

- `MlRuntime.probe()` は `preferred → ortCpu → bicubicCpu` のフォールバック連鎖を持ち、`ExecutionProviderProbe` を注入できる (`app/lib/core/ml/ml_runtime.dart:31-111`)。preferred が GPU EP のとき `_epProbe(preferred)` が true なら GPU を採用する分岐が既にある (`:96-100`)。
- production の probe は `ortCpuExecutionProviderProbe` のみで、GPU EP は常に false (`ort_capability_probe.dart:25-30`、`providers.dart:42`)。
- `OnnxImageUpscaler` は CPU プロバイダしか append しない (`onnx_image_upscaler.dart:53-56`)。

調査により `onnxruntime` 1.4.1 は `appendCoreMLProvider`/`appendNnapiProvider`/`appendCPUProvider`/`appendXnnpackProvider` を公開し、append 失敗は catchable に throw することが判明（DirectML/CUDA は非公開）。step 4 は「probe を実 GPU 対応にする」「upscaler を EP 対応にする」「上書き UI を足す」の 3 点で、フォールバック連鎖の seam にそのまま乗る。

## Goals / Non-Goals

**Goals:**

- CoreML（macOS/iOS）・NNAPI（Android）EP を有効化し、実機 GPU で `OnnxImageUpscaler` が走る経路を開く。
- 実 GPU EP 可用性 probe（try-append・never-throw）と CPU+GPU 統合 probe を提供し、production に配線する。
- 上級 backend 上書き UI（Auto / 強制 CPU / 特定 EP 強制）を追加し永続化する。
- GPU append 失敗・EP 不在時は CPU/bicubic floor に必ず縮退（hard-fail しない）。
- 実 GPU 無しの CI で全テスト緑（probe は no-throw、EP 実推論テストは不在時 skip）。

**Non-Goals:**

- DirectML / CUDA / TensorRT（パッケージ非公開）、Xnnpack（CPU アクセラレータ・スコープ外）。
- 実モデル選定（follow-up）、実験卒業、動画 AI、drift schema 変更、ADR-0007 supersede。

## Decisions

### D1. `OnnxImageUpscaler` に target `MlBackend` を渡し、GPU-first + CPU fallback で append

コンストラクタに `MlBackend targetBackend`（既定 `ortCpu`）を追加。`_ensureSession()` で:
```
options.appendGpuIfRequested(targetBackend)  // coreml/nnapi、throw は catch
options.appendCPUProvider(useArena)          // 常に最後に CPU を残す
```
GPU append が throw したら catch して CPU-only を継続（`_effectiveBackend` を実際に append できた EP に確定）。`UpscaleResult.backend` は `_effectiveBackend` を報告。

- 代替案: GPU 専用セッション（CPU fallback なし）→ 失敗時 hard-fail のため却下。ORT は複数 EP append 時に未対応ノードを次の EP に流すので GPU-first+CPU が正攻法。

### D2. GPU 可用性 probe は使い捨て `OrtSessionOptions` への try-append（モデル不要）

```
bool coremlAvailable() { try { final o = OrtSessionOptions()..appendCoreMLProvider(useNone); o.release(); return true; } catch (_) { return false; } }
```
セッション生成・推論なしで EP の有無を判定でき軽量。`OrtEnv.instance.init()` を前段で呼ぶ。never-throw。

- 代替案: 小モデルで実セッション生成して判定 → モデル依存・重い・CI で不安定のため却下。

### D3. `directmlEp` は常に false、Windows は ORT CPU に縮退（ADR 変更なし）

パッケージが DirectML 非公開のため `directmlEp` probe は常時 false。`MlRuntime.preferredBackend()` は Windows で `directmlEp` を返すが（`ml_runtime.dart:55-56`）、probe が false → `_epProbe(ortCpu)` 経由で ortCpu に縮退。これは ADR-0007 のフォールバック設計内であり ADR 変更不要。proposal/design に「Windows GPU は将来課題」と明記。

### D4. backend 上書きは `preferredBackend` を上書きする resolver で実現（grill Q1=A）

新規設定 `experimental.ai_upscale_backend_override`（enum: `auto`/`forceCpu`/`forceGpu`、既定 `auto`）。`MlRuntime` に `preferredOverride`（`MlBackend?` を返す resolver、既定 null）を追加し、`preferredBackend()` が override 非 null ならそれを優先。production の `mlRuntimeProvider` 配線側で override + プラットフォームを解釈して resolver を渡す:
- `auto` → null（プラットフォーム既定の preferred を使用）
- `forceCpu` → `ortCpu`
- `forceGpu` → プラットフォームの GPU EP（iOS/macOS=`coremlEp`、Android=`nnapiEp`、その他は GPU EP 無し→ null/`ortCpu`）

probe が利用不可なら従来どおり floor へ縮退するので安全性は保たれる。

- 代替案: 上書きで effective を直接強制 → floor 縮退保証を壊すため却下。上書きは「希望（preferred）」に作用し、可用性 probe が最終判定する。
- 代替案: `forceCoreml`/`forceNnapi` を個別列挙（grill Q1=B）→ プラットフォーム別 EP は 1 つなので冗長、`forceGpu` に簡約（grill Q1=A）。

### D5. `resolveImageUpscaler` / provider に target backend を伝搬

`resolveImageUpscaler(effective, model)` は ortCpu のときのみ `OnnxImageUpscaler` を返す（step2）。step4 では effective が `coremlEp`/`nnapiEp` でも `OnnxImageUpscaler(model, targetBackend: effective)` を返すよう拡張。`imageUpscalerProvider`（`providers.dart:67-80`）の `caps.effective != ortCpu` early-return を「GPU EP も Onnx 経路」に広げ、target backend を渡す。

### D6. 設定 UI（上書き）

Experimental セクションに `SegmentedButton`/`ChoiceChip` で **Auto / 強制 CPU / 強制 GPU** の 3 択を提示（grill Q1=A）。注記で「強制 GPU は利用不可時 CPU に縮退」を示す。GPU EP の無いプラットフォーム（Windows/Linux）でも 3 択は出すが、強制 GPU は probe 不可で CPU 縮退する（注記で説明）。永続化は既存 key/value。

## Risks / Trade-offs

- **[CoreML/NNAPI が native build に含まれない]** → append が throw → probe false / upscaler は CPU 継続。pub.dev onnxruntime の macOS dylib は通常 CoreML を含み、Android AAR は NNAPI を含むが、未保証。実機検証は follow-up。CI は no-throw で緑。
- **[GPU EP の数値差]** → nearest-neighbor フィクスチャは整数倍 Resize で EP 間差は最小。実モデルでの数値差は実モデル follow-up で評価。
- **[CoreML probe が macOS CI で true を返し、実推論テストが走る]** → EP 実推論テストは「EP available なら実行・不在なら skip」。CoreML CPU 実行でも nearest 出力は決定的なので緑のはず。万一不安定なら skip 条件を厳格化。
- **[Windows DirectML 不在のユーザー期待ズレ]** → 設定 UI と docs で「Windows GPU は将来対応」を明記。
- **[OrtSessionOptions のリーク]** → probe は append 後に `release()` を必ず呼ぶ（try/finally）。

## Migration Plan

- 後方互換: 既存ユーザーは override キー未存在 → `auto`。挙動は probe 駆動で、GPU が使えるプラットフォームでのみ自動的に GPU 経路へ（実験 ON＋モデル present 時のみ）。ロールフォワードのみ・データ移行不要。
- 失敗時縮退: GPU append 失敗・EP 不在・上書き不能のいずれも bicubic/ORT CPU floor へ縮退。機能無効化はトグル OFF で完結。

## Open Questions（grill 20260606 で解決済み）

- ~~上書きの粒度~~ → **解決 (Q1=A)**: `auto`/`forceCpu`/`forceGpu` の 3 択。`forceGpu` の具体 EP はプラットフォームから自動決定（D4）。
- ~~EP 実推論テストを CI で実走させるか~~ → **解決 (Q2=A)**: available なら実走・不在なら skip（既存 `onnx_image_upscaler_test` の skip パターン）。
- ~~Windows DirectML ギャップを ADR に追記するか~~ → **解決 (Q3=B)**: **ADR-0007 に amendment 節を追記**し、Windows EP の現実（DirectML 非対応・ortCpu 縮退）を明文化する（tasks 7.6）。

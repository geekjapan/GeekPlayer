# 0007 — On-device AI 画像アップスケーリングのランタイム戦略と環境別挙動

**Status**: accepted (2026-06-03)

> 関連: [ADR-0002](0002-hybrid-media-engine.md)（メディアエンジン）。
> 既存 capability: `ml-runtime`（`add-ml-runtime-abstraction`）、`ai-image-upscaler`（`add-ai-image-upscaler`）。
> 本 ADR は v1.0「AI 高画質化」の concrete backend を実装する前の **基盤の再整理** であり、
> 後続の ML backend / モデル配布 change の前提条件となる。

## Context

v0.2 で AI 高画質化の足場を 2 段階で入れた:

- `ml-runtime`: `ImageUpscaler` 抽象、`MlRuntime`（プラットフォーム→`MlBackend` 選択）、`MlCapabilities`、`MlBackend` enum（coreml / nnapi / onnxRuntime / tensorRt / cpu）。
- `ai-image-upscaler`: `CpuImageUpscaler`（`image` パッケージの bicubic）を既定 `imageUpscalerProvider` とし、manga viewer に「高画質化」アクションを追加。

ここで concrete な GPU/ネイティブ backend に進む前に、**基盤に未解決の構造的問題**がある:

1. **「選択 backend」と「実効 backend」が乖離している。** `MlRuntime.describe()` は OS だけで backend を返す（iOS→`coreml` 等）。しかし実装済みのアップスケーラは `CpuImageUpscaler`（`cpu` を報告）だけ。`describe()` は「iOS では CoreML」と言うが、実際に走るのは CPU bicubic。**選択（プラットフォーム志向の願望）と可用性（実際に使えるか）が分離されていない。**
2. **可用性判定がない。** 「その backend が今このデバイスで本当に使えるか」（ランタイム/実行プロバイダの有無、モデルの有無、メモリ）を確かめる仕組みも、使えないときの**フォールバック連鎖**もない。
3. **モデル配布モデルがない。** roadmap は「AI 機能は opt-in モジュール、モデルは初回利用時に GitHub Releases から DL」と定める。現状その仕組みは皆無。
4. **環境別の挙動・機能が未定義。** どの OS で何が既定 ON/OFF か、モデル未取得時に UI がどう振る舞うか、品質がどう変わるかが決まっていない。

v1.0 のゴールは Real-ESRGAN / waifu2x を on-device GPU で推論すること。複数の concrete change（各 OS backend、モデル配布、設定 UI）がこの基盤に乗るため、**先に基盤の挙動契約を確定する**。

## Decision

### 0. AI アップスケーリングは「実験的機能（Experimental）」として出す

当面、AI 画像アップスケーリングは **実験的機能**として提供する:

- **既定 OFF**。設定の「実験的機能 / Experimental」ゲートの内側に置き、明示的に有効化したときだけ動作する。
- UI は **Experimental ラベル**を表示し、品質・性能・安定性を保証しないこと、将来仕様変更や削除があり得ることを明記する。
- 実験的扱いのため、ORT 経路・モデル配布・GPU EP を**段階的に**投入できる（フル品質の作り込みを待たずに出せる）。
- 実験フラグが OFF の間、画像経路の effective backend は **bicubic CPU**（現行挙動）であり、ユーザー体験は変わらない。

実験的機能を卒業（既定 ON 化や保証付与）する判断は、品質・性能の実測後に別途行う。

### 1. backend を「preferred（志向）」と「effective（実効）」の 2 層に分離する

`MlRuntime` は次を返すよう再定義する:

- **preferred backend**: OS から決まる理想の実行プロバイダ（下記マトリクス）。
- **effective backend**: ランタイム可用性 + モデル有無を**非同期で probe** した結果、実際に使う backend。
- `MlCapabilities` を `{ preferred, effective, modelState, reason }` に拡張する。`describe()` は同期の静的選択をやめ、`probe()`（async）で実効能力を返す。UI と `imageUpscalerProvider` は **effective backend** に基づく。

これにより「iOS だから CoreML と表示するが実は CPU」という不整合を解消する。

### 2. フォールバック連鎖（画像）

```
preferred GPU EP（CoreML / NNAPI / DirectML / TensorRT）
   └→ 利用不可 or モデル未取得 →  ONNX Runtime CPU EP
        └→ 利用不可 → bicubic CPU（CpuImageUpscaler、常に利用可能）
```

**bicubic CPU を恒久的な最下層（universal floor）**とする。AI アップスケーリングは hard-fail せず、必ずいずれかの段に**劣化（degrade）**する。`reason` に「なぜこの段か」（モデル未取得 / EP 不在 等）を載せ、UI が説明できるようにする。

### 3. クロスプラットフォーム推論ランタイムは ONNX Runtime に一本化し、GPU は実行プロバイダ（EP）で差し込む

各 OS 専用フレームワーク（CoreML / NNAPI / TensorRT）を**別々のネイティブ実装として持たない**。代わりに **ONNX Runtime（ORT）を単一の推論ブリッジ**とし、GPU 加速は ORT の Execution Provider で切り替える:

| OS | preferred EP | フォールバック |
|---|---|---|
| iOS / macOS | CoreML EP | ORT CPU EP → bicubic CPU |
| Android | NNAPI EP | ORT CPU EP → bicubic CPU |
| Windows | DirectML EP | ORT CPU EP → bicubic CPU |
| Linux | ORT CPU EP（GPU は将来 CUDA/TensorRT EP） | bicubic CPU |
| その他/Web | bicubic CPU | — |

これでネイティブ実装面が「ORT 統合 + EP 設定」に収束し、4 種の独立ネイティブコードベースを避けられる。**`MlBackend` enum は EP 志向に見直す**（例: `coremlEp` / `nnapiEp` / `directmlEp` / `ortCpu` / `bicubicCpu`）。`tensorRt` は当面 Windows/Linux の将来 EP として保留。

### 4. モデルのライフサイクル（opt-in + 初回 DL）

- AI アップスケーリングは **opt-in 機能**。アプリ本体にモデルを**同梱しない**（サイズのため）。
- モデルは初回利用時に **GitHub Releases から DL**（バージョン付き、SHA-256 検証、on-disk キャッシュ）。`ModelRepository` を新設し、DL/検証/保存/削除を担う。
- モデル未取得の間、effective backend は **bicubic CPU**（＝現在の挙動）。AI 品質はモデル取得後に有効化。
- **設定**は「実験的機能」セクション配下に置き、AI アップスケーリングの有効化トグル（既定 OFF）、既定倍率、モデル管理（DL/削除/サイズ表示）、（上級）backend 上書きを提供。
- **ライセンス**: Real-ESRGAN は BSD-3-Clause、waifu2x は MIT と**寛容**。libmpv（LGPL）と違い配布上の動的リンク制約はないが、サイズの都合で同梱せず DL とする。採用モデルのライセンスは change 着手時に各々確認する。

### 5. 環境別の挙動・機能マトリクス

全環境で **実験的機能・既定 OFF**。下表は実験フラグを ON にしたときの経路（OFF の間は常に bicubic CPU）。

| 環境 | AI（実験フラグ ON 時） | preferred 経路 | モデル未取得時 | 備考 |
|---|---|---|---|---|
| iOS / iPadOS | experimental（既定 OFF） | CoreML EP | bicubic CPU | 非ストア配布（ADR-0006） |
| macOS | experimental | CoreML EP | bicubic CPU | |
| Android | experimental | NNAPI EP | bicubic CPU | 端末差が大きく要 fallback |
| Windows | experimental | DirectML EP | bicubic CPU | |
| Linux | experimental | ORT CPU EP | bicubic CPU | GPU EP は将来 |
| Web/その他 | 常に bicubic CPU | — | — | ORT/モデル非対象 |

### 6. 機能境界

- **画像**（manga / book ページ）は `ImageUpscaler` seam を通す（本 ADR の対象）。
- **動画 AI**（Anime4K リアルタイム / Real-ESRGAN オフライン書き出し / RIFE 補間）は `ImageUpscaler` の**対象外**で、レンダリングパス/書き出しパイプラインの別トラックとする。本 ADR は画像経路のみを規定する。

## Considered Options

### A. ONNX Runtime + Execution Providers（単一ランタイム、OS 別 EP）

- ✅ ネイティブ面が ORT 統合 + EP 設定に収束。4 種の独立ネイティブ実装を回避。
- ✅ ORT CPU EP は全 OS・CI で検証可能（GPU 不要で smoke できる）。モデルも ONNX で統一。
- ✅ Real-ESRGAN/waifu2x は ONNX 変換実績が豊富。
- ⚠️ ORT Flutter パッケージの各 OS ビルド可否を spike で要確認（iOS の media_kit と同様）。
- ⚠️ EP ごとの数値差・対応 opset の確認が要る。

### B. OS 別ネイティブフレームワーク（CoreML / NNAPI / TensorRT を個別実装）

- ✅ 各 OS で理論上の最高性能・最小依存。
- ⚠️ ネイティブコードベースが OS 分だけ増殖、テスト・保守・CI 検証が困難。
- ⚠️ この環境では検証不能（モデル/デバイス/GPU ランタイム不在）。

### C. CPU bicubic のまま（AI 推論を入れない）

- ✅ 最小・全 OS で確実。現状の `CpuImageUpscaler` がそれ。
- ❌ AI 高画質化という v1.0 の核を満たさない。floor としては残すが単体では不採択。

## Decision の位置づけ

- **A（ONNX Runtime + EP）を採択**。検証可能性（CI で CPU EP smoke）と保守性で最良。
- スコープは**画像のみ**（manga/book）。動画 AI は別トラック・別 ADR。
- 機能は**当面 Experimental・既定 OFF**（上記 Decision 0）。
- bicubic CPU（現 `CpuImageUpscaler`）は**恒久 floor**として常に残す。
- **B は採らない**（OS 別ネイティブ増殖を避ける）。将来 ORT で性能不足が判明した特定 OS に限り、ADR を supersede して部分導入を検討する。

## Consequences

- **基盤リファクタが最初の実装 change**: `MlRuntime` を preferred/effective + 非同期 probe + フォールバックに再構成し、`MlCapabilities` と `MlBackend` を見直す。`ai-image-upscaler` の「`describe()` がプラットフォーム backend を選ぶ」期待は**実効 backend セマンティクス**へ更新する。
- **新規 capability**: `ModelRepository`（モデル DL/検証/キャッシュ）と AI 設定 UI。
- **CI**: ORT パッケージが全 6 ジョブ（特に iOS/Android/Windows）でビルドできるか spike で確認してから依存追加（iOS media_kit の前例に倣う）。ORT CPU EP の推論 smoke を 1 つ足す。
- **後続 change のシーケンス（推奨）**:
  1. `refactor-ml-runtime-effective-backend` — preferred/effective + probe + フォールバック（コードのみ、検証可能）。
  2. `add-onnx-upscaler-runtime` — ORT 統合 + CPU EP の `OnnxImageUpscaler`（軽量モデルで CI 検証）。
  3. `add-upscale-model-distribution` — `ModelRepository`（初回 DL/検証/キャッシュ）+ 設定 UI。
  4. `enable-gpu-execution-providers` — CoreML / NNAPI / DirectML EP を段階有効化。
  5. 動画 AI（Anime4K / RIFE / 動画 Real-ESRGAN）は別 ADR・別トラック。
- 各後続 change の proposal は本 ADR を Related ADR として参照し、roadmap の **v0.2 proposal readiness checklist**（依存/ライセンス/全 OS サポート/検証コマンド）に通すこと。
- AI 高画質化の挙動を変える将来判断（モデル同梱化、クラウド推論等）は本 ADR を supersede する新 ADR を立てる。

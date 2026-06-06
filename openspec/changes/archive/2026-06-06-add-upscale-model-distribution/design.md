## Context

ADR-0007 の step 1 (`refactor-ml-runtime-effective-backend`) と step 2 (`add-onnx-upscaler-runtime`) で、ML ランタイムの seam はほぼ完成している:

- `MlRuntime.probe()` は `preferred → ortCpu → bicubicCpu` のフォールバック連鎖を実装し、3 つの注入可能 resolver (`ExecutionProviderProbe` / `ModelStateResolver` / `ExperimentalFlagResolver`) を持つ (`app/lib/core/ml/ml_runtime.dart:31-111`)。ただし production の既定値はすべて floor (`_noExecutionProviders` / `_modelAbsent` / `_experimentalOff`、同 `:24-26`)。
- `resolveImageUpscaler` は実効 backend + モデル source から `OnnxImageUpscaler` か `CpuImageUpscaler` を返す純粋関数 (`app/lib/core/ml/upscaler_selection.dart:15`)。
- `ortCpuExecutionProviderProbe` は ORT 初期化可否を返す (`app/lib/core/ml/ort_capability_probe.dart:25`)。
- `imageUpscalerProvider` は今も同期の `CpuImageUpscaler` を返すだけ (`app/lib/core/ml/providers.dart:24`)。

欠けているのは「実モデルの供給」と「実験的機能の有効化」、そしてそれらを provider に配線する最後の一手。本 change はその 3 点を埋め、初めて AI 経路を end-to-end で発火可能にする。設定永続化は既存の key/value (`AppSettings` + `setting_keys.dart` + drift `app_settings`、schema v3) に載せ、schema は上げない。

## Goals / Non-Goals

**Goals:**

- opt-in モデルを GitHub Releases から初回 DL し、SHA-256 検証 + バージョン付き on-disk キャッシュする `ModelRepository` を提供する。
- 実験的機能ゲート配下の設定 UI (有効化トグル既定 OFF・既定倍率・モデル管理・上級 backend 上書き) を追加し、永続化する。
- `mlRuntimeProvider` を floor 既定から実 resolver 注入へ、`imageUpscalerProvider` を async + 実効 backend 駆動へ配線し、manga viewer を移行する。
- 実験 OFF / モデル未取得時は現行どおり bicubic CPU に劣化し、ユーザー体験を変えない。
- ネットワーク非依存・GPU 非依存で全 CI が通るテストを揃える。

**Non-Goals:**

- GPU EP の有効化 (step 4)。本 change の実効上限は ORT CPU EP。
- 動画 AI / フレーム補間 (別トラック・別 ADR)。
- 実験的機能の卒業 (既定 ON 化・品質保証)。
- モデル同梱・クラウド推論。
- 書籍リーダーへの適用拡大、drift schema 変更。

## Decisions

### D1. `ModelRepository` は注入可能な HTTP クライアントを取り、検証を内製する

`dio` を直接呼ばず、薄い `ModelDownloader` 抽象 (あるいは `dio` の注入) を介す。理由: テストを実ネットワーク非依存にするため。SHA-256 は `crypto` パッケージ (`sha256.convert(bytes)`) で計算する。検証フロー: 一時ファイルへ DL → ハッシュ照合 → 一致時のみ最終パスへ `rename` (原子的確定)、不一致・失敗時は一時ファイルを削除。

- 代替案: ダウンロード済みを直接最終パスへ書く → 中断時に壊れたモデルが present 扱いになるため却下。temp→検証→rename を採る。

### D2. キャッシュレイアウトは `<appSupport>/ml_models/<modelId>/<version>/model.onnx`

`path_provider` の `getApplicationSupportDirectory()` 配下。モデル ID とバージョンでパスを分離するので、バージョン差は別物として共存し、片方の削除が他方に影響しない。present 判定は「期待パスにファイルが存在し、サイズ > 0」。

- 代替案: 単一ファイル名でバージョンを上書き → ロールバック不能・検証中の不整合リスクで却下。

### D3. モデルカタログはコード内の静的 const で持つ

初期は 1 モデル (例: 軽量 Real-ESRGAN/ESRGAN 系の ONNX、ライセンスは change 着手時に確認) のみ。カタログを Dart の const リストにし、ID/version/url/sha256/scale/license を宣言。理由: アセット同梱やリモート catalog 取得は過剰。将来モデルが増えたらリモートカタログ化を別 change で検討。

### D4. 設定は既存 key/value に載せ、schema を上げない

`setting_keys.dart` に `aiUpscaleEnabled`(bool, 既定 false)、`aiUpscaleScale`(int/enum, 既定 2)、`aiUpscaleModelId`(string?) を追加。`settings_codec.dart` でエンコード。drift `app_settings` は汎用 key/value なので migration 不要。`AppSettings` 値オブジェクトと `app_settings_notifier` にフィールドを足す。

- 反映ポリシー: トグル変更は **次回 upscale 実行時に反映** (provider 再評価)。アクティブな upscale 中セッションへの即時反映は不要。`docs/CONVENTIONS.md` の realtime reflection 開示に倣い設定 UI に明記。

### D5. provider 配線 — `mlRuntimeProvider` に実 resolver、`imageUpscalerProvider` を async 化

- `mlRuntimeProvider` (`providers.dart`) は `MlRuntime(executionProviderProbe: ortCpuExecutionProviderProbe, modelState: () => repo.stateOf(selected), experimentalFlag: () => settings.aiUpscaleEnabled)` を構築する。
- `imageUpscalerProvider` を `FutureProvider`/async notifier 化し、`final caps = await runtime.probe(); final model = caps.effective == ortCpu ? repo.sourceOf(selected) : null; return resolveImageUpscaler(effective: caps.effective, model: model);` で解決。
- manga viewer の高画質化アクションは `ref.read`(同期) から `ref.watch(imageUpscalerProvider.future)` ベースの async 取得へ移行。解決中・upscale 中は `CircularProgressIndicator`、失敗時はローカライズ済みエラー + 元ページ維持。

- 代替案: `imageUpscalerProvider` を同期のまま probe を別 provider に分ける → manga viewer 側で 2 provider を合成する複雑さが増すため、単一 async provider に集約。

### D6. ローカライズ

新規文字列はすべて `app/lib/l10n/app_en.arb` / `app_ja.arb` に追加し、`AppLocalizations` 経由で参照。ARB key parity test (`add-english-localization` で導入済み) が ja/en の欠落を検出する。

## Risks / Trade-offs

- **[ONNX モデルの入手性・ライセンス未確定]** → 採用モデルのライセンス (Real-ESRGAN: BSD-3, waifu2x: MIT) と ONNX 変換可否を change 着手時に確認。カタログは差し替え容易な const なので、確定までフィクスチャ/プレースホルダで配線を完成させ、実モデル URL/SHA は確定後に差し込む。
- **[GitHub Releases の URL 変更・404]** → DL 失敗は catchable エラーで absent を維持し bicubic に劣化。UI はエラーを表示し再試行可能。
- **[大きいモデルの DL 中断]** → temp→検証→rename で部分ファイルが present 扱いにならない。再試行で再 DL。レジューム DL は本 change では非対応 (将来検討)。
- **[ORT CPU 推論が遅い]** → 実験的機能・既定 OFF なので影響は限定。倍率既定 2x、対象は表示中ページ単位。性能実測は卒業判断時。
- **[onnxruntime の各 OS ビルド]** → step 2 で全 OS ビルドは検証済み。本 change は新たなネイティブ依存を増やさない (`crypto` は pure-Dart)。
- **[設定の realtime 反映期待のズレ]** → D4 の「次回実行時反映」を UI に明記し、`app-settings` の realtime 開示要件に合わせる。

## Migration Plan

- 後方互換: 既存ユーザーは設定キー未存在 → 既定 OFF で読み込まれ、挙動は現行 (bicubic) のまま。ロールフォワードのみで、データ移行・ロールバック手順は不要。
- 失敗時の縮退: いずれの障害 (DL 失敗・検証失敗・ORT 不在) でも bicubic floor に劣化するため、機能無効化は「トグル OFF」で完結する。

## Open Questions（grill 20260606 で解決済み）

- ~~初期カタログに載せる具体モデルと公開 URL/SHA-256~~ → **解決 (Q1=A)**: 本 change は DL/検証/キャッシュ/配線/UI を **フィクスチャモデル (2x/4x)** で完成させる。実 ONNX モデルの選定・ライセンス精査・GitHub Releases 配置は **follow-up change**。実験 OFF 既定のためユーザー影響なし。カタログは差し替え容易な const。
- ~~既定スケールの選択肢~~ → **解決 (Q2=B)**: **2x / 4x を選択可・既定 2x**。カタログは倍率ごとにエントリ (フィクスチャ) を持ち、manga viewer は設定値の倍率を使用する。
- ~~上級 backend 上書き UI を本 change に含めるか~~ → **解決 (Q3=A)**: 本 change では **提供しない**。GPU EP を有効化する step4 (`enable-gpu-execution-providers`) に委ねる。本 change は floor 劣化保証 (probe 経路) のみを担保 (spec ai-upscaler-settings「実効 backend は probe に従い floor へ劣化する」)。

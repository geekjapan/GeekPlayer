## Why

ADR-0007 のシーケンス step 2 (`add-onnx-upscaler-runtime`) で `OnnxImageUpscaler` と純粋な選択 seam (`resolveImageUpscaler`) までは入ったが、**実モデルが端末に存在しないため AI アップスケーリングは一度も発火しない**。`imageUpscalerProvider` は今も同期の bicubic floor を返すだけで (`app/lib/core/ml/providers.dart:24`)、`MlRuntime.probe()` の `modelState`/`experimentalFlag` resolver は floor 既定のまま (`app/lib/core/ml/ml_runtime.dart:25-26`)。ADR-0007 step 3 として、**opt-in モデルを初回 DL・検証・キャッシュする仕組み**と**それを有効化する実験的機能の設定 UI**、そして両者を実効 backend へ配線する async provider を入れ、初めて実 AI 品質を出せる状態にする。

## What Changes

- **`ModelRepository` を新設**: アップスケールモデルを GitHub Releases から初回 DL し、SHA-256 で検証、バージョン付きで on-disk キャッシュ、サイズ照会・削除を提供する。`OnnxModelSource.file(path)` (`app/lib/core/ml/onnx_model_source.dart:18`) を供給元として返す。
- **モデルカタログ**: アプリ同梱の静的カタログ (モデル ID・バージョン・URL・期待 SHA-256・スケール係数・ライセンス) を定義し、DL 対象を宣言的に持つ。アプリ本体にモデルバイナリは**同梱しない**。
- **実験的機能の設定 UI**: `features/settings/presentation/sections/` に Experimental セクションを追加。AI アップスケーリング有効化トグル (**既定 OFF**)、既定スケール倍率 (**2x / 4x 選択可・既定 2x**)、モデル管理 (DL/削除/サイズ表示/進捗) を提供。`Experimental` ラベルで品質・性能・安定性を保証しない旨を明示する。(上級) backend 上書き UI は GPU EP を入れる step4 へ委ねる。
- **設定の永続化**: 上記トグル・倍率・選択モデルを `AppSettings` (`app/lib/features/settings/domain/app_settings.dart`) と `setting_keys.dart` に追加し、既存 key/value 永続化 (drift app_settings, schema 据え置き) に載せる。
- **実効 backend への配線**: `MlRuntime` の production provider が floor 既定の代わりに**実 resolver** を注入する — `experimentalFlag` は設定トグル、`modelState` は `ModelRepository` のモデル有無、`executionProviderProbe` は既存の `ortCpuExecutionProviderProbe` (`app/lib/core/ml/ort_capability_probe.dart:25`)。
- **`imageUpscalerProvider` を async 化** (step 2 で先送りされた配線): `MlRuntime.probe()` の effective backend とモデル source から `resolveImageUpscaler` (`app/lib/core/ml/upscaler_selection.dart:15`) で実 upscaler を解決し、**manga viewer の高画質化アクションを async provider へ移行**する。実験 OFF / モデル未取得時は従来どおり bicubic CPU に劣化する。
- **Localization**: 追加するユーザー可視文字列はすべて `AppLocalizations` (ja/en) 経由で追加し、生リテラルを置かない。
- **依存追加**: SHA-256 検証用に `crypto` (pure-Dart, BSD-3-Clause, 全対象 OS) を追加。DL は既存 `dio`、キャッシュ dir は既存 `path_provider` を使う。

## Capabilities

### New Capabilities

- `upscale-model-distribution`: モデルカタログ・初回 DL・SHA-256 検証・バージョン付き on-disk キャッシュ・サイズ照会・削除を担う `ModelRepository`。`MlRuntime` 向けの `ModelStateResolver` と、選択モデルの `OnnxModelSource` を供給する。
- `ai-upscaler-settings`: 実験的機能ゲート配下の AI アップスケーリング設定 (有効化トグル既定 OFF・既定倍率・モデル管理 UI・上級 backend 上書き) と、その永続化、`MlRuntime` 向けの `ExperimentalFlagResolver` 供給。

### Modified Capabilities

- `ai-image-upscaler`: 「`CpuImageUpscaler` が既定 provider」という要件を、**effective backend 駆動の async provider** へ更新する。`imageUpscalerProvider` は `MlRuntime.probe()` とモデル source に基づき実 upscaler を解決し、manga viewer の高画質化アクションは async provider 経由になる (実験 OFF / モデル未取得時は bicubic floor のまま)。
- `ml-runtime`: 「Riverpod providers for the ML runtime」要件を、**production の `mlRuntimeProvider` が floor 既定ではなく実 resolver (設定トグル・`ModelRepository`・ORT probe) を注入する**よう更新する。`MlRuntime` のクラス契約自体は不変で、注入される resolver が floor から実装に替わる。

## Impact

- **新規コード**: `ModelRepository` とモデルカタログ (`app/lib/core/ml/` 配下、または `features/.../upscale_model/`)、Experimental 設定セクション (`features/settings/presentation/sections/`)、async `imageUpscalerProvider` の配線。
- **変更コード**: `app/lib/core/ml/providers.dart:24` (async 化)、`features/settings/domain/app_settings.dart`・`setting_keys.dart`・`data/settings_codec.dart` (新規キー)、`features/settings/presentation/settings_screen.dart` (セクション登録)、manga viewer の高画質化呼び出し箇所、`app/lib/l10n/*.arb` (ja/en 文字列)。
- **依存**: `crypto` を `app/pubspec.yaml` に追加 (pure-Dart, BSD-3-Clause)。`dio`/`path_provider`/`onnxruntime` は既存。drift schema は据え置き (app_settings は key/value)。
- **ネットワーク**: GitHub Releases への HTTPS GET (モデル取得時のみ・ユーザーが明示的に有効化＋DL したときだけ)。受動取得なし。
- **CI**: モデル実 DL はネットワーク依存のため CI では行わず、`ModelRepository` の検証/キャッシュ/フォールバックはフェイク HTTP クライアント + フィクスチャで単体テストする。

## Non-goals

- **GPU Execution Provider の有効化** (CoreML/NNAPI/DirectML) — ADR-0007 step 4 `enable-gpu-execution-providers` の範囲。本 change は ORT **CPU EP** + bicubic floor のみを実効経路とする。
- **動画 AI** (Anime4K / Real-ESRGAN 動画書き出し / RIFE) — `ImageUpscaler` 対象外の別トラック・別 ADR。
- **実験的機能の卒業** (既定 ON 化・品質保証) — 実測後に別途判断 (ADR-0007 Decision 0)。
- **モデル本体の同梱・クラウド推論** — ADR-0007 を supersede する将来判断。
- **書籍リーダーへの高画質化適用拡大** — 本 change は既存の manga viewer 経路の移行に限定する。
- **drift schema 変更** — 設定は既存 key/value テーブルに載せ、schema バージョンは上げない。
- **実モデルの選定・URL/SHA-256 確定** — 本 change は DL/検証/キャッシュ/配線/UI をフィクスチャモデル (2x/4x) で完成させる。実 ONNX モデルの選定・ライセンス精査・GitHub Releases 配置は follow-up change で行う (実験的機能・既定 OFF のためユーザー影響なし)。
- **上級 backend 上書き UI** — GPU EP を有効化する step4 (`enable-gpu-execution-providers`) に委ねる。本 change は floor 劣化保証 (probe 経路) のみを担保する。

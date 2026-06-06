## 1. GPU EP 可用性 probe (capability: gpu-execution-providers) — TDD

- [x] 1.1 [test] `coremlEp`/`nnapiEp` の可用性 probe が、利用不可ホストでも throw せず bool を返す (no-throw)。`directmlEp` は常に false (red)
- [x] 1.2 GPU EP 可用性 probe を実装: 使い捨て `OrtSessionOptions` に対象 EP を try-append→`release()`、throw は catch して false。`OrtEnv.instance.init()` を前段で呼ぶ
- [x] 1.3 [test] CPU+GPU 統合 probe: `ortCpu`→ORT 初期化判定 / `coremlEp`/`nnapiEp`→GPU probe 委譲 / `directmlEp`→false / never-throw (red→green)
- [x] 1.4 統合 probe を実装し、`OrtSessionOptions` リークなし (try/finally で release) を確認

## 2. OnnxImageUpscaler の EP 対応 (capability: onnx-upscaler-runtime) — TDD

- [x] 2.1 [test] target `ortCpu` で従来どおり `UpscaleResult.backend == ortCpu`、出力寸法は model scale 通り (既存 fixture 回帰、red→green)
- [x] 2.2 [test] GPU target で EP が当該ホストに無いとき、append throw を catch して CPU-only セッションで完走・クラッシュしない (no-throw degrade)
- [x] 2.3 `OnnxImageUpscaler` に `MlBackend targetBackend`(既定 `ortCpu`) を追加。`_ensureSession()` で GPU EP を先に append (coreml/nnapi、throw catch)→CPU を常に append。実際に append できた EP を `UpscaleResult.backend` に報告
- [x] 2.4 [test] (条件付き) CoreML/NNAPI が available なホストでは GPU target で実推論が完走し正しい寸法を返す。**EP 不在時は skip** (既存 onnx fixture テストの skip パターン)

## 3. 選択 seam と provider 配線 (capability: ml-runtime / ai-image-upscaler)

- [x] 3.1 [test] `resolveImageUpscaler`: effective が `coremlEp`/`nnapiEp` かつ model present のとき `OnnxImageUpscaler` を返し target backend が伝搬する / floor 条件は従来どおり (red→green)
- [x] 3.2 `resolveImageUpscaler` を GPU EP も Onnx 経路にする (target backend 伝搬)。`imageUpscalerProvider` の early-return を GPU EP 包含に拡張
- [x] 3.3 統合 probe を `core/ml/` に配線し、production `mlRuntimeProvider` の `executionProviderProbe` を ortCpu-only→統合 probe に差し替え (`providers.dart:42`)
- [x] 3.4 [test] production `mlRuntimeProvider` が統合 probe を注入し、`probe()` が GPU 可用性を反映する (injected fake probe で coremlEp available→effective coremlEp を検証)

## 4. backend 上書き設定 (capability: ai-upscaler-settings)

- [x] 4.1 backend 上書き enum (`auto`/`forceCpu`/`forceGpu`、grill Q1=A) を `domain/` に定義。`setting_keys.dart` に `experimental.ai_upscale_backend_override`(既定 `auto`) を追加し `SettingKeys.all` に登録
- [x] 4.2 `app_settings.dart` にフィールド追加 (copyWith/equality/toString)、`settings_codec.dart` に EnumCodec、`app_settings_repository.dart`(readAll/diff/invertedDefaults) を更新
- [x] 4.3 [test] 既定 `auto`、`forceCpu` 保存→再読込で復元 (drift schema 据え置き、キー数テスト更新)
- [x] 4.4 `MlRuntime` に `preferredOverride`(`MlBackend?` resolver、既定 null) を追加。`preferredBackend()` が override 非 null ならそれを優先。`mlRuntimeProvider` で override+プラットフォーム→resolver を配線 (auto→null / forceCpu→ortCpu / forceGpu→platform GPU EP)
- [x] 4.5 [test] override=forceCpu で preferred が ortCpu になる / override=forceGpu かつ probe 利用不可で floor へ縮退 (injected probe)

## 5. 上書き UI (capability: ai-upscaler-settings)

- [x] 5.1 `experimental_section.dart` に backend 上書き UI (Auto / 強制 CPU / 強制 GPU の 3 択、grill Q1=A) を追加。強制 GPU 利用不可時は CPU 縮退の注記。設定へ mutate
- [x] 5.2 [test] 上書き UI のレンダリング (既定 Auto 選択、選択肢表示) — render-only (mutate/IO は unit でカバー)

## 6. ローカライズ

- [x] 6.1 上書き UI の新規文字列を `app_ja.arb`(テンプレート)・`app_en.arb` に追加し `flutter gen-l10n` 再生成 (`AppLocalizations` 経由、生リテラル禁止)
- [x] 6.2 ARB key parity test が緑

## 7. 検証

- [x] 7.1 `dart format lib test`
- [x] 7.2 `flutter analyze --fatal-infos` がクリーン
- [x] 7.3 `flutter test` 全緑 (probe・upscaler・selection・provider・設定・UI・parity)。実 GPU 非依存 (GPU EP 実推論は不在時 skip)
- [x] 7.4 `openspec validate enable-gpu-execution-providers --strict` が通る
- [x] 7.5 `git diff --check` で空白エラーなし
- [x] 7.6 `docs/adr/0007-ai-upscaling-runtime-strategy.md` に **amendment 節**を追記し Windows DirectML の現実（パッケージ非対応・ortCpu 縮退）を明文化 (grill Q3=B)。`docs/roadmap.md`・`docs/HANDOFF.md` の ADR-0007 シーケンス step4 を ✅ に更新

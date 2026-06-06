## 1. セットアップと依存

- [x] 1.1 `app/pubspec.yaml` に `crypto` (pure-Dart, BSD-3-Clause) を追加し、`flutter pub get` を実行
- [x] 1.2 `THIRD_PARTY_NOTICES.md` に `crypto` のライセンス表記を追加
- [x] 1.3 モデルカタログの const 定義 (`modelId` / `version` / `url` / `sha256` / `scale` / `license`) を `app/lib/core/ml/upscale_model_catalog.dart` に作成。**2x と 4x のフィクスチャモデルのエントリ**を用意し、DL/検証/配線/テストを完成させる。実 ONNX モデルの選定・URL/SHA-256・GitHub Releases 配置は follow-up change (grill Q1=A)

## 2. ModelRepository (capability: upscale-model-distribution) — TDD

- [x] 2.1 注入可能な `ModelDownloader` 抽象 (実装は `dio` の `DioModelDownloader`、テストはフェイク) を定義
- [x] 2.2 [test] ハッシュ一致でモデルが `<appSupport>/ml_models/<id>/<version>/model.onnx` に確定し、パスを返す (red)
- [x] 2.3 [test] ハッシュ不一致で temp を破棄し catchable エラー、キャッシュは absent のまま (red)
- [x] 2.4 [test] ネットワーク/HTTP/I-O 失敗で catchable エラー + absent 維持 (red)
- [x] 2.5 [test] 同一 id・version がキャッシュ済みなら再 DL せず既存パスを返す / 異なる version はパス分離 (red)
- [x] 2.6 [test] 状態照会 (present/absent)・on-disk サイズ・削除 (削除後 absent、再削除は no-op) (red)
- [x] 2.7 `ModelRepository` を実装し 2.2–2.6 を green に (temp→SHA-256 検証→原子的 rename、`path_provider` 配下)
- [x] 2.8 選択中モデルから `ModelStateResolver` (present/absent) と `OnnxModelSource.file` を供給するヘルパを実装し、テストで present/absent 双方を検証

## 3. 設定の永続化 (capability: ai-upscaler-settings)

- [x] 3.1 `setting_keys.dart` に dotted-namespace キーを追加 (規約 `^[a-z][a-z_]*(\.[a-z][a-z_]*)+$`): `experimental.ai_upscale_enabled`(bool,既定 false)・`experimental.ai_upscale_scale`(int,既定 2)。`SettingKeys.all` にも追加。(model_id は scale 駆動のため不要 — grill 反映)
- [x] 3.2 `domain/app_settings.dart` にフィールド (`aiUpscaleEnabled`/`aiUpscaleScale`) を追加し `copyWith`/equality/toString と repository(readAll/diff/invertedDefaults) を更新。既存 `BoolCodec`/`IntCodec` を再利用
- [x] 3.3 [test] 既定値 (OFF/2) で読み込まれ、保存→再読込でトグル ON + scale 4 が復元される (drift schema 据え置き、既存キー数テスト 13→15 を更新)
- [x] 3.4 有効化トグル値を返す `ExperimentalFlagResolver` を `appSettingsProvider` 経由で `mlRuntimeProvider` に供給 (Group 4 で配線)

## 4. provider 配線 (capability: ml-runtime / ai-image-upscaler)

- [x] 4.1 [test] production `mlRuntimeProvider` が実 resolver (experimentalFlag=設定, modelState=repo, probe=`ortCpuExecutionProviderProbe`) を注入し、`probe()` がトグル/モデル有無を反映する
- [x] 4.2 `providers.dart` の `mlRuntimeProvider` を floor 既定から実 resolver 注入へ変更。`modelRepositoryProvider` を新設 (Dio + path_provider)
- [x] 4.3 [test] `imageUpscalerProvider` (async): 実験 OFF→Cpu / モデル未取得→Cpu / ortCpu+present→Onnx に解決する。override 維持も検証
- [x] 4.4 `imageUpscalerProvider` を `FutureProvider` 化し、`probe()` + モデル source + `resolveImageUpscaler` で解決。floor 経路は settings/DB 非依存

## 5. 設定 UI (capability: ai-upscaler-settings)

- [x] 5.1 `features/settings/presentation/sections/experimental_section.dart` を作成: Experimental ラベル + 保証しない旨の注意書き + 有効化トグル (既定 OFF)。[test] レンダリング検証
- [x] 5.2 既定スケール選択 (2x / 4x・既定 2x) と、設定反映ポリシー (次回実行時反映) の開示文を追加。4x 永続化は repo round-trip テスト (3.3) でカバー
- [x] 5.3 モデル管理 UI: 状態 (未取得/取得済み)・on-disk サイズ・DL (進捗表示)・削除を `ModelRepository` に委譲。DL/削除は ModelRepository テスト (2.x) でカバー
- [x] 5.4 `settings_screen.dart` にセクションを登録 (R18 と About の間、10→11 sections、既存テスト更新)
<!-- 上級 backend 上書き UI は step4 (enable-gpu-execution-providers) 送り (grill Q3=A)。floor 劣化保証は §4 の probe 経路テストで担保 -->

## 6. manga viewer 移行 (capability: ai-image-upscaler)

- [x] 6.1 高画質化アクションを同期 `ref.read` から `ref.read(imageUpscalerProvider.future)` ベースの async 取得へ移行し、倍率は設定値 (`appSettingsProvider`) を使用
- [x] 6.2 縮退挙動 (`_upscaling` 中インジケータ、エラー時ローカライズ snackbar + 元ページ維持) は既存 try/catch 構造を維持。エラー縮退は `OnnxImageUpscaler` catchable error + provider floor テストでカバー (UI 実アーカイブ駆動テストは pending-timer で不安定なため不採用)
- [x] 6.3 [test] 高画質化ボタン表示・ツールチップ・空アーカイブ tap 無例外 (既存 manga_viewer_upscale_test 緑維持)

## 7. ローカライズ

- [x] 7.1 実験的機能セクション/モデル管理/エラーの 11 文字列を `app_ja.arb`(テンプレート)・`app_en.arb` に追加し `flutter gen-l10n` 再生成 (`AppLocalizations` 経由、生リテラル禁止)
- [x] 7.2 ARB key parity test (ja/en 欠落検出) が緑であることを確認 (全 test スイートで検証)

## 8. 検証

- [x] 8.1 `dart format lib test` を実行し整形
- [x] 8.2 `flutter analyze --fatal-infos` がクリーン（No issues found）
- [x] 8.3 `flutter test` 全緑（+567、ModelRepository・provider・設定・manga viewer・parity）。実ネットワーク/GPU 非依存
- [x] 8.4 `openspec validate add-upscale-model-distribution --strict` が通る
- [x] 8.5 `git diff --check` で空白エラーなし
- [x] 8.6 `docs/roadmap.md` の v1.0 状態と ADR-0007 シーケンス、`docs/HANDOFF.md` §9 step2/step3 を ✅ に更新

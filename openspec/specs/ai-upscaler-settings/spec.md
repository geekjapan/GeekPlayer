# ai-upscaler-settings Specification

## Purpose

Exposes AI upscaling to users as an opt-in experimental feature in settings: an Experimental section with an enable toggle (default OFF), persisted enable/scale preferences via `AppSettings`, a model management UI delegating to the `ModelRepository`, and a default scale-factor selector. Supplies the `MlRuntime` seam with an `ExperimentalFlagResolver`, and keeps the effective backend probe-driven so it degrades to the bicubic CPU floor. All user-visible strings are localized (ja/en).

## Requirements

### Requirement: 実験的機能セクションと有効化トグル

設定画面は、AI アップスケーリングを「実験的機能 (Experimental)」セクション配下に表示しなければならない (SHALL)。有効化トグルの既定値は **OFF** でなければならない (MUST)。セクションは、品質・性能・安定性を保証せず将来仕様変更や削除があり得る旨のローカライズ済み注意書きを表示しなければならない (SHALL)。

#### Scenario: 既定で実験的機能は OFF

- **WHEN** 永続化された設定がない初期状態で設定画面を開く
- **THEN** AI アップスケーリングの有効化トグルは OFF で表示される

#### Scenario: Experimental の注意書きが表示される

- **WHEN** 実験的機能セクションを表示する
- **THEN** Experimental ラベルと、保証しない旨のローカライズ済み注意書きが表示される

### Requirement: 設定の永続化

有効化トグルと既定スケール倍率は `AppSettings` に追加され、既存の key/value 永続化 (drift `app_settings` テーブル) を通じて保存・復元されなければならない (MUST)。本 change は drift schema バージョンを変更してはならない (MUST NOT)。選択されるモデルは設定された倍率から `UpscaleModelCatalog.forScale` で導出されるため、別個のモデル ID キーは本 change では必須ではない (将来の多モデルファミリ対応で追加しうる)。

#### Scenario: トグルが永続化される

- **GIVEN** ユーザーが AI アップスケーリングを ON にする
- **WHEN** アプリを再起動して設定を読み込む
- **THEN** トグルは ON のまま復元される

#### Scenario: schema バージョンは据え置き

- **WHEN** 本 change の前後で drift schema バージョンを比較する
- **THEN** schema バージョンは変化しない

### Requirement: モデル管理 UI

実験的機能セクションは、選択中モデルの管理 UI を提供しなければならない (SHALL): モデルの状態 (未取得 / 取得済み)、on-disk サイズ、ダウンロード操作 (進捗表示付き)、削除操作。これらは `upscale-model-distribution` の `ModelRepository` に委譲する。すべての文言はローカライズ済みでなければならない (MUST)。

#### Scenario: 未取得モデルにダウンロード操作を出す

- **GIVEN** 選択中モデルが未取得
- **WHEN** モデル管理 UI を表示する
- **THEN** 状態は「未取得」で、ローカライズ済みのダウンロード操作が表示される

#### Scenario: 取得済みモデルにサイズと削除を出す

- **GIVEN** 選択中モデルが取得済み
- **WHEN** モデル管理 UI を表示する
- **THEN** on-disk サイズと、ローカライズ済みの削除操作が表示される

#### Scenario: ダウンロード中は進捗を表示する

- **WHEN** モデルのダウンロードが進行中である
- **THEN** 進捗インジケータが表示され、完了するとモデル状態が「取得済み」へ更新される

### Requirement: 既定スケール倍率の選択

実験的機能セクションは、AI アップスケーリングの既定スケール倍率を **2x または 4x** から選択する手段を提供しなければならない (SHALL)。既定値は 2x でなければならない (MUST)。選択した倍率は永続化され、manga viewer の高画質化アクションが使用する倍率になる。

#### Scenario: 既定は 2x

- **WHEN** 永続化された設定がない初期状態でスケール設定を参照する
- **THEN** 既定スケール倍率は 2x である

#### Scenario: 4x を選択して永続化する

- **GIVEN** ユーザーが既定スケール倍率を 4x に変更する
- **WHEN** アプリを再起動して設定を読み込む
- **THEN** 既定スケール倍率は 4x のまま復元され、高画質化アクションは 4x を使用する

### Requirement: 実効 backend は probe に従い floor へ劣化する

実効 backend は、ADR-0007 のフォールバック連鎖と `MlRuntime.probe()` の結果に従わなければならない (MUST)。設定で要求された backend が利用不可な場合でも、bicubic CPU floor に劣化し、クラッシュしてはならない (MUST NOT)。上級者向けの preferred backend 上書き UI は本 capability では提供せず、GPU Execution Provider を有効化する step4 (`enable-gpu-execution-providers`) に委ねる。

#### Scenario: 利用不可な preferred backend は floor に劣化する

- **GIVEN** preferred backend が GPU EP だが、その EP が当該プラットフォームで利用不可
- **WHEN** 実効 backend が `MlRuntime.probe()` で解決される
- **THEN** probe により ORT CPU もしくは bicubic CPU floor に劣化し、クラッシュしない

### Requirement: `MlRuntime` 向けの ExperimentalFlagResolver 供給

`ai-upscaler-settings` は、有効化トグルの現在値を返す `ExperimentalFlagResolver` を `MlRuntime` に供給しなければならない (MUST)。トグルが OFF の間、`MlRuntime.probe()` の実効 backend は bicubic CPU でなければならない (MUST)。

#### Scenario: OFF のとき実効 backend は bicubic CPU

- **GIVEN** 有効化トグルが OFF
- **WHEN** `MlRuntime.probe()` が実行される
- **THEN** 実効 backend は `MlBackend.bicubicCpu` で、reason は実験的機能が無効である旨を示す

### Requirement: 設定 UI のローカライズ

実験的機能セクションの新規ユーザー可視文字列はすべて `AppLocalizations` (ja/en) 経由で提供しなければならない (MUST)。生のリテラル文字列を UI に置いてはならない (MUST NOT)。

#### Scenario: 日本語ロケールでセクション文言が表示される

- **WHEN** ロケールが日本語で実験的機能セクションを表示する
- **THEN** すべての文言が日本語のローカライズ済みリソースから供給される

#### Scenario: 英語ロケールでセクション文言が表示される

- **WHEN** ロケールが英語で実験的機能セクションを表示する
- **THEN** すべての文言が英語のローカライズ済みリソースから供給される

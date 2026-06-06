## MODIFIED Requirements

### Requirement: CpuImageUpscaler is the default provider

`imageUpscalerProvider` は、`MlRuntime.probe()` の実効 backend と選択中モデルの有無に基づいて `ImageUpscaler` を非同期に解決しなければならない (SHALL)。実効 backend が `MlBackend.ortCpu` で、かつ検証済みモデルの `OnnxModelSource` が存在するとき `OnnxImageUpscaler` を返す。それ以外 (実験的機能 OFF、モデル未取得、ORT 利用不可) のとき、bicubic floor の `CpuImageUpscaler` を返す。解決は `resolveImageUpscaler` の純粋 seam を通さなければならない (MUST)。

#### Scenario: 実験 OFF では CpuImageUpscaler に解決する

- **WHEN** 実験的機能が OFF の状態で `imageUpscalerProvider` を読む
- **THEN** 返るインスタンスは `CpuImageUpscaler` である

#### Scenario: モデル未取得では CpuImageUpscaler に解決する

- **GIVEN** 実験的機能は ON だが、選択中モデルが未取得
- **WHEN** `imageUpscalerProvider` を読む
- **THEN** 返るインスタンスは `CpuImageUpscaler` である

#### Scenario: ortCpu かつモデル present では OnnxImageUpscaler に解決する

- **GIVEN** 実験的機能が ON、実効 backend が `MlBackend.ortCpu`、検証済みモデルが present
- **WHEN** `imageUpscalerProvider` を読む
- **THEN** 返るインスタンスは `OnnxImageUpscaler` である

### Requirement: Manga viewer upscale action

The manga viewer SHALL display a "高画質化 / Upscale" icon button in the AppBar. Tapping it SHALL upscale the current page at the configured scale using the asynchronously-resolved `imageUpscalerProvider` and display the upscaled image. A progress indicator SHALL be shown while the upscaler is resolving or upscaling. On error, a localized error message SHALL be displayed, and the page SHALL remain viewable (degrade, never crash).

#### Scenario: Upscale button is visible in AppBar

- **WHEN** the manga viewer screen is displayed with controls visible
- **THEN** an `Icons.auto_fix_high` icon button with the localized upscale tooltip is present in the AppBar

#### Scenario: Upscale in-progress shows indicator

- **WHEN** the upscale action is tapped and the upscaler has not yet returned
- **THEN** a `CircularProgressIndicator` is visible

#### Scenario: Upscale error degrades without crashing

- **WHEN** the resolved upscaler throws during upscaling
- **THEN** a localized error message is shown and the original page remains viewable

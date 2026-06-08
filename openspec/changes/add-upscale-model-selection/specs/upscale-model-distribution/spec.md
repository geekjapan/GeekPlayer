## ADDED Requirements

### Requirement: 実モデル選定基準

配布カタログ (`UpscaleModelCatalog`) の各**恒久エントリ**は、次のすべてを満たす実モデルを指さなければならない (MUST): (1) 寛容ライセンス（BSD-3-Clause または MIT など、利用制限のないもの）、(2) 同梱ネイティブランタイム ONNX Runtime 1.15.1 が対応する opset（≤19、推奨エクスポート opset 17）、(3) アニメ/イラスト向けにチューニングされたモデル系統。nearest-neighbor 等の fixture/placeholder モデルを恒久エントリにしてはならない (MUST NOT)。Research-only RAIL など利用制限付きライセンスのモデルを採用してはならない (MUST NOT)。

#### Scenario: 恒久エントリが選定基準を満たす

- **WHEN** カタログの任意の恒久エントリ（2x / 4x）を参照する
- **THEN** そのエントリは寛容ライセンス・ORT 1.15.1 互換 opset・anime-tuned 系統の実モデルを指し、license フィールドが実際の weights ライセンスと一致する

#### Scenario: fixture は恒久エントリにしない

- **WHEN** 出荷ビルドのカタログを検査する
- **THEN** nearest-neighbor 等の placeholder/fixture モデルは恒久エントリに含まれない（テスト専用 fixture はテストコード側に限定する）

### Requirement: 採用モデルの出所とライセンスの追跡可能性

カタログの各恒久エントリについて、システムは採用モデルの**出所（upstream）とライセンス根拠**を変更成果物に記録しなければならない (MUST)。2x・4x の両スロットは **RealESRGAN_x4plus_anime_6B**（xinntao/Real-ESRGAN, BSD-3-Clause）を採用し、ホスト前に upstream リポジトリの LICENSE を直接確認しなければならない (MUST)。2x スロットは別モデルを持たず、4x モデルを native 4x で実行し ×0.5 縮小して得る（`modelScale`/`downscaleFactor`、design D8）。

#### Scenario: ライセンス根拠が確認済みである

- **GIVEN** カタログに登録予定の採用モデル
- **WHEN** GitHub Release にホストする前
- **THEN** upstream リポジトリの LICENSE を直接確認した記録があり、license フィールドがそれと一致する

#### Scenario: 2x は 4x モデルの downscale で供給する

- **WHEN** 2x スロットのエントリを参照する
- **THEN** `modelScale` は 4、`scale` は 2、`downscaleFactor` は 2 であり、4x スロットと同一のモデル（同一 URL・SHA-256）を指す

### Requirement: target scale への downscale

native scale（`modelScale`）が target `scale` を上回るエントリについて、システムは、モデルを native scale で実行した出力を `modelScale / scale` で縮小し、最終出力が入力 × `scale` の寸法になるようにしなければならない (MUST)。縮小はエイリアシングを抑える補間（average 等）で行う。

#### Scenario: 4x モデルで 2x 出力を得る

- **GIVEN** `modelScale=4`・`scale=2` のエントリと寸法 W×H の入力
- **WHEN** アップスケールを実行する
- **THEN** モデルは 4x で推論し、出力は ×0.5 縮小されて (W·2)×(H·2) になる

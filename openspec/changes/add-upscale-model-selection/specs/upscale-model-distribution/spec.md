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

カタログの各恒久エントリについて、システムは採用モデルの**出所（upstream）とライセンス根拠**を変更成果物に記録しなければならない (MUST)。2x は waifu2x (nagadomi/nunif, MIT)、4x は RealESRGAN_x4plus_anime_6B (xinntao/Real-ESRGAN, BSD-3-Clause) を既定採用とし、ホスト前に upstream リポジトリの LICENSE を直接確認しなければならない (MUST)。

#### Scenario: ライセンス根拠が確認済みである

- **GIVEN** カタログに登録予定の採用モデル
- **WHEN** GitHub Release にホストする前
- **THEN** upstream リポジトリの LICENSE を直接確認した記録があり、license フィールドがそれと一致する

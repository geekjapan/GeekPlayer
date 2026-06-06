## ADDED Requirements

### Requirement: GPU Execution Provider availability probe

システムは、ONNX Runtime の GPU Execution Provider（CoreML / NNAPI）が現在のプラットフォームで初期化可能かを報告する probe を提供しなければならない (SHALL)。probe は使い捨ての `OrtSessionOptions` に対象 EP を append し、成功すれば available、失敗（throw）すれば unavailable を返す。probe は決して throw してはならない (MUST NOT)。

#### Scenario: CoreML EP が利用可能なとき available を返す

- **GIVEN** ONNX Runtime が CoreML EP を含むビルドで動作するプラットフォーム
- **WHEN** `coremlEp` の可用性 probe を評価する
- **THEN** available を返し、throw しない

#### Scenario: 利用不可な EP は unavailable を返し throw しない

- **GIVEN** 対象 GPU EP が当該プラットフォームのネイティブビルドに含まれない
- **WHEN** その EP の可用性 probe を評価する
- **THEN** unavailable を返し、throw しない

### Requirement: DirectML は常に利用不可を報告する

`directmlEp` の可用性 probe は常に unavailable を返さなければならない (MUST)。`onnxruntime` 1.4.1 パッケージの高レベル API は DirectML を公開していないため、Windows GPU 経路は提供されず、フォールバック連鎖により ORT CPU EP に縮退する。

#### Scenario: DirectML probe は常に false

- **WHEN** `directmlEp` の可用性 probe を評価する
- **THEN** プラットフォームに関わらず unavailable を返す

### Requirement: CPU+GPU 統合 Execution Provider probe

システムは、`MlRuntime` の `ExecutionProviderProbe` シームに適合する統合 probe を提供しなければならない (SHALL)。統合 probe は `ortCpu` に対しては ORT 初期化可否を、`coremlEp`/`nnapiEp` に対しては GPU EP 可用性 probe を、`directmlEp` に対しては常に false を返す。probe は決して throw してはならない (MUST NOT)。

#### Scenario: ortCpu は ORT 初期化で判定

- **WHEN** 統合 probe を `ortCpu` で評価する
- **THEN** ONNX Runtime が初期化できれば available を返す

#### Scenario: GPU EP は可用性 probe に委譲

- **WHEN** 統合 probe を `coremlEp` または `nnapiEp` で評価する
- **THEN** 対応する GPU EP 可用性 probe の結果を返す

### Requirement: probe は実 GPU 無しの CI で安全に評価できる

GPU EP 可用性 probe と統合 probe は、実 GPU やアクセラレータの無いホスト（CI 含む）でも throw せず bool を返さなければならない (MUST)。EP が利用不可な環境では unavailable を返すだけで、テストスイートを失敗させてはならない (MUST NOT)。

#### Scenario: GPU 無しホストで probe が解決する

- **GIVEN** GPU アクセラレータの無いテストホスト
- **WHEN** 各 EP の可用性 probe を評価する
- **THEN** いずれも throw せず bool（多くは unavailable）を返し、テストは緑のまま

## ADDED Requirements

### Requirement: 動画 AI パイプラインのアーキテクチャ分解が ADR として文書化されている

システムは、v1.x 動画 AI パイプライン（Anime4K リアルタイムシェーダ、Real-ESRGAN 動画オフライン書き出し、RIFE フレーム補間）のアーキテクチャ分解方針を `docs/adr/0008-video-ai-pipeline-rendering-strategy.md` に文書化しなければならない (MUST)。当該 ADR は、リアルタイムシェーダ経路とオフラインバッチ経路が異なる設計軸を持つことの説明、Considered Options、および Decision の最終確定を各後続 change の design 段階へ委ねる旨を含まなければならない (MUST)。

#### Scenario: ADR-0008 がリアルタイム/オフラインの区別を説明している

- **WHEN** 開発者が `docs/adr/0008-video-ai-pipeline-rendering-strategy.md` を読む
- **THEN** Anime4K（リアルタイム GPU シェーダ）と Real-ESRGAN 動画/RIFE（オフラインバッチ）が異なる設計軸を持つことの説明、および Considered Options のセクションが存在する

#### Scenario: ADR-0008 が Decision 確定の委譲先を明記している

- **WHEN** 開発者が ADR-0008 の「Decision の位置づけ」セクションを読む
- **THEN** シェーダフック方式（Option A/B）とオフライン共通ジョブ抽象の要否（Option C/D）の最終確定が、それぞれどの後続 change の design 段階で行われるかが明記されている

### Requirement: 後続 OpenSpec change への分割計画が識別可能である

システムは、動画 AI パイプライン 3 項目に対応する後続 OpenSpec change 候補（名称・スコープ・依存関係）を `openspec/changes/decompose-v1x-video-ai-pipeline/design.md` に列挙しなければならない (MUST)。各候補は ADR-0008 への参照、および着手前に必要な調査項目（プラットフォーム対応、GPU/ランタイム依存、ライセンス、バイナリサイズ影響、検証ハードウェア）のうち該当するものを含まなければならない (MUST)。

#### Scenario: 3 本の後続 change 候補が名前・依存関係付きで列挙されている

- **WHEN** 開発者が本 change の `design.md` の "D2" セクションを読む
- **THEN** `add-anime4k-realtime-shader` / `add-realesrgan-video-export` / `add-rife-frame-interpolation`（いずれも仮称）が、それぞれの ADR-0008 への依存関係とともに列挙されている

#### Scenario: 共通オフライン基盤の切り出し判断が先送りされていることが明記されている

- **WHEN** 開発者が `design.md` の "D2" セクションを読む
- **THEN** Real-ESRGAN 動画書き出しと RIFE フレーム補間が共有しうる「オフライン変換ジョブ」抽象を独立 change として切り出すか否かの判断が、`add-realesrgan-video-export` の design 段階に委ねられていることが明記されている

### Requirement: roadmap がアーキテクチャ分解の完了と後続計画を反映している

`docs/roadmap.md` の v1.0 セクションにある動画 AI パイプライン 3 項目の記述は、ADR-0008 の起票と後続 change 分割計画への参照を含まなければならない (MUST)。

#### Scenario: roadmap が ADR-0008 と後続 change 分割計画にリンクしている

- **WHEN** 開発者が `docs/roadmap.md` の v1.0 セクション中「動画リアルタイム」「動画オフライン書き出し」「フレーム補間」の直後にある状態注記を読む
- **THEN** `docs/adr/0008-video-ai-pipeline-rendering-strategy.md` へのリンクと、3 本の後続 change 仮称名が記載されている

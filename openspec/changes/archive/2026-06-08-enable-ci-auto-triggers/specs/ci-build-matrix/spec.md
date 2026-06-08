## ADDED Requirements

### Requirement: CI workflow trigger events と concurrency

CI ワークフロー（`.github/workflows/ci.yaml`）は、以下のトリガーイベントで発火しなければならない (MUST): `main` ブランチへの `push`、`main` ブランチを base とする `pull_request`、および手動実行用の `workflow_dispatch`。さらにワークフローは ref 単位の `concurrency` グループ（同一 ref の新しい run が古い run を `cancel-in-progress` で打ち切る）を MUST 設定し、同一ブランチへの連続 push で無駄な並列実行が積み上がらないようにする。`push` は `main` に限定し (MUST)、feature ブランチの検証は main 宛 `pull_request` で行うことで、PR とマージ後の二重実行を避ける。

#### Scenario: main への push で CI が自動発火する

- **WHEN** `main` ブランチへコミットが push される
- **THEN** CI ワークフローが `workflow_dispatch` を待たずに自動でトリガーされ、6 ジョブ matrix が実行される

#### Scenario: main 宛 PR で CI が自動発火する

- **WHEN** `main` を base とする pull request が open / 更新される
- **THEN** CI ワークフローが自動でトリガーされ、6 ジョブ matrix が実行される

#### Scenario: 手動 dispatch が引き続き可能

- **WHEN** ユーザーが GitHub UI / API から workflow を手動実行する
- **THEN** `workflow_dispatch` トリガーにより CI が実行される

#### Scenario: 同一 ref の連続 push で古い run が打ち切られる

- **GIVEN** ある ref の CI run が進行中
- **WHEN** 同じ ref に新しい push が来て新しい run が開始される
- **THEN** concurrency グループにより進行中の古い run が cancel され、最新コミットの run のみが残る

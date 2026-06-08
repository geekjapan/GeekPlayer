## Why

CI ワークフロー（`.github/workflows/ci.yaml`）は現在 `on: workflow_dispatch:` のみで、push / PR では一切自動実行されない。回帰検知は手動 dispatch 頼みで実効性が低い。元々の意図（`ci-build-matrix` spec の「push to `main` triggers the CI workflow」シナリオ）と実装が乖離している。リポジトリを public 化したことで GitHub Actions が無料になり、以前の「課金上限で全 CI 失敗」ブロッカーも解消したため、自動トリガーを復活させる好機。

## What Changes

- `ci.yaml` のトリガーに `push`（`branches: [main]`）と `pull_request`（`branches: [main]`）を追加する。`workflow_dispatch` は手動再実行用に維持。
- 同一 ref で新しい push が来たら進行中の古い run を打ち切る `concurrency` グループ（`group: ci-${{ github.ref }}`, `cancel-in-progress: true`）を追加し、無駄な並列実行を抑える。
- feature ブランチへの push は `pull_request`（main 宛 PR がある場合）でカバーし、`push` は `main` のみに限定して PR とマージ後の二重実行を避ける。
- ジョブ定義（6 ジョブ）の内容は変更しない。トリガーと concurrency の追加のみ。

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `ci-build-matrix`: CI ワークフローが発火するトリガーイベント（`push` to main / `pull_request` to main / `workflow_dispatch`）と、ref 単位の concurrency による古い run の打ち切りを規定する新規要件を追加する。

## Impact

- 変更ファイル: `.github/workflows/ci.yaml`（トリガー + concurrency ブロックのみ）。ジョブ・ステップは不変。
- spec: `openspec/specs/ci-build-matrix/spec.md`（delta 経由で trigger 要件を追加）。
- 挙動: main への push と main 宛 PR で 6 ジョブ matrix が自動実行されるようになる（public repo のため追加コストなし）。
- アプリ実行コード・依存・スキーマへの影響なし。

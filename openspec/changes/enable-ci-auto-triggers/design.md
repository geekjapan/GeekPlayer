## Context

`.github/workflows/ci.yaml` は 6 ジョブ（analyze-and-test / build-android-debug / build-windows-release / build-macos / build-linux / build-ios）を持つが、トリガーは `on: workflow_dispatch:` のみ。push / PR で自動実行されない。`ci-build-matrix` spec には「push to `main` triggers the CI workflow」というシナリオが既にあり、実装が意図に追いついていない。

過去のブロッカー（GitHub Actions の課金上限で全 run が runner 起動時に即失敗）はリポジトリ public 化により解消（public repo は標準 runner の Actions 分が無料）。`release-artifacts.yaml` は別ワークフローで、本変更の対象外。

## Goals / Non-Goals

**Goals:**
- main への push と main 宛 PR で CI matrix が自動実行されるようにする。
- 同一 ref の連続 push で古い run を自動 cancel し、runner 時間と queue を節約する。
- 手動再実行（`workflow_dispatch`）を維持する。
- spec と実装の乖離を解消する。

**Non-Goals:**
- ジョブ・ステップ内容の変更（Flutter version, build コマンド, artifact 設定はすべて不変）。
- `release-artifacts.yaml` のトリガー変更。
- path filter による選択的ジョブ実行や、ジョブ間 `needs` 依存の導入（将来課題）。
- branch protection / required status checks の設定（GitHub 設定側の話で、ワークフロー YAML の範囲外）。

## Decisions

### D1: トリガーイベントの構成
`on:` を次の 3 つにする:
```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
```
- **push を main 限定にする理由**: feature ブランチへの push まで `push` で拾うと、main 宛 PR がある場合に `push`(feature) と `pull_request` の二重実行になる。`push: main` + `pull_request: main` にすれば、feature 作業は PR の `pull_request` で 1 回、main マージ後は `push: main` で 1 回となり重複しない。
- `workflow_dispatch` は手動再実行・デバッグ用に残す。

### D2: concurrency による古い run の打ち切り
ワークフロー top-level に追加:
```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```
- `github.ref` 単位でグループ化。PR ブランチへの連続 push で古い run を cancel。
- `cancel-in-progress: true`: 最新コミットのみ検証すれば十分（中間コミットの結果は不要）。
- main への push は通常 squash-merge 1 件ずつなので cancel は稀だが、設定して害はない。

### D3: ジョブ定義は触らない
6 ジョブの steps・runner・artifact 設定は完全に現状維持。diff はファイル冒頭の `on:` / `concurrency:` ブロックのみ。

## Risks / Trade-offs

- **macOS/Windows runner の消費**: public repo なので無料。ただし PR ごとに 6 ジョブ（うち macOS×2: build-macos, build-ios）が走り wall-clock は長め。path filter 等の最適化は Non-Goal とし、まず自動化の価値を取る。
- **CI の現状未検証**: 課金ブロッカー解消後、実際に runner が起動するかは本変更を main にマージして push トリガーが発火するまで確証が無い。apply 時にローカルで YAML 妥当性（構文）を検証し、マージ後の初回自動 run で実走を確認する。
- **二重実行の見落とし**: D1 の `push: main` + `pull_request: main` 構成で回避済み。`push` を全ブランチにすると重複するため明示的に main 限定とする。
- **可逆性**: トリガー追加のみ。問題があれば `on:` を `workflow_dispatch:` に戻すだけで原状復帰できる。

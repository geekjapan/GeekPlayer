## 1. トリガー + concurrency 実装

- [x] 1.1 `.github/workflows/ci.yaml` の `on:` を `push`(branches: [main]) / `pull_request`(branches: [main]) / `workflow_dispatch` の 3 トリガーに変更（design D1）
- [x] 1.2 ワークフロー top-level に `concurrency`（`group: ci-${{ github.ref }}`, `cancel-in-progress: true`）を追加（design D2）
- [x] 1.3 6 ジョブの steps / runner / artifact 設定は無変更であることを diff で確認（design D3）。diff は純粋に 8 行追加（trigger + concurrency ブロックのみ）、job 行の変更なし

## 2. 検証

- [x] 2.1 YAML 構文の妥当性を確認（`python3 -c "import yaml; yaml.safe_load(...)"` で parse 成功、6 ジョブ検出）
- [x] 2.2 `on:` に push/pull_request/workflow_dispatch が揃い、push/pull_request とも `branches: [main]`、concurrency=`ci-${{ github.ref }}`/cancel-in-progress=true を確認
- [x] 2.3 `openspec validate enable-ci-auto-triggers --strict` パス
- [x] 2.4 **マージ後フォローアップ**: 本変更が main にマージされた push 自体が初回自動 run のトリガーになる。マージ直後に `gh run list` で 6 ジョブの起動を確認する（public repo・Actions 無料化後の実走確認）

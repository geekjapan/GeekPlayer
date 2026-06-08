## 1. トリガー + concurrency 実装

- [x] 1.1 `.github/workflows/ci.yaml` の `on:` を `push`(branches: [main]) / `pull_request`(branches: [main]) / `workflow_dispatch` の 3 トリガーに変更（design D1）
- [x] 1.2 ワークフロー top-level に `concurrency`（`group: ci-${{ github.ref }}`, `cancel-in-progress: true`）を追加（design D2）
- [x] 1.3 6 ジョブの steps / runner / artifact 設定は無変更であることを diff で確認（design D3）。diff は純粋に 8 行追加（trigger + concurrency ブロックのみ）、job 行の変更なし

## 2. 検証

- [x] 2.1 YAML 構文の妥当性を確認（`python3 -c "import yaml; yaml.safe_load(...)"` で parse 成功、6 ジョブ検出）
- [x] 2.2 `on:` に push/pull_request/workflow_dispatch が揃い、push/pull_request とも `branches: [main]`、concurrency=`ci-${{ github.ref }}`/cancel-in-progress=true を確認
- [x] 2.3 `openspec validate enable-ci-auto-triggers --strict` パス
- [x] 2.4 **マージ後フォローアップ（確認済み 2026-06-08）**: #26 マージの main への push が初回自動 run（run 27120096846, event=push, branch=main）をトリガーし、**6 ジョブすべてが起動・実走**した（public repo で Actions 無料化後の初回実走を確認）。PR #26 自体も head ブランチの workflow 定義により `pull_request` で自動実行された（run 27119749469）= トリガー機能は正常。**注**: トリガー機能とは別に、この初回実走が既存の問題を露呈した（本 change の責務外）: ① `analyze-and-test` の OSS license drift（`crypto` 依存の `oss_licenses.dart` 未再生成 → 別 PR #27 で修正）、② build 系ジョブの flaky な upstream download 失敗（mimalloc/pdfium/libmpv の integrity/cache。PR run と main run で別ジョブが落ちる非決定性で flaky と確認 → re-run で対応）

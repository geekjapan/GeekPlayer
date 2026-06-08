# Grill — enable-ci-auto-triggers (20260608)

## enable-ci-auto-triggers — 残課題なし (20260608)

Phase 1（自己グリル）/ Phase 2（cross-cutting、単一 change のため自明）を実施。すべて docs/コード/design から判断可能で、ユーザー確認が必須の残課題は無し。検討した論点と結論:

- **二重実行回避**: `push: branches: [main]` + `pull_request: branches: [main]` の構成。feature→main の PR は feature ブランチへの push では発火せず（push は main 限定）、PR の `pull_request` で 1 回検証。main へ squash-merge されると `push: main` で 1 回。重複しない。design D1 で確定済み。
- **concurrency グループ**: `ci-${{ github.ref }}`。PR イベントの ref は `refs/pull/N/merge`、push は `refs/heads/main` で別グループになるため PR run と main run は干渉しない。同一 PR への連続 push は同一 ref で `cancel-in-progress` により古い run を打ち切る。design D2 で確定済み。
- **fork PR の secret 露出**: `ci.yaml` は secret を一切使わず build + `upload-artifact` のみ。fork PR で `pull_request` が走っても露出リスクなし。
- **PR 無しの feature push**: CI は走らない（PR open まで）。design Non-Goal / D1 の意図通りで許容。
- **default branch**: `gh repo view` で `main` を確認。`branches: [main]` フィルタは妥当。
- **他ワークフローとの overlap**: `release-artifacts.yaml` は `workflow_dispatch:` のみで push 非発火 → 重複なし。本変更の対象外。
- **可逆性**: `on:` を元に戻すだけで原状復帰可能（design Risks）。

**Status**: Resolved — 残課題なし。grill ゲートをクリアし opsx:apply 可。

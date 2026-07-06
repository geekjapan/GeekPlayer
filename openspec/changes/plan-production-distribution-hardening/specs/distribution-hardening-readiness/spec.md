## ADDED Requirements

### Requirement: 本番配布署名の方針決定は design.md に記録される

iOS/iPadOS・macOS・Android の本番配布に関わる署名/公証/鍵管理の方針決定（またはその不在＝未決事項）は、`openspec/changes/plan-production-distribution-hardening/design.md` の Decisions セクションにプラットフォームごとの選択肢比較とともに記録されなければならない (MUST)。決定できない事項は Open Questions セクションに、誰の判断が必要かとともに明記しなければならない (MUST)。

#### Scenario: 各プラットフォームの決定が design.md に存在する

- **WHEN** `plan-production-distribution-hardening` の design.md を読む
- **THEN** iOS、macOS、Android それぞれについて、選択肢とトレードオフを比較した Decision 項目が存在する

#### Scenario: 未決事項は担当が明示される

- **WHEN** design.md の Open Questions セクションを読む
- **THEN** 人間/プロダクトオーナーの判断が必要な項目が、判断待ちであることが分かる形で列挙されている

### Requirement: 本番署名実装は本 change のスコープ外として明示される

本 change (`plan-production-distribution-hardening`) は証明書・プロビジョニングプロファイル・Android keystore の発行、GitHub Actions secrets への登録、署名/notarization ワークフローの実装を行ってはならない (MUST NOT)。これらは本 change の proposal.md の Non-goals セクションに明記され、後続の OpenSpec change に委譲されなければならない (MUST)。

#### Scenario: proposal.md が実装作業を除外している

- **WHEN** `plan-production-distribution-hardening` の proposal.md の Non-goals セクションを読む
- **THEN** 証明書/keystore の発行、secrets 登録、署名・notarization ワークフローの実装が明示的に除外されている

#### Scenario: 本 change の diff にコード変更が含まれない

- **WHEN** `plan-production-distribution-hardening` ブランチの `git diff main` を確認する
- **THEN** 変更ファイルは `openspec/changes/plan-production-distribution-hardening/` 配下のみであり、`app/` 配下や `.github/workflows/` の変更を含まない

### Requirement: 後続 change への分割計画が存在する

本 change は、プラットフォームごとの決定を受けて着手すべき後続 OpenSpec change の名称・スコープ案を tasks.md に含めなければならない (MUST)。各後続 change 案は対応する design.md の Decision 項目を前提条件として参照しなければならない (MUST)。

#### Scenario: tasks.md に後続 change の分割タスクが存在する

- **WHEN** `plan-production-distribution-hardening` の tasks.md を読む
- **THEN** iOS・macOS・Android それぞれの実装 change 名/スコープ案を確定するタスクが、対応する決定タスクの後に順序付けられている

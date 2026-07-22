## Why

現状の配布は3プラットフォームとも本番運用に耐えない状態にある: macOS は未署名 dmg（Gatekeeper 警告が出る、`docs/release.md:71-73`）、Android は debug 署名の release APK（`app/android/app/build.gradle.kts:28-32` の `signingConfigs.getByName("debug")`、鍵ローテーション不可）、iOS は CI 上の build smoke（`.github/workflows/ci.yaml:299` `build-ios`）のみで配布可能な成果物が存在しない。Issue #49 / Milestone #5「Distribution hardening」は、この3プラットフォームについて署名・公証・鍵管理の方針を確定し、実装を後続の OpenSpec change に分割するための計画策定を求めている。方針を決めないまま実装に入ると、ADR-0006（iOS 非ストア配布・LGPL 維持）や `docs/release.md:95-96`（App Store / Play Store 不使用）の既存方針と矛盾するリスク、または証明書/鍵管理の手戻りが発生する。

## What Changes

- iOS/iPadOS: ADR-0006 の「非 App Store 配布」路線を維持したまま、実際に配布可能な signed 成果物を作るための署名・プロビジョニング戦略（Apple Developer Program のアカウント種別、証明書/プロビジョニングプロファイルの入手・更新運用、Ad Hoc 配布の端末登録上限をどう扱うか）を選択肢比較し、design.md に決定または未決事項として記録する。
- macOS: 未署名 dmg から Developer ID 署名 + notarization に進むかどうかを、コスト（Apple Developer Program 年会費）・Gatekeeper UX 改善・CI 実装コスト（`notarytool` 連携）を比較した上で判断する。
- Android: debug 署名から本番 keystore への移行方針（keystore 保管場所、CI secrets 化、署名鍵のローテーション/紛失時のリカバリー、Play Store 不使用のため upgrade certificate 制約は無いが APK 配布の観点で鍵を失えない点）を整理する。
- 横断: 必要な secrets 一覧、GitHub Actions の permissions、証明書/鍵の所有者・ローテーション責任、失効時の緊急手順を明文化する。
- 上記の決定を受けて、プラットフォームごとの実装 OpenSpec change（例: iOS signing 実装、macOS notarization 実装、Android production signing 実装）に分割するための名称・スコープ案を用意する。
- **本 change ではコードは一切変更しない**。方針決定と後続計画がすべてのアウトプットである。

## Non-goals

- 実際の署名証明書・プロビジョニングプロファイル・Android keystore の発行/生成は行わない。
- GitHub Actions への secrets 登録、署名/notarization ワークフローの実装は行わない（後続の OpenSpec change に委ねる）。
- `.github/workflows/release-artifacts.yaml` の配布パイプライン自体を変更しない。
- App Store / Play Store への配布方針転換は決定しない。現行方針（OSS / GitHub Releases のみ、ADR-0006・`docs/release.md:95-96`）を覆す場合は、本 change ではなく新規 ADR が必要であることを明記するに留める。

## Capabilities

### New Capabilities

- `distribution-hardening-readiness`: プラットフォームごとの本番配布署名/公証の方針決定が満たすべき readiness 要件（決定の記録場所、secrets/ローテーション責任の明文化、後続 change への分割、ADR 前提の明示）を定義する。

### Modified Capabilities

（なし。`ios-platform-support` と `lgpl-compliance` はビルド設定・アプリ内表示という実装レベルの要件を扱っており、本 change はコード変更を伴わないため既存要件を変更しない。理由は design.md「Goals / Non-Goals」に記載。）

## Impact

- 影響ドキュメント: `docs/roadmap.md`、`docs/HANDOFF.md`、`docs/release.md:60-96`（配布手順に本番署名の位置づけを追記する際の参照点）。
- 影響コード（現状の把握のみ、本 change では変更しない）: `.github/workflows/release-artifacts.yaml`（macOS unsigned dmg / Android debug-signed APK のビルドジョブ）、`app/android/app/build.gradle.kts:28-32`（Android signingConfig）、`.github/workflows/ci.yaml:299`（iOS build smoke）。
- 既存 ADR: `docs/adr/0006-ios-media-engine-distribution-policy.md`（iOS 非ストア配布方針、本 change はこれを前提として維持）。
- 後続 change: iOS / macOS / Android それぞれの実装 change（GitHub Issue #49 の子タスクとして分割予定）。

GitHub Issue: #49

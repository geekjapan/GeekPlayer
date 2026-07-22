## Context

GeekPlayer は OSS / GitHub Releases のみで配布する方針（`docs/release.md:89-96`、App Store / Play Store には出さない）。この方針の背景は `media_kit`（libmpv, LGPL-2.1+）の動的リンク条件を OSS 配布の形で満たすためであり（`docs/adr/0002-hybrid-media-engine.md`）、iOS/iPadOS についても ADR-0006 で「非 App Store 配布を維持しつつ、Apple Developer Program 署名による Ad Hoc / 開発者直配布を前提とする」方針が accepted 済み。

現在の `.github/workflows/release-artifacts.yaml` が生成する成果物は次の状態:

- **Windows**: zip 配布、署名なし（対象外。Windows は SmartScreen の扱いが本 Issue のスコープ外 — Issue #49 は iOS/macOS/Android のみを列挙している）。
- **macOS**（`release-artifacts.yaml` の `build-macos-release` ジョブ）: `hdiutil create` で未署名 dmg を生成。初回起動時に Gatekeeper 警告が出るため、右クリック→開く等の手動回避が必要（`docs/release.md:71-73`）。
- **Android**（`build-android-release` ジョブ）: `app/android/app/build.gradle.kts:28-32` で `signingConfigs.getByName("debug")` を release ビルドに適用。keystore 管理不要でサイドロードできる代わりに、本番の鍵ローテーション・改ざん検知の仕組みが無い。
- **iOS/iPadOS**: `.github/workflows/ci.yaml` の `build-ios` ジョブは `--no-codesign` の smoke build のみ（`openspec/specs/ios-platform-support/spec.md` の該当要件参照）。配布可能な `.ipa` は現状生成していない。

## Goals / Non-Goals

**Goals:**

- iOS / macOS / Android それぞれについて、本番配布に向けた署名・公証戦略の選択肢とトレードオフを整理し、決定または「要人間判断」の未決事項として明記する。
- secrets 管理・CI 権限・鍵ローテーション責任という横断的な運用方針を明文化する。
- 決定を受けて着手すべき後続 OpenSpec change の名称・スコープ案を用意し、GitHub Issue #49 の子タスクへの分割を可能にする。

**Non-Goals:**

- 実際の証明書・プロビジョニングプロファイル・keystore の発行/生成、GitHub Actions secrets への登録、署名/notarization ワークフローの実装（後続 change のスコープ）。
- 既存の `ios-platform-support` / `lgpl-compliance` capability spec の変更。両者はビルド設定・アプリ内表示という実装済みの正常系要件を定義しており、本 change はコードや設定を一切変更しないため、これらの要件は不変のまま。本番署名を実装する後続 change が、そこで初めて `ios-platform-support` 等に配布関連の要件を追加/変更するのが適切な粒度と判断した。
- App Store / Play Store 配布への転換の可否判断（ADR-0006 のスコープ外事項として明示的に「本 change では判断しない」と記録するに留める）。

## Decisions

### D1. iOS/iPadOS 署名・プロビジョニング戦略

ADR-0006 は「非ストア配布」を既に決定済みだが、具体的な証明書運用は未決。選択肢:

| 選択肢 | 概要 | Trade-off |
| --- | --- | --- |
| A. Apple Developer Program（個人/組織, 年額 $99）+ Ad Hoc 配布 | UDID 登録済み端末（製品ファミリーごとに membership year あたり最大100台）向けに配布用 `.ipa` を署名 | ✅ ADR-0006 と整合。⚠️ 不特定多数への配布ではなく登録端末に限定され、端末登録の運用コストが利用者拡大時にボトルネック。年次の証明書更新が必要。 |
| B. Apple Developer Enterprise Program（年額 $299、社内配布向け） | 社内配布向けで端末数上限なし | ⚠️ 個人/小規模 OSS プロジェクトの用途外（Apple の Enterprise Program 利用規約は社内配布限定）。**不採用が妥当**。 |
| C. 署名なしのまま `.ipa`/`.app` を配布し、利用者が自前で再署名（sideloading ツール等）する | 証明書運用コストゼロ | ⚠️ 利用者側の技術ハードルが高く、実質的に「配布」と呼べない。UX が大きく劣化。 |

**現時点の判断**: A を暫定候補とするが、**年会費 $99 の負担主体（プロジェクト予算 or 個人負担）と、Ad Hoc 端末登録上限への対応は人間/プロダクトオーナーの判断が必要**。両方の go/no-go を design.md に記録するまで task 2.1 と iOS の後続 change には着手しない。Ad Hoc は登録端末向けの限定配布であり、不特定多数の GitHub Releases 利用者向け iOS 配布は現方針ではサポートしない。

### D2. macOS notarization の要否

| 選択肢 | 概要 | Trade-off |
| --- | --- | --- |
| A. 現状維持（未署名 dmg） | 変更コストゼロ | ⚠️ Gatekeeper 警告が UX を損ない続ける。 |
| B. Developer ID Application 証明書で署名 + `notarytool` で notarization | Gatekeeper 警告が解消し「確認済みデベロッパー」として起動可能 | ✅ UX 改善。同じ Apple Developer Program 登録（D1 と共用可能）で追加コストなし。⚠️ CI に証明書 + App Store Connect API key の secrets 追加、notarization 待ち時間（数分〜）を release フローに組み込む必要。 |

**現時点の判断**: D1 で Apple Developer Program に加入するなら、B は限界費用がほぼゼロで UX 改善効果が大きいため **B を推奨**する。ただし「次の配布 tier」のタイミング（Issue #49 の scope 文言）をいつにするかはプロダクト側の判断であり、open question として残す。

### D3. Android 本番 keystore への移行

| 選択肢 | 概要 | Trade-off |
| --- | --- | --- |
| A. 現状維持（debug 署名） | 変更コストゼロ、GitHub Actions secrets 不要 | ⚠️ 改ざん検知や更新時の署名継続性が保証されない。 |
| B. 本番 keystore を生成し GitHub Actions Secrets（base64 encoded keystore + パスワード）として保管、release ワークフローで署名 | Play Store は使わないため upgrade certificate 制約は無いが、同一鍵での継続署名によりユーザーが安全に上書きインストールできる | ✅ 実装コストが比較的低い（Gradle `signingConfigs` にリポジトリ管理下の secrets を注入するだけ）。⚠️ keystore の紛失・漏洩リスクがあるため、リカバリー不能な鍵のバックアップ運用に加え、GitHub Actions の Environment Secrets によるアクセス制限が必須。 |
| C. GitHub Actions OIDC 等を使った鍵管理サービス（例: クラウド KMS）連携 | 鍵そのものを secrets に置かず署名時にのみ利用 | ⚠️ 個人/小規模 OSS の運用コストに見合わない可能性が高い。将来のスケール次第で再検討。 |

**現時点の判断**: B を推奨。keystore のバックアップ方針（誰が・どこに二重保管するか）は人間の判断が必要な open question として残す。

### D4. 横断的な secrets / CI 権限 / ローテーション方針

- D1〜D3 が必要とする secrets（iOS: 配布証明書 + プロビジョニングプロファイル、macOS: Developer ID 証明書 + App Store Connect API key の `.p8`・key ID・issuer ID、Android: keystore + パスワード）はすべて、最低1名のリポジトリ maintainer の承認を要する GitHub Actions の protected `release` Environment Secrets に格納し、署名・公証ジョブだけが参照する方針とする。App Store Connect の Individual API key では issuer ID を指定しない。
- `GITHUB_TOKEN` は build・署名・公証ジョブを `contents: read`、GitHub Release 公開ジョブだけを `contents: write` とし、OIDC 連携を採用しない限り `id-token: write` を付与しない。
- 証明書の有効期限（iOS 用は1年、macOS Developer ID 用は5年など）到来前に更新する担当・手順を `docs/release.md` に追記することを後続 change のタスクに含める。
- 秘密情報をリポジトリに直書きしない方針は、後続の実装 change でも継続して守る前提とする。

## Risks / Trade-offs

- [Risk] Apple Developer Program 年会費の継続支払いが個人負担のまま放置されるとサービス断絶（証明書失効）につながる → Mitigation: D4 でローテーション担当・更新期日のドキュメント化をタスク化する。
- [Risk] Android keystore の紛失により既存ユーザーが二度と同一アプリとして上書きインストールできなくなる → Mitigation: 後続 change で二重バックアップ（例: リポジトリ管理者2名が別々の保管場所を持つ）を必須タスクにする。
- [Risk] iOS Ad Hoc の端末登録上限（製品ファミリーごとに membership year あたり100台）が OSS 配布の想定利用者数を超える可能性 → Mitigation: 実際に上限に到達した場合の代替案（EU 代替マーケットプレイス、招待制配布等）を open question として残し、後続 change 着手前に人間判断を仰ぐ。
- [Risk] 本 change が「決定」ではなく「選択肢整理」に留まる決定事項が多く、後続 change 着手がブロックされる → Mitigation: tasks.md で「人間判断待ち」の項目を明示的に分離し、判断が付いた項目から後続 change に着手できるようにする。

## Migration Plan

コード変更を伴わないため、デプロイ/ロールバック手順は無い。本 change の「移行」は、決定事項を `docs/roadmap.md` / `docs/HANDOFF.md` に反映し、GitHub Issue #49 に子 Issue またはコメントとして後続 change 計画を記録することを指す（tasks.md 参照）。

## Open Questions

1. iOS: Apple Developer Program 年会費 $99 の負担主体は誰か。
2. iOS: Ad Hoc 配布の端末登録上限（製品ファミリーごとに membership year あたり100台）に到達した場合の代替方針を今から決めておくか、到達時に判断するか。
3. macOS: notarization 導入（D2-B）に着手する「次の配布 tier」のタイミングはいつか（バージョン番号や Milestone で明示するか）。
4. Android: 本番 keystore のバックアップ保管者・保管場所を誰がどう決めるか（プロジェクトの組織体制に依存するため、本 change 単独では決定できない）。
5. 将来的に App Store / Play Store 配布を検討する可能性があるか。ある場合は ADR-0006 を supersede する新 ADR が必要（本 change のスコープ外であることを明示するに留める）。

上記はいずれも人間・プロダクトオーナーの判断が必要な項目であり、本 change の tasks.md では「決定を記録する」タスクとして扱い、決定自体はこの change の中で下さない。

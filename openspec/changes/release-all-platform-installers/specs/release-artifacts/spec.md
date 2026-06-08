## ADDED Requirements

### Requirement: タグ push で全プラットフォームの Release 配布が起動する

`release-artifacts.yaml` ワークフローは `v*` 形式のタグ push を契機に起動しなければならない (MUST)。既存の `workflow_dispatch` 手動起動も維持しなければならない (MUST)。タグ起動時は対応する全プラットフォーム（Windows / macOS / Android / Linux）のビルドを実行しなければならない (MUST)。

#### Scenario: タグ push で配布ワークフローが走る

- **WHEN** `v0.1.0` のようなタグが push される
- **THEN** `release-artifacts.yaml` が起動し、Windows / macOS / Android / Linux のビルドジョブが実行される

#### Scenario: 手動 dispatch も維持される

- **WHEN** メンテナが `workflow_dispatch` でワークフローを手動実行する
- **THEN** 全プラットフォームのビルドジョブが実行される（タグ参照時のみ Release への添付が行われる）

### Requirement: 各プラットフォームの配布物を生成する

ワークフローは以下の配布物を生成しアップロードしなければならない (MUST):
- Windows: release ビルドを zip 化した `GeekPlayer-windows-<suffix>.zip`
- macOS: unsigned の `GeekPlayer-macos-<suffix>-unsigned.dmg`
- Android: `flutter build apk --release` による installable な APK `GeekPlayer-android-<suffix>.apk`（debug 署名で可、キーストア不要）
- Linux: `flutter build linux --release` を AppImage 化した `GeekPlayer-linux-<suffix>.AppImage`

iOS / iPadOS の配布物は本要件の対象外とする (MUST NOT)。`<suffix>` はタグ起動時はタグ名、手動起動時は `run-<run_number>` でなければならない (MUST)。

#### Scenario: Android の installable APK が生成される

- **WHEN** Android ジョブが完走する
- **THEN** debug 署名された release APK が生成され、`geekplayer-android` artifact としてアップロードされる

#### Scenario: Linux の AppImage が生成される

- **WHEN** Linux ジョブが完走する
- **THEN** 実行可能な `.AppImage` が生成され、`geekplayer-linux` artifact としてアップロードされる

#### Scenario: AppImage に libmpv が同梱される

- **WHEN** Linux AppImage がビルドされる
- **THEN** media_kit が必要とする `libmpv.so.2` が AppImage 内に同梱され、libmpv 未導入の Linux 環境でも再生機能が壊れない

#### Scenario: iOS は配布対象に含まれない

- **WHEN** 配布ワークフローが実行される
- **THEN** iOS / iPadOS のビルド・アップロードジョブは存在しない

### Requirement: タグ時に全資産を 1 つの GitHub Release に集約する

`publish-github-release` ジョブは `github.ref_type == 'tag'` の場合のみ実行され (MUST)、Windows / macOS / Android / Linux の全ビルドジョブの完了を `needs:` で待ってから (MUST)、それらの artifact を 1 つの GitHub Release に添付しなければならない (MUST)。Release ノートは自動生成しなければならない (MUST)。

#### Scenario: タグ起動時に 4 プラットフォーム資産が添付される

- **WHEN** `v*` タグ起動でビルドジョブが全て成功する
- **THEN** `softprops/action-gh-release` により、zip / dmg / apk / AppImage の 4 資産が当該タグの GitHub Release に添付され、リリースノートが自動生成される

#### Scenario: 手動 dispatch（非タグ）では Release を作らない

- **WHEN** タグ以外の ref で `workflow_dispatch` 実行される
- **THEN** ビルドと artifact アップロードは行われるが、`publish-github-release` はスキップされ GitHub Release は作成・更新されない

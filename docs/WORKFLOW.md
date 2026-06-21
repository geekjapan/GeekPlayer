# GeekPlayer — 開発運用

最終更新: 2026-06-21

この文書は、GeekPlayer の計画・仕様・実装・レビューを複数チャット / 複数エージェントで分担するための運用ルールです。

## 1. 正本と役割分担

**GitHub Milestone / Issue を計画の正本**とします。ロードマップ、実装単位、優先順位、PR との対応は GitHub 側で管理します。

ローカルリポジトリは、GitHub で決めた計画を実装可能な形に落とし込む **仕様・実装・検証証跡の作業面**です。OpenSpec artifacts、設計判断、コード、テスト、ローカルドキュメントはこのリポジトリで管理します。

`docs/HANDOFF.md` は再開用の現状・進捗・次アクションに限定します。継続的なプロジェクトルールはこのファイル、`AGENTS.md`、`CLAUDE.md`、`openspec/config.yaml` に置きます。

ツール制約により、同一チャットで DevSpace と GitHub ツールを同時利用しない運用にします。

| 場 | 役割 | してよいこと | 避けること |
|---|---|---|---|
| GitHub 管理チャット | Milestone / Issue / PR / CI / Release の管理 | Issue 作成・更新、Milestone 整理、PR 状況確認、CI 結果確認 | ローカルファイル編集を前提にした実装判断 |
| ローカルリポジトリ管理チャット | `~/dev/projects/GeekPlayer` の確認・編集・レビュー・指示 | OpenSpec artifacts、ドキュメント、コード差分確認、レビュー指示、検証コマンド実行 | GitHub 側の直接変更 |
| Codex 実装セッション | 実装・修正・テスト | OpenSpec tasks に沿った実装、最小検証、差分報告 | スコープや受け入れ条件の独断変更 |

## 2. 作業単位の階層

作業は原則として次の階層で扱います。

```text
GitHub Milestone
  └─ GitHub Issue
       └─ OpenSpec change
            └─ feature branch / PR
                 └─ tasks.md のチェックボックス
```

原則は **1 GitHub Issue = 1 OpenSpec change = 1 feature branch / PR** です。ただし、単一 Issue が大きい場合は、OpenSpec change を小さな検証単位に分割して構いません。その場合は、各 change の proposal または tasks に親 Issue と分割理由を明記します。

OpenSpec change 名は kebab-case とし、Issue の意図が分かる短い名前にします。例: `ui-phase-2-batch-3-localize-raw-errors-and-format-dates`。

## 3. OpenSpec の使い方

非自明な変更は OpenSpec を通します。

- 企画・検討: `/opsx:explore`
- 仕様化: `/opsx:propose <change-name>`
- 実装: `/opsx:apply <change-name>` または Codex への実装指示
- 完了確認: `/opsx:verify <change-name>` 相当の観点で差分・tasks・tests を確認
- アーカイブ: `/opsx:archive <change-name>`

`proposal.md` には、可能な限り GitHub Issue / Milestone への対応関係を記録します。GitHub ツールを使えないローカルチャットでは、Issue 番号が不明な場合に推測で埋めず、`GitHub Issue: TBD` として扱います。

`tasks.md` は実装者向けの実行契約です。Codex 実装セッションは tasks のチェックボックスを完了ごとに `- [x]` へ更新し、スコープ外の変更を見つけた場合は実装を広げず、設計・Issue 側へ戻します。

## 4. ブランチ / PR

`main` へ直接 feature / workflow 変更を入れません。作業開始時に専用ブランチを切ります。

```bash
git switch -c feature/<change-name>
# または docs/<topic>, fix/<topic>
```

PR には、少なくとも次を記録します。

- 対応 GitHub Issue / Milestone
- 対応 OpenSpec change
- 変更概要
- 検証コマンドと結果
- ローカルで検証できない項目と、GitHub Actions で代替確認した run

## 5. ローカル検証と CI

ローカルに Flutter / Dart がない環境では、Flutter 系検証は GitHub Actions を正本にします。ただし、実行可能な検証はローカルで先に行います。

ローカルで実行する基本検証:

```bash
openspec validate --all --strict
git diff --check
```

Flutter / Dart が利用できる環境では、次も実行します。

```bash
cd app
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

## 6. レビュー観点

このローカルリポジトリ管理チャットは、Codex が実装した差分に対して次を確認します。

- Issue / OpenSpec のスコープから逸脱していないか
- `tasks.md` のチェック状態と実差分が一致しているか
- ユーザー可視文字列が `AppLocalizations` を経由しているか
- drift schema 変更時に migration とテストがあるか
- ADR / CONTEXT / docs の更新が必要な判断変更を含んでいないか
- セキュリティ、法務、外部サイト利用規範、LGPL 通知に反していないか
- ローカル未検証項目が PR / CI で追跡可能になっているか

## 7. 判断の戻し先

迷った場合の戻し先は次の順序です。

1. GitHub Issue / Milestone: 作業の目的、優先順位、受け入れ条件
2. OpenSpec change: 具体的な仕様、設計、tasks
3. ADR / CONTEXT / docs: 長期的な設計判断、用語、開発規約
4. コード / テスト: 実装事実と回帰防止

この順序に反する判断が必要になった場合は、コードを先に広げず、Issue / OpenSpec / ADR のいずれかを更新してから実装します。

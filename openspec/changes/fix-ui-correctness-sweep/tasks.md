## 1. なろう作品詳細 エピソード一覧の修正

- [x] 1.1 `work_detail_screen.dart`: エピソード行のタイトルを空文字 `Text('')` から `第N話` に変更（旧 `leading` の `第N話` を `title` へ）、`trailing` に chevron を追加
- [x] 1.2 短編（`generalAllNo == 0` / `isShort`）で 0 件になっていたエピソード一覧を、行数 `episodeCount = summary.isShort ? 1 : summary.generalAllNo` で算出し 1 件表示に修正（`totalEpisodes` も同値に統一）

## 2. ホームのエラー表示色

- [x] 2.1 audio/video `home_section.dart` の `_ErrorRow` の `Colors.redAccent` を `Theme.of(context).colorScheme.error` に変更（dark 対応・パレット整合）

## 3. spec 同期

- [x] 3.1 `narou-novel-reader-ui` の「Work detail screen with metadata and episode list」要件に短編=1話の Scenario を追加（MODIFIED delta）

## 4. 検証

- [ ] 4.1 `openspec validate fix-ui-correctness-sweep --strict` が通る
- [ ] 4.2 PR 作成し CI（`analyze --fatal-infos` + `test` + 6 ビルド）green を確認

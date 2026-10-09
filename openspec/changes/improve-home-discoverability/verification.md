# #51 検証記録

確認日: 2026-10-09

## 実装と自動検証

`feature/improve-home-discoverability` で、6つのジャンプ先、日英ラベル、tooltip、48dpの操作領域、Tab/Enter操作を追加した。既存のセクション実装・順序・データ層は変更していない。

`ListView(children: ...)` の遅延構築により、初期表示から離れたセクションへのジャンプが失敗することを先に再現した。縦ListViewの中にColumnを1つ置いてアンカーを構築し、同じテストが成功することを確認した。

| 確認 | 結果 |
|---|---|
| 新規7テストと既存ホーム画面テスト | 8件成功 |
| 全 `flutter test --no-pub` | 639件成功 |
| `flutter analyze --no-pub --fatal-infos` | 指摘なし |
| `dart format --output=none --set-exit-if-changed .` | 381ファイル、変更なし |
| `openspec validate --all --strict` | 49件成功 |
| `git diff --check` | 成功 |
| 独立した仕様レビュー | ブロッキング指摘なし |
| `graphify update .` | AST更新成功。生成物はgitignore対象 |

新規テストは、遠いセクションへの往復、360×640の画面でのTab/Enterによる全ジャンプ先への移動、日英ラベル、tooltip/semantics、最小操作領域、登録順・登録済みの対象のみの表示を確認する。追加の3ケースで、前方セクションの遅延読み込み後も見出しを可視に保つこと、ユーザーのドラッグ・PageDown後は追従をやめることを確認する。実際のレジストリを使う既存テストにも6チップの確認を追加した。

ログは `/tmp/geekplayer-{format,analyze,tests,openspec,quick-jump-red,quick-jump-lazy,quick-jump-green,graphify}.log` に保存した。これらはローカル一時ファイルである。

## 変更後アプリの実機確認

- 環境: macOS 27.0.1 / arm64、Flutter 3.44.0 / Dart 3.12.0。
- Orca Computer UseのAccessibility・スクリーンキャプチャ権限は利用可能。
- Xcode本体は未インストール。`xcodebuild -version` は有効な開発ディレクトリが `/Library/Developer/CommandLineTools` であるため失敗した。
- このため、今回の変更を含むmacOSアプリでのポインタ・キーボード操作は未確認。task 6.3は未完了のまま保持する。
- Windows実機確認はユーザーの明示指示によりSKIP。成功扱いにはしない。
- PR #71を作成済み。初回CI（37898563465）と手動ビルド（37898564838）は成功し、レビュー修正版で再実行する。通常CIのmacOSジョブはビルドのみでアプリを保存しない。実機確認用のDMGは既存の `Release Artifacts` workflowを対象ブランチで手動実行すると取得できる。ブランチでの手動実行はGitHub Releaseを作成しない。

## 配布版でのComputer Use観測

これは今回の変更の合格証拠ではない。GitHub Releasesの `v0.1.1`、`GeekPlayer-macos-v0.1.1-unsigned.dmg` を読み取り専用でマウントし、アプリを起動した。

- ホーム画面の起動とネイティブの動画ファイル選択を確認した。
- FFmpegで作成した15秒の無音テスト動画を開き、映像と再生位置の進行を確認した。
- 待機後のプレイヤーには戻る導線が見えなかった。映像中央のクリックで下部の再生操作は表示されたが、戻るボタンは確認できなかった。Escapeでもホームへ戻らなかった。
- Cmd+Qによる終了後に再起動するとホームが表示された。#50の再現調査の参考になるが、現在のmainとは版が異なるため、現行コードでの再現確定や修正完了とはしない。

テスト動画は `/tmp/geekplayer-computer-use/navigation-test.mp4`。既存メディアは開いていない。アプリの最近開いた項目にはテスト動画が追加される。

## PRレビュー対応

- PR #71のP2指摘を再現した。前方のセクションを40dpから2400dpへ拡大すると、選択済み見出しの下端が600dpの画面に対し2484dpとなった。各セクションのサイズ変更後にアンカーを補正し、ユーザースクロール開始時に追従を止める修正を追加した。
- 全セクションを構築する方式には、画面外にあった小説ライブラリも早く構築するコストがある。既存のWrapによる全件表示は変更していない。大規模ライブラリの起動コストは未計測であり、別changeでの上限・仮想化の対象とする。

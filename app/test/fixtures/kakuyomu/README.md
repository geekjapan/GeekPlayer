# Kakuyomu test fixtures

このディレクトリは `KakuyomuRssSource` / `KakuyomuHtmlParser` の
スナップショットテストで参照する **golden 入力** を保持しています。
`add-kakuyomu-novel-reader` change の `kakuyomu-resilience` capability
が要求する HTML 構造変更の早期検知メカニズムの心臓部です。

## 構成

- `rss/latest.xml` / `latest.golden.json` — 新着 RSS フィード
- `rss/ranking_daily.xml` / `ranking_daily.golden.json` — 日次ランキング (RSS 2.0)
- `rss/ranking_weekly.xml` / `ranking_weekly.golden.json` — 週次ランキング (Atom)
- `html/work_001.html` 〜 `work_005.html` — 作品詳細ページ 5 件
  (ジャンル分散: SF / 恋愛 / ミステリー / 詩 / ドラマ)
- `html/episode_001.html` 〜 `episode_005.html` — エピソード本文 5 件
  (本文長 / ルビ有無 / 段落数で分散)
- 対応する `*.golden.json` — パース後の正規化結果

## 更新ポリシー: 月 1 回手動

ADR-0001 の責任あるスクレイピング規範に従い、**実環境フェッチは月 1 回**
の手動オペレーションに限定します。CI から定常的に kakuyomu.jp を叩く
ことは禁止です（CI に組み込むと「能動キャッシュのみ」原則を破る）。

毎月の手動手順:

1. 自分のローカル PC で、開発者個人が自分の手でブラウザを開いて
   対象 URL（5 work + 5 episode + 3 RSS endpoint）を「保存（HTML のみ）」
   する。`curl` を使う場合は次の制約を守る:
   - User-Agent に `GeekPlayer/<version> (+https://github.com/geekjapan/GeekPlayer; personal-use)`
   - 1 リクエスト / 2 秒 以上の間隔 (`sleep 2` を間に挟む)
   - 連続して 13 リクエスト前後 = 約 30 秒以上の所要時間 (短すぎるなら
     再考)
2. `robots.txt` に Disallow が追加されていないか確認。Disallow に
   `/works/...` 等が含まれるようになった場合は **更新を中止** し、
   `kakuyomuEnabled = false` の hotfix リリースを検討する。
3. 取得した HTML / RSS をこのディレクトリの該当ファイルに **上書き**
   保存。
4. `KAKUYOMU_UPDATE_GOLDENS=1 flutter test test/features/novel/kakuyomu/`
   を実行して `*.golden.json` を再生成。
5. `git diff` で構造変更（新しいセレクタ名、新しいクラス階層）が
   発生していないか確認。差分が発生した場合は
   `kakuyomu_html_parser.dart` のセレクタを修正する PR を別途立てる。

## ゴールデン JSON の管理

- ゴールデン JSON は `JsonEncoder.withIndent('  ')` でシリアライズ。
  改行差分が出やすいので、必ず `KAKUYOMU_UPDATE_GOLDENS=1` 経由で
  生成する（手書きしない）。
- ゴールデン差分は **構造変更を検知するためのもの**。CI が赤になったら
  まず HTML を確認し、上流（カクヨム）が構造変更したかどうかを
  人間が判断する。

## トラブルシューティング

- パースが失敗するファイル fixture があれば、`KakuyomuParseException`
  が投げられて UI 側で外部ブラウザフォールバック（`url_launcher` で
  公式ビューア起動）が走る。テスト中に投げてほしい場合は意図的に
  壊した fixture を別ファイルに保存し、テスト側で個別に検証する
  （現状の `parser_test.dart` が `missing title` ケースをカバー済み）。
- robots.txt が disallow するパス（例: `/admin/`）の検証は
  `kakuyomu_robots_txt_cache_test.dart`（task 9.x）で別途行う。

## 関連 ADR / spec

- [ADR-0001](../../../../docs/adr/0001-online-novel-fetch-policy.md)
- [kakuyomu-resilience spec](../../../../openspec/changes/add-kakuyomu-novel-reader/specs/kakuyomu-resilience/spec.md)
- [responsible-fetching spec](../../../../openspec/specs/responsible-fetching/spec.md)

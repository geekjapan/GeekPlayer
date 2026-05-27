## Context

カクヨムは GeekPlayer v0.1 がターゲットとする 3 つの小説サイトのうち、唯一
公式 API を持たないサイトである。検索・新着・ランキング・更新通知は **公式 RSS /
Atom フィード**で提供されているが、本文は HTML ページとしてしか公開されていない。
[ADR-0001](../../../docs/adr/0001-online-novel-fetch-policy.md) は (c) HTML パース
方式を採用し、能動キャッシュのみ・レート制限・User-Agent・`robots.txt` 尊重・
指数バックオフ・同意ダイアログ・4 箇所注意書きという責任あるスクレイピングの
運用規範を確定させた。

本 change はその ADR を **カクヨム個別実装に降ろす** 責務を負う。共通インフラ
（`NovelRepository` interface / `RateLimiter` / `site-consent` capability /
`OnlineWork` / `OnlineEpisode` のドメインモデル / drift スキーマ）は
別 change `add-online-novel-library` が同時並行で確立する前提で、本 change は
それらの interface に依存する側として書く。なろう / ノクターン系は別 change
`add-narou-novel-reader` に分離する。

採用済みの前提:

- HTTP クライアント: `dio`（共通インフラに `RateLimiter` 適用済み Interceptor が
  入る想定）
- RSS / Atom パース: `webfeed_revised`
- HTML パース: `html`（`dart:html` ではなく `package:html`）
- 状態管理: Riverpod v2 (Notifier API)
- データ永続化: 単一 drift SQLite DB（テーブル定義は共通 change の責務）
- 対象 OS: macOS / Windows / Android (v0.1)
- UI 言語: ja-first

カクヨム HTML は SPA ではなく **サーバーサイドレンダリング**のページが安定して
返ってくる前提（2026-05 時点）で設計する。Next.js による hydration はあるが
初期 HTML に本文が含まれているため、JS 実行は不要。

## Goals / Non-Goals

**Goals:**

- ユーザーがカクヨム同意を済ませた状態で、検索 / 新着 / ランキング画面から作品を
  見つけ、作品詳細を開き、エピソードリーダーで本文を読める
- ADR-0001 の運用規範（1 req / 2 sec、並列 1、User-Agent、`robots.txt`、
  429/503 指数バックオフ最大 5 分）が全カクヨムリクエストに自動適用される
- 同意なし / 同意取り消し時にカクヨム機能が完全に不可視・不可達になる
- HTML 構造変更が起きた場合、CI のスナップショットテストで早期に失敗が出る
- パーサが落ちても、ユーザーは公式ビューアにフォールバックして読書を続けられる
- `KakuyomuHtmlSource` クラス docstring に ADR-0001 の注意書きが書かれている

**Non-Goals:**

- なろう / ノクターン系の取り扱い（別 change）
- `NovelRepository` / `RateLimiter` / `site-consent` の定義そのもの（共通 change）
- 受動キャッシュ / 事前ダウンロード / 大規模クロール
- カクヨムへのログイン状態同期
- 公式 API への切り替え（将来の新 ADR 案件）
- 自動セレクタ推測機構
- TLS pinning

## Decisions

### D1. `KakuyomuNovelRepository` は 2 ソースの薄いコンポジット

```dart
final class KakuyomuNovelRepository implements NovelRepository {
  KakuyomuNovelRepository({
    required this.rssSource,
    required this.htmlSource,
    required this.consent,
  });
  final KakuyomuRssSource rssSource;
  final KakuyomuHtmlSource htmlSource;
  final SiteConsentReader consent;
  // search / latest / ranking / workUpdates → rssSource
  // workDetail / episodeBody → htmlSource
  // どのメソッドも consent.isGranted('kakuyomu') を先頭でチェック
}
```

各メソッドの先頭で同意状態をチェックし、未同意の場合は専用の
`SiteConsentDeniedException` を投げる。UI 側はその例外を catch してフォールバック
（同意ダイアログ表示 or 機能不可表示）。

**代替案: Repository を 1 つのモノリシックなクラスにする**
→ ソースを分離する方が `KakuyomuRssSource` を別のサイト（例: 他フィード提供サービス）
にも再利用しやすい。また Rss と Html はテスト戦略（fixture 種別）が違うので分けると
責務が明快。

### D2. RSS / Atom は `webfeed_revised` の `RssFeed.parse` / `AtomFeed.parse` に集約

カクヨムの公式フィードがどちらの形式を返すかはエンドポイント別に異なるため、
`Content-Type` ヘッダで判定し `RssFeed.parse` または `AtomFeed.parse` に振り分け、
内部の `KakuyomuFeedItem` 値オブジェクトに正規化する。

**代替案: 自前 XML パース**
→ 依存削減のメリットより、フィードのバージョン差異吸収の安定性を優先。
`webfeed_revised` はメンテされており iTunes 拡張等の取り扱いも安定。

### D3. HTML パースはセレクタを `KakuyomuHtmlParser` に隔離

`KakuyomuHtmlSource` は HTTP 取得 + パーサ呼び出しのみを担当し、CSS セレクタや
DOM 操作は `KakuyomuHtmlParser` に閉じ込める。これにより HTML 構造変更時の修正
範囲を 1 ファイルに局所化し、スナップショットテストもパーサ単体に対して書ける。

`KakuyomuHtmlParser` の public API:

```dart
class KakuyomuHtmlParser {
  KakuyomuWorkDetail parseWorkPage(String html);
  KakuyomuEpisodeBody parseEpisodePage(String html);
}
```

セレクタは関数の先頭に `const` で並べる（変更時の grep 容易性）。

### D4. レート制限は共通 `RateLimiter` を Dio Interceptor 経由で適用

`add-online-novel-library` の `RateLimiter` は site key を引数に取る前提で、
カクヨム用 `KakuyomuRateLimiter` は `RateLimiter(siteKey: 'kakuyomu', minInterval:
Duration(seconds: 2), maxConcurrent: 1)` で構築する。`Dio` の interceptor で
全リクエスト前に `await limiter.acquire('kakuyomu')` を呼び、`onError` で
429 / 503 を捕捉して指数バックオフ（初期 1s → 倍々、上限 5 分、Retry-After
ヘッダがあれば優先）でリトライする。

最大リトライ回数: **3 回**。3 回で諦め、UI には「カクヨムが混雑しています。
時間を置いて再試行してください」を表示。

### D5. User-Agent は固定文字列でビルド時版から組み立てる

```
GeekPlayer/<version> (+https://github.com/geekjapan/GeekPlayer; personal-use)
```

`<version>` は `package_info_plus` から取得し、Dio の `BaseOptions.headers` に
セット。ADR-0001 §取得方針 4. を満たす。

### D6. `robots.txt` キャッシュ

`KakuyomuRobotsTxtCache` を以下のように実装:

- アプリ起動後・カクヨム機能初回呼び出し時に `https://kakuyomu.jp/robots.txt` を
  1 回フェッチ（レート制限経由）
- パース結果（disallow パス一覧）をプロセス内メモリに 1 時間キャッシュ
- 全 HTTP リクエスト前に対象パスが disallow にマッチしないか評価
- 評価で deny になったパスへのアクセスは `RobotsDisallowedException` を投げる
- `robots.txt` 自体の取得に失敗した場合は **保守的に全 disallow** とせず、
  「直近成功キャッシュがあればそれを使う、なければ既知のパス
  （`/works/{id}`, `/works/{id}/episodes/{id}`, RSS）のみ許可」のフォールバック

### D7. 同意ダイアログと `site-consent` capability への依存

カクヨム機能の初回呼び出し時、`site-consent` capability が公開する
`requestConsent(SiteKey.kakuyomu)` を呼ぶ。Dialog の文言・ボタンラベル・注意書きは
本 change の `kakuyomu_consent_dialog.dart` に閉じる（共通ダイアログを汎用化
しすぎないため）。

文言要件:

- ADR-0001 の趣旨を平易な日本語で記す
- 「個人利用に限定」「能動キャッシュのみ」「`robots.txt` 尊重」を箇条書きで明示
- 「同意しない」ボタンが「同意する」ボタンと同等の視認性
- リンク: README の「カクヨム機能の注意事項」セクション、ADR-0001、カクヨム公式
  サイト利用規約

同意取り消し時の挙動: ローカルにキャッシュ済みの本文（Library に追加済みの作品）も
**全削除する**。設定画面の同意トグル OFF 時に確認ダイアログを出してから削除。

### D8. UI 構成

5 画面構成:

| 画面 | 役割 | データソース |
|---|---|---|
| `SearchScreen` | キーワード検索（フォーム → 検索 URL の RSS を fetch） | `KakuyomuRssSource.search` |
| `LatestFeedScreen` | 新着 RSS タイムライン | `KakuyomuRssSource.latest` |
| `RankingScreen` | ランキング RSS（日次 / 週次 / 月次 / 累計のタブ） | `KakuyomuRssSource.ranking` |
| `WorkDetailScreen` | 作品の概要 + エピソード一覧 + 「Library に追加」 | `KakuyomuHtmlSource.fetchWork` |
| `ReaderScreen` | エピソード本文表示、縦書き / 横書きトグル、文字サイズ | `KakuyomuHtmlSource.fetchEpisodeBody` (キャッシュ優先) |

`ReaderScreen` は本文を `Text.rich` で表示。ルビ・段落・空行・縦中横は
`KakuyomuHtmlParser` で正規化したセグメント列で扱う。詳細な縦書き仕様は
共通 reader UI が `add-online-novel-library` で確立される前提でそれに乗る。

### D9. パーサ失敗時のフォールバック

`KakuyomuHtmlSource` で `FormatException` / `KakuyomuParseException` が発生した
場合、UI は **エラー画面ではなく fallback CTA を出す**:

```
[!] このエピソードの読み込みに失敗しました。
    アプリのバージョンを更新するか、公式ビューアで開いてください。

    [ 公式ビューアで開く ]   [ 詳細をコピー ]
```

「公式ビューアで開く」は `url_launcher` で `https://kakuyomu.jp/works/{id}/episodes/{id}`
を外部ブラウザ（OS デフォルト）で開く。アプリ内 WebView は v0.2 で再評価
（platform 別の追加依存が必要なため）。

「詳細をコピー」はパーサがどのセレクタで失敗したかを文字列に整形してクリップ
ボードへ。Issue 報告用。

### D10. スナップショットテスト戦略

`app/test/fixtures/kakuyomu/` 配下に:

- `rss/latest.xml` — 新着フィードのスナップショット
- `rss/ranking_daily.xml` — ランキングフィード
- `html/work_<id>.html` — 作品ページ（5 件、ジャンル分散）
- `html/episode_<id>.html` — エピソードページ（5 件、本文長/ルビ有無で分散）

これらに対する `KakuyomuFeedParser` / `KakuyomuHtmlParser` のパース結果を
`.json` のゴールデンファイルとして固定。CI で fixture ↔ ゴールデンの一致を検証。

実環境 smoke テスト: 月 1 回手動で実環境からフェッチして fixture を更新し、
パース結果に差分が出たらこの change を起点に修正する。実環境への自動アクセスは
CI に組み込まない（CI からカクヨムへの定常アクセスは ADR-0001 の趣旨に反するため）。

### D11. ToS 違反時の機能停止フロー

カクヨムが ToS で自動収集を明示禁止した場合の対応手順を spec / docs に明文化:

1. 機能フラグ `kakuyomuEnabled` を `core/config` に追加し、デフォルト `true`
2. リモートで強制 OFF にする手段は v0.1 では持たない（クラウド未使用）
3. アプリ更新時に `kakuyomuEnabled = false` を hardcode したリリースをプッシュ
4. 該当バージョンを起動した時点で UI からカクヨムタブが消え、キャッシュ済み本文の
   削除確認ダイアログを出す
5. 経緯と判断は新 ADR で記録、ADR-0001 を superseded する

この change ではフラグ実装のみ行い、強制 OFF は将来対応。

### D12. テスト戦略まとめ

| 層 | テスト | tool |
|---|---|---|
| パーサ単体 | RSS / HTML fixture → ゴールデン JSON | `flutter test` |
| Source 単体 | Dio mock + fixture を返す、レートリミッタ・robots 経由を検証 | `mocktail` + `http_mock_adapter` |
| Repository 単体 | source mock + consent mock | `mocktail` |
| ウィジェット | 各画面の空状態 / 読み込み中 / エラー / 同意なし状態 | `flutter_test` |
| Integration | 同意ダイアログ → 検索 → 作品詳細 → リーダー の通し動作（モック source） | `integration_test` |
| 実環境 smoke | 月 1 回手動、fixture 更新 | 手動 + 記録 |

### D13. ディレクトリ構成

```
app/lib/features/novel/kakuyomu/
  data/
    kakuyomu_rss_source.dart
    kakuyomu_html_source.dart
    kakuyomu_html_parser.dart
    kakuyomu_robots_txt_cache.dart
    kakuyomu_novel_repository.dart
    kakuyomu_dio_factory.dart        # UA / interceptor 構成
  domain/
    kakuyomu_work.dart
    kakuyomu_episode.dart
    kakuyomu_search_query.dart
    kakuyomu_feed_item.dart
    exceptions.dart                   # SiteConsentDeniedException / KakuyomuParseException / RobotsDisallowedException
  presentation/
    search_screen.dart
    latest_feed_screen.dart
    ranking_screen.dart
    work_detail_screen.dart
    reader_screen.dart
    kakuyomu_consent_dialog.dart
    parser_failure_fallback.dart
    kakuyomu_section.dart             # ホーム画面 / 設定画面に組み込まれるコンポジット
```

## Risks / Trade-offs

- **カクヨム HTML 構造変更でパース失敗** → `KakuyomuHtmlParser` にセレクタを
  集約し、スナップショットテストで早期検知。失敗時は公式ビューアフォールバック
  で読書継続を担保。GitHub Releases で hotfix を出すリードタイムは数日想定。
- **カクヨムが ToS で自動収集を明示禁止した場合の機能停止** → D11 のフロー。
  v0.1 ではアプリ更新でのみ無効化、リモートキルスイッチは未実装。
  ToS 監視は人手のため初動遅延リスクあり。OSS なので運営側コミュニティに
  気づきが出やすい点で部分的に緩和。
- **`webfeed_revised` の RSS パース失敗時挙動** → ライブラリが投げる例外を
  個別 catch し、`KakuyomuFeedParseException` でラップ。フィード 1 アイテムの
  破損が全体を落とさないよう、アイテム単位で try-catch（ベストエフォート）。
- **`robots.txt` 取得失敗** → D6 のフォールバック（既知 path のみ許可）。
  ただしカクヨムが新パスを公開した場合に到達できなくなる懸念。許可リストは
  D6 のコメントに「ここを更新したら docstring とテストも更新」と明記。
- **同意ダイアログのダークパターン懸念** → 「同意しない」ボタンを「同意する」と
  視覚的に同等にする。文言レビューを tasks に明示的に入れる。
- **レート制限が他チャネル（CLI / 別プロセス）と整合しない** → v0.1 ではアプリは
  単一プロセスなので問題なし。複数プロセス間共有は v1.0 以降。
- **同意取り消し時のキャッシュ削除を忘れる** → 設定画面の OFF トグルから
  必ず `KakuyomuNovelRepository.purgeAllCachedBodies()` を呼ぶ。テストで OFF
  → 後続 read が 0 件であることを検証。
- **`url_launcher` の OS 別対応漏れ** → macOS / Windows / Android で smoke。
  Android で TWA 形式で開くと体験は良いが依存が増えるため v0.1 では既定ブラウザで
  開くのみ。

## Migration Plan

- 既存ユーザーなし（新規プロジェクト）→ drift スキーマ追加のみ、移行手順なし
- ロールバック: 本 change をリバートするとカクヨム関連ファイル一式が消え、
  共通 `NovelRepository` への登録解除のみで他機能には影響なし
- `add-online-novel-library` が先にマージされている前提だが、依存方向は本 change
  → 共通 change で一方向。共通 change が遅延する場合、本 change の Dart 実装は
  共通インターフェースのモックを暫定で置いて先行マージしないこと

## Open Questions

- **Q-D1**: 検索結果 RSS のページネーション仕様は? → tasks の D2 検証 task で
  実フィードを観察して確定。初期実装はトップ 1 ページのみ、続きは v0.2。
- **Q-D2**: ランキングのタブ（日次 / 週次 / 月次 / 累計）は v0.1 で全部出すか? →
  全部実装。RSS エンドポイントが分かれているだけで実装コストは小さい。
- **Q-D3**: 縦書き表示は v0.1 で出すか? → 共通 reader UI が
  `add-online-novel-library` で v0.1 サポートする想定でそれに乗る。共通側で
  v0.2 に倒れた場合、横書きのみで先行リリース。
- **Q-D4**: パーサ失敗時の「詳細をコピー」がプライバシー情報を含まないか? →
  HTML 全体ではなく、失敗セレクタ / URL / アプリバージョン / OS のみに限定。
  tasks の QA セクションで確認。
- **Q-D5**: スナップショット fixture の更新頻度? → 月 1 回手動が現実的。
  CI で「fixture が 90 日以上更新されていない」警告を出すかは v0.2 で検討。

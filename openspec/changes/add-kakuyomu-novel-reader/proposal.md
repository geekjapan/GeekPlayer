## Why

GeekPlayer v0.1 のオンライン小説機能のうち、**カクヨム** のリーダー体験を実装する。
カクヨムには公式 API がないため、検索 / 一覧 / 通知は **公式 RSS / Atom フィード**、
作品本文は **HTML パース** で取得する方針が
[ADR-0001](../../../docs/adr/0001-online-novel-fetch-policy.md) で確定している。
本 change はその方針を具体的なコードとして降ろす責務を負い、
[`docs/roadmap.md`](../../../docs/roadmap.md):14 が v0.1 MVP に含めると宣言した
3 サイト統合体験（なろう / ノクターン系 / カクヨム）の最後のピースを構成する。

なろう / ノクターン系は別 change（`add-narou-novel-reader`）、共通インフラ
（`NovelRepository` interface / `RateLimiter` / `site-consent`）は
`add-online-novel-library` の責務に分離されており、本 change は **カクヨム固有部分**
に閉じる。

## What Changes

- **新規**: `webfeed_revised` で公式 RSS / Atom フィード（新着 / ランキング / 検索結果 /
  作品更新通知）を取得する `KakuyomuRssSource`。
- **新規**: `dio` + `html` で作品ページ / エピソードページの HTML を取得・パースする
  `KakuyomuHtmlSource`。ADR-0001 の責任あるスクレイピング規範
  （User-Agent / `robots.txt` / 1 req / 2 sec / 並列 1 / 429・503 指数バックオフ
  最大 5 分）を全リクエストに適用する。
- **新規**: 上記 2 ソースをまとめて `add-online-novel-library` が定義する
  `NovelRepository` interface を満たす `KakuyomuNovelRepository`。
- **新規**: カクヨム専用の `robots.txt` キャッシュと評価ロジック。同一プロセス内で
  `robots.txt` を 1 時間キャッシュし、disallow パスへのアクセスは早期に拒否する。
- **新規**: カクヨム同意ダイアログのテキスト・ボタンラベル・遷移を実装し、
  `add-online-novel-library` の `site-consent` capability が公開する API 経由で
  「カクヨムへの同意状態」を読み書きする。同意なし時はカクヨム機能を完全に無効化
  （UI 上もエントリ非表示）。
- **新規**: カクヨム UI（検索画面 / 新着 RSS タイムライン / ランキング RSS リスト /
  作品詳細画面 / エピソードリーダー画面）。
- **新規**: HTML 構造変更を早期検知するスナップショットテスト戦略。固定の HTML
  fixture（`app/test/fixtures/kakuyomu/`）に対するゴールデンパース結果テストと、
  実環境 smoke テスト（手動・週次想定）。
- **新規**: パーサ失敗時のフォールバック動線（公式ビューアを外部ブラウザ / WebView
  で開くボタン）。
- **新規**: ADR-0001 の注意書きを 4 箇所のうちカクヨム固有部分（`KakuyomuHtmlSource`
  クラス docstring、同意ダイアログ文言、設定画面のカクヨムセクション文言）に
  ハードコードで書き込む。README の文言は
  [`README.md`](../../../README.md):47 で既に存在。

## Capabilities

### New Capabilities

- `kakuyomu-novel-source`: `KakuyomuRssSource` / `KakuyomuHtmlSource` /
  `KakuyomuNovelRepository` の実装と、カクヨム固有のレート制限・User-Agent・
  `robots.txt` 尊重・429/503 指数バックオフの運用規範。
- `kakuyomu-novel-reader-ui`: カクヨムの検索 / 新着 / ランキング / 作品詳細 /
  リーダー画面、および同意ダイアログ文言と設定画面のカクヨムセクション。
- `kakuyomu-resilience`: HTML 構造変更を早期検知するスナップショットテスト戦略、
  パーサ失敗時に公式ビューアへフォールバックするユーザー動線、ToS が
  自動収集を明示禁止した場合の機能停止フロー。

### Modified Capabilities

（なし — カクヨム固有 capability はこの change で初めて生まれる。共通の
`online-novel-library` / `site-consent` は `add-online-novel-library` の責務であり、
本 change からはそれらの interface に依存するのみで requirement は変更しない）

## Impact

**新規ディレクトリ / ファイル（予定）:**

- `app/lib/features/novel/kakuyomu/data/kakuyomu_rss_source.dart`
- `app/lib/features/novel/kakuyomu/data/kakuyomu_html_source.dart`
- `app/lib/features/novel/kakuyomu/data/kakuyomu_novel_repository.dart`
- `app/lib/features/novel/kakuyomu/data/kakuyomu_robots_txt_cache.dart`
- `app/lib/features/novel/kakuyomu/data/kakuyomu_html_parser.dart` —
  パーサ単体（差し替え可能化）
- `app/lib/features/novel/kakuyomu/domain/{kakuyomu_work.dart, kakuyomu_episode.dart, kakuyomu_search_query.dart}`
- `app/lib/features/novel/kakuyomu/presentation/{search_screen.dart, latest_feed_screen.dart, ranking_screen.dart, work_detail_screen.dart, reader_screen.dart, parser_failure_fallback.dart}`
- `app/lib/features/novel/kakuyomu/presentation/kakuyomu_consent_dialog.dart`
- `app/test/fixtures/kakuyomu/` — RSS / 作品ページ / エピソードページ HTML の
  ゴールデン fixture
- `app/test/features/novel/kakuyomu/` — ユニット / スナップショットテスト

**変更（想定）:**

- `app/pubspec.yaml` — `webfeed_revised`, `html`, `dio` を追加（既に
  `add-online-novel-library` で `dio` が入っている場合は省略可）
- `app/lib/main.dart`（行は確定していないがホーム画面相当） — カクヨム UI への
  ナビゲーションエントリを追加。同意なし時は非表示
- `app/lib/features/settings/`（`add-online-novel-library` 想定で存在） —
  カクヨムセクションを追加し、同意トグル / 注意書き / レート制限の現状値 / 直近
  パース失敗のメトリクス（簡易）を表示

**外部依存（カクヨム側）:**

- カクヨム公式 RSS / Atom フィードのスキーマ
- カクヨム作品ページ / エピソードページの HTML 構造
- カクヨムの `robots.txt`
- カクヨム利用規約（ToS）— 自動収集の明示禁止条項が将来追加された場合は本機能を
  即時無効化する

**プラットフォーム影響:**

- v0.1 対象の macOS / Windows / Android 全てでネットワーク許可とテキスト描画のみ
  なので OS 固有設定は不要
- Android で `INTERNET` permission は既に音楽 / 動画機能で必要なのでこの change で
  追加する必要はない（既存変更があれば再確認）

**ライセンス影響:**

- `webfeed_revised` (BSD-3 想定) / `html` (BSD-3) / `dio` (MIT) — いずれも Apache-2.0
  と互換。`THIRD_PARTY_NOTICES.md` への追記が必要

**Non-goals:**

- **なろう / ノクターン系の実装** — 別 change `add-narou-novel-reader` の責務。
- **共通インフラ** — `NovelRepository` interface / `RateLimiter` / `site-consent` /
  drift スキーマは `add-online-novel-library` の責務。本 change はそれらに依存する
  だけで、定義は持たない。
- **書籍 / 漫画 / 動画 / 音楽** — 別 feature。
- **カクヨムへのログイン / ブックマーク / レビュー投稿** — 公式手段なし、
  かつスコープ外。
- **能動キャッシュ以外のキャッシュ戦略** — 受動的クロール / ミラーリング /
  事前ダウンロードは ADR-0001 で明示禁止のため永続的に非対象。
- **カクヨム公式 API への移行** — 公式 API が提供された場合は新 ADR を立てて別
  change で対応する。
- **HTML 構造変更を自動検知して動的にセレクタを推測する機能** — スコープを
  膨らませる割に脆い。スナップショットテストでの早期検知 + 手動修正で対応する。
- **TLS 証明書ピンニング** — カクヨム側の証明書ローテーションに追随する保守
  コストに見合わない。

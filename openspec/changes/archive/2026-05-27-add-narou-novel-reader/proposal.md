> **Related ADRs**: [ADR-0001](../../../docs/adr/0001-online-novel-fetch-policy.md) (online novel fetch policy), [ADR-0003](../../../docs/adr/0003-narou-content-fetch-policy.md) (narou content fetch policy)

## Why

GeekPlayer v0.1 のオンライン小説機能のうち、最大の対象サイトである「小説家になろう」
と R18 系統（ノクターン / ミッドナイト / ムーンライト）のリーダー体験を提供する。
[`docs/roadmap.md`](../../../docs/roadmap.md:14) で v0.1 に含めると宣言した
オンライン小説機能のうち、なろう側は公式 API が整備されており
[`docs/adr/0001-online-novel-fetch-policy.md`](../../../docs/adr/0001-online-novel-fetch-policy.md)
の取得方針に従えば法務リスクなく実装できる。共通の `NovelRepository` 抽象と
ストレージ / 同意 / レート制限の基盤は別 change `add-online-novel-library`
で導入される前提で、本 change はその抽象を満たすなろう専用実装と専用 UI を
構築する。

## What Changes

- **新規**: `NarouNovelRepository` を `app/lib/features/novel_narou/data/narou_novel_repository.dart` に実装。`api.syosetu.com/novelapi/api/` を `dio` で叩き、検索 / ランキング / 作品詳細 / エピソード一覧 / 本文を取得する。
- **新規**: `NarouR18NovelRepository` を `app/lib/features/novel_narou/data/narou_r18_novel_repository.dart` に実装。`api.syosetu.com/novel18api/api/` をベースに同等の機能を提供する。R18 同意済みでなければインスタンス化を拒否する。
- **新規**: なろう検索パラメタモデル `NarouWorkQuery` を `app/lib/features/novel_narou/domain/narou_work_query.dart` に定義（ジャンル、文字数下限/上限、最終更新日範囲、ピックアップ、完結フラグ、長期連載フラグ、文体タグ等）。共通 `WorkQuery` を narou 拡張で具体化する形。
- **新規**: ランキング取得（日間 / 週間 / 月間 / 四半期 / 年間 / 累計）を `NarouRankingRepository` 経由で提供。`rankget` エンドポイントと作品詳細取得を 2 段階で組み合わせる。
- **新規**: 作品詳細とエピソード一覧画面。`ncode` をキーにメタデータ（タイトル / 著者 / あらすじ / タグ / 全話数 / 文字数 / 最終更新）と話一覧を表示。
- **新規**: 本文取得器 `NarouEpisodeFetcher`。公式 API の本文取得経路（短編は `out=epi`、連載は各話パスの構造化フィールド）を抽象化する。詳細経路は design.md の Open Questions で扱う。
- **新規**: R18 系統サイト（ノクターン / ミッドナイト / ムーンライト）専用の年齢確認ダイアログを `app/lib/features/age_gate/presentation/age_gate_dialog.dart` に実装。同意は `drift` の `site_consents` テーブル経由で永続化し、`Settings > オンライン小説` 画面から再設定できる。
- **新規**: 縦スクロール式リーダー画面 `app/lib/features/novel_narou/presentation/reader_screen.dart`。フォントサイズ調整 / 行間調整 / 明暗テーマ / ページ内栞（`ResumePoint`）/ 前後話遷移を提供する。
- **新規**: 「Library に追加」アクション。`add-online-novel-library` 側の能動キャッシュ起動 API を呼び、なろう作品の全話をローカル DB に保存する。
- **新規**: ホーム画面に「なろう」セクション（検索 / ランキング / ピックアップ）を追加（`HomeScreen` 側の compose は `add-online-novel-library` 側で確定する `NovelHomeSection` interface に依存）。

## Capabilities

### New Capabilities

- `narou-novel-source`: `NarouNovelRepository` と `NarouR18NovelRepository` を中心にした、なろうグループの API クライアント能力。検索 / ランキング / 詳細 / 本文取得の API 契約とレート制限規範を定義する。
- `narou-novel-reader-ui`: なろう作品の検索画面・ランキング画面・作品詳細画面・エピソード一覧・縦スクロールリーダー画面の UI 能力。フォント / テーマ / 栞操作の動作を定義する。
- `r18-age-gate`: ノクターン系 API を呼ぶ前のユーザー年齢確認ダイアログと、その同意状態の永続化・再設定能力。

### Modified Capabilities

（なし — `add-online-novel-library` change で導入される `online-novel-library` capability にはこの change から **依存** するが、`online-novel-library` の要件は本 change では変更しない）

## Impact

**新規ディレクトリ / ファイル:**

- `app/lib/features/novel_narou/data/narou_novel_repository.dart`
- `app/lib/features/novel_narou/data/narou_r18_novel_repository.dart`
- `app/lib/features/novel_narou/data/narou_api_client.dart` — `dio` ベースの低レベルクライアント
- `app/lib/features/novel_narou/data/narou_episode_fetcher.dart`
- `app/lib/features/novel_narou/domain/narou_work_query.dart`
- `app/lib/features/novel_narou/domain/narou_genre.dart`
- `app/lib/features/novel_narou/domain/narou_ranking_type.dart`
- `app/lib/features/novel_narou/domain/narou_work_summary.dart`
- `app/lib/features/novel_narou/domain/narou_work_detail.dart`
- `app/lib/features/novel_narou/domain/narou_episode.dart`
- `app/lib/features/novel_narou/presentation/search_screen.dart`
- `app/lib/features/novel_narou/presentation/ranking_screen.dart`
- `app/lib/features/novel_narou/presentation/work_detail_screen.dart`
- `app/lib/features/novel_narou/presentation/episode_list_section.dart`
- `app/lib/features/novel_narou/presentation/reader_screen.dart`
- `app/lib/features/novel_narou/presentation/reader_settings.dart`
- `app/lib/features/novel_narou/presentation/narou_home_section.dart`
- `app/lib/features/age_gate/data/site_consent_repository.dart` — `add-online-novel-library` 側で `site_consents` テーブルが導入される前提で、その DAO 利用クライアント
- `app/lib/features/age_gate/presentation/age_gate_dialog.dart`
- `app/lib/features/age_gate/presentation/age_gate_settings_section.dart`
- `app/test/features/novel_narou/**` — 単体・ウィジェット・スナップショットテスト

**変更:**

- `app/pubspec.yaml` — `dio` が `add-online-novel-library` 側で追加されていなければ本 change でも追加要請。`html_unescape`（あらすじや本文中の HTML エンティティ処理）を新規追加。
- `app/lib/main.dart:1` — `HomeScreen` の compose に `NarouHomeSection` を追加（`add-local-video-playback` で再構成された `HomeScreen` を前提）。

**依存する change:**

- `add-online-novel-library`: `NovelRepository` interface、`Work` / `Episode` / `Site` ドメインモデル、`site_consents` テーブル、`RateLimiter`、能動キャッシュ起動 API、共通 `NovelHomeSection` interface、同意ダイアログ基盤。これらが提供される前提で実装する。
- `add-local-video-playback`: `HomeScreen` の合成ポイントと drift DB 基盤。

**プラットフォーム影響:**

- ネットワーク権限のみ。Android は `INTERNET` permission（既定で付与）以外不要。
- macOS sandbox に `com.apple.security.network.client` entitlement が必要。
- v0.1 対象 3 OS（macOS / Windows / Android）で API レスポンス互換性を確認する。

## Non-goals

- カクヨム関連の取得ロジック / UI は別 change `add-kakuyomu-novel-reader` で扱う。
- 共通の `NovelRepository` interface 定義、`Work` / `Episode` の drift スキーマ、`RateLimiter`、`SiteConsent` ストレージ層、初回起動同意ダイアログは `add-online-novel-library` の責務。本 change では **利用するのみ**。
- 書籍（PDF / EPUB）/ 漫画（ZIP / CBZ）/ 動画 / 音楽の機能は対象外。
- ユーザー投稿（感想 / レビュー / 評価送信）への対応は対象外。読み取り専用。
- なろうログイン認証（しおり同期 / マイページ）は対象外。
- 横書き / 縦書き切り替えは対象外（縦スクロール横書きのみ）。縦書きは v0.2 以降で別 change。
- TTS（読み上げ）は対象外。v1.x 以降。
- AI 要約 / 翻訳は対象外。v1.x 以降。
- Linux / iOS / iPadOS ビルド設定は対象外（v0.2）。

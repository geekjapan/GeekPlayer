## Context

「小説家になろう」グループは日本最大級の Web 小説プラットフォームで、
GeekPlayer v0.1 のオンライン小説機能では最も優先順位が高い対象である。
グループは大きく 2 系統に分かれる:

| 系統 | API ベース | 対象作品 |
|---|---|---|
| 一般 | `https://api.syosetu.com/novelapi/api/` | 小説家になろう |
| R18 | `https://api.syosetu.com/novel18api/api/` | ノクターン / ミッドナイト / ムーンライト |

両系統とも公開仕様の JSON API があり、検索 / ランキング / メタデータ取得は同じ
インターフェース。本文取得はエピソード単位で別系統のエンドポイントを使う必要が
ある（詳細は Open Questions 参照）。

[`docs/adr/0001-online-novel-fetch-policy.md`](../../../docs/adr/0001-online-novel-fetch-policy.md)
で固定された運用規範は本 change にもそのまま適用される:

- **能動キャッシュのみ**: `Library` に追加された `Work` のみ本文をローカル DB に保存
- **User-Agent**: `GeekPlayer/<version> (+https://github.com/geekjapan/GeekPlayer; personal-use)`
- **429 / 503 で指数バックオフ**（最大 5 分）
- **同意ダイアログ**: サイト別。なろう一般は同意必須でないが、R18 系統は年齢確認が必須

`add-online-novel-library` が提供する前提のもの:

- `NovelRepository` interface（検索 / 詳細 / 本文の共通契約）
- ドメインモデル `Work` / `Episode` / `Site` / `WorkQuery`
- drift テーブル `works`, `episodes`, `episode_bodies`, `site_consents`, `library_entries`
- `RateLimiter` ユーティリティ
- 共通 `NovelHomeSection` interface（`HomeScreen` 合成点）
- 初回起動時の汎用同意ダイアログ
- ja-first の文言基盤と空状態表示

本 change はこれらを **利用するだけ**で、定義しない。

## Goals / Non-Goals

**Goals:**

- なろう一般 / R18 系統の検索 / ランキング / 詳細 / 本文取得を、共通 `NovelRepository`
  抽象に適合する形で実装する
- `WorkQuery` の narou 拡張で、なろう固有パラメタ（ジャンル / 文字数 / 最終更新日 /
  ピックアップ / 完結フラグ等）を扱える
- ノクターン系 API を呼ぶ前に年齢確認ダイアログを必ず挟み、同意を永続化する
- 縦スクロールのリーダー画面で、フォントサイズ / 行間 / 明暗テーマ / 栞 / 前後話遷移を
  提供する
- ADR-0001 の規範（1 req/sec, 並列 2, 指数バックオフ, User-Agent 規範）を遵守する
- macOS / Windows / Android の 3 OS で API 互換性を確認する

**Non-Goals:**

- カクヨム実装（別 change）
- 共通 `NovelRepository` / drift スキーマ / `RateLimiter` / 同意基盤の **定義**（依存先 change の責務）
- ユーザー投稿（感想 / 評価 / レビュー）
- ログイン認証（マイページ / しおり同期）
- 縦書き表示 / TTS / AI 要約 / 翻訳
- Linux / iOS / iPadOS

## Decisions

### D1. API クライアントは `dio` + 自前モデルレイヤ、コードジェネレーションなし

`dio` で生 GET を叩き、レスポンスを `freezed` ベースの値オブジェクト
（`NarouWorkSummary` / `NarouWorkDetail`）に手書き mapper で写す。`retrofit` /
`chopper` は採用しない:

- なろう API は GET + querystring のみで RPC 的構造ではない
- レスポンス形式（`out=json`）は配列の先頭要素に `allcount` を入れる癖があり、
  自動マッピングではむしろ readability を損なう
- 失敗時のフォールバック（429 / 503 の指数バックオフ）を `dio` の `Interceptor` に
  乗せたい

**代替案: `http` パッケージ直叩き** → `Interceptor` がなく、レート制限と
バックオフ実装が散らかる。`dio` の方が拡張点が揃っている。

### D2. なろう一般 / R18 で同一の低レベル `NarouApiClient` を共有、ベース URL のみ切り替える

```dart
class NarouApiClient {
  NarouApiClient({required Uri baseUrl, required Dio dio, required RateLimiter limiter});
  Future<NarouSearchResponse> search(NarouWorkQuery query);
  Future<NarouRankingResponse> ranking(NarouRankingType type, DateTime date);
  Future<NarouWorkDetail> detail(String ncode);
}
```

`NarouNovelRepository` と `NarouR18NovelRepository` はこの `NarouApiClient` を
別インスタンス（別 baseUrl）で保持する。R18 リポジトリは `SiteConsent` の状態を
コンストラクタで検査し、未同意ならインスタンス化を弾く。

**代替案: 2 つのクライアントを完全に別クラス** → API 仕様が同一なので DRY 違反。
互換性検査も二重メンテになる。

### D3. 本文取得は専用 `NarouEpisodeFetcher` に隔離する

なろう API の検索エンドポイントは本文を返さない。本文取得経路は連載 / 短編で
分岐し、また仕様が変わりやすい（Open Questions 参照）。これらの分岐を
`NarouEpisodeFetcher` に集中させ、リポジトリ層からは
`Future<String> fetchBody(String ncode, int episodeIndex)` の単一インターフェース
として見せる。

**代替案: リポジトリに直接実装** → 経路分岐がリポジトリの責務を肥大化させる。
将来仕様変更が来た時の差し替えポイントが拡散する。

### D4. レート制限はサイト単位、`add-online-novel-library` 提供の `RateLimiter` を使う

なろう一般と R18 は **物理的に同一 origin**（`api.syosetu.com`）。レート制限
バケットは `Site` ではなく **origin 単位**で持つ。`RateLimiter` のキーは
"`api.syosetu.com`" 固定で、両リポジトリが同じバケットを共有する。

規範: 1 req / 秒、最大並列 2。なろう側に明示制限はないが、ADR-0001 の責任ある
スクレイピング規範に揃える（API でも同じ）。

**代替案: サイトごとに別バケット** → 同一 origin に対する見かけ上の流量が 2 倍に
なる。なろう側からは区別できないので避ける。

### D5. `NarouWorkQuery` は共通 `WorkQuery` を継承せず、`extensions: NarouQueryExtensions` で持つ

共通 `WorkQuery`（`add-online-novel-library` 定義）にサイト固有パラメタを乗せると
カクヨム拡張と衝突する。代わりに sealed `WorkQueryExtensions` を導入し、
narou は `NarouQueryExtensions` を `WorkQuery.extensions` に詰める。

```dart
class WorkQuery {
  final String? keyword;
  final WorkQueryExtensions? extensions;
}

sealed class WorkQueryExtensions {}
class NarouQueryExtensions extends WorkQueryExtensions {
  final Set<NarouGenre> genres;
  final int? minChars;
  final int? maxChars;
  final DateTime? lastUpdatedAfter;
  final bool? completed;
  final bool? pickup;
  // ...
}
```

`extensions` フィールドの追加は `add-online-novel-library` 側で対応する必要がある
（依存先 change へ依頼）。本 change ではその拡張を **使う** だけ。

**代替案: `Map<String, dynamic>` で渡す** → 型安全性がなくテスタビリティが落ちる。

### D6. ランキングは `rankget` の ID 列 → detail 一括取得で構成

`rankget` エンドポイントは作品 ID と順位だけを返す（メタデータなし）。UI で
ランキング画面を表示するには、上位 N 件の `ncode` を `detail` で **一括取得**
する必要がある。一括取得は `ncode-ncode-ncode` の `-` 区切りで複数 ID 指定が
可能（API 仕様）。

`NarouRankingRepository.fetchRanking(NarouRankingType, DateTime)` は内部で
2 段階呼び出しを行い、上位 100 件を返す。100 件超のページネーションは UI 側で。

### D7. R18 同意ダイアログのフロー

1. ユーザーが「ノクターン」「ミッドナイト」「ムーンライト」関連のタブ / ボタンに触れた瞬間
2. `SiteConsent` を `add-online-novel-library` の `SiteConsentRepository` から取得
3. 未同意 / 拒否なら `AgeGateDialog` を `showDialog` で出す
4. ダイアログは「あなたは18歳以上ですか?」+ 「はい / いいえ」のシンプル UI、説明文と注意書きを含む
5. 「はい」で `SiteConsentRepository.grant(SiteId.noctune)` を呼び、ダイアログを閉じて R18 機能を解放
6. 「いいえ」または閉じる操作でダイアログをキャンセル扱い、R18 機能ロックを継続

同意は **3 サイト（noctune / midnight / moonlight）で 1 つのフラグ** にする
（API が共通の `novel18api` で内部的に同系統扱いだから）。`SiteId` enum には
`narou18` という統合キーを用意する（`add-online-novel-library` 側に依頼）。

`Settings > オンライン小説` 画面に「年齢確認をやり直す」項目を追加。タップで
`SiteConsentRepository.revoke(SiteId.narou18)` を呼ぶ。

### D8. リーダー画面は `SingleChildScrollView` ベース、`ReaderTheme` 値オブジェクトでスタイル管理

縦スクロール、`ListView.builder` ではなく `SingleChildScrollView` + `SelectableText.rich`
を採用（章内 1 本のテキストとしてコピー可能にするため）。

`ReaderTheme` は `fontSize` (12〜32 pt) / `lineHeight` (1.2〜2.4) / `colorScheme`
(`light` / `sepia` / `dark`) の値オブジェクト。`SharedPreferences` ではなく
**drift の `reader_settings` テーブル**（単一行）に保存する（同意状態と
DB 統一管理）。`reader_settings` テーブルは本 change で追加する（共通基盤と
判断するか議論余地あり。本 change で完結させる）。

栞は `ResumePoint` を再利用する。動画と同じ `playback_positions` ではなく
`add-online-novel-library` の `episode_resume_points` テーブルを使う:
`(workId, episodeIndex, scrollOffset)` の 3 カラム。

**代替案: `flutter_html` で HTML レンダリング** → なろう本文はプレーンテキスト
寄りで、ルビ（`|漢字《かんじ》` 記法）と挿絵タグ程度。専用パーサで HTML より軽い。

### D9. ルビ表記の処理

なろう独自記法 `|漢字《かんじ》` と `《ルビ》` 直前 1 文字パターンは正規表現で
解析し、`TextSpan` の `WidgetSpan` でルビを上に重ねる `RubyText` ウィジェットに
変換する。挿絵タグ `<i123|456|789>` は本 change では **テキスト中に
\[挿絵\] プレースホルダー** として表示するのみ。実画像表示は別 change。

### D10. 「Library に追加」の能動キャッシュフロー

ユーザーが作品詳細画面で「Library に追加」を押した時:

1. `LibraryService.add(work)` を呼ぶ（`add-online-novel-library` 提供）
2. `LibraryService` 側で全話のメタデータ取得 → 本文ダウンロードジョブを起動
3. 本 change の `NarouEpisodeFetcher` がジョブから呼ばれて 1 話ずつ本文取得
4. レート制限 1 req/sec を守るので、100 話 = 約 100 秒
5. 進捗は `LibraryService` 提供の `Stream<DownloadProgress>` で UI に流す

本 change の責務は **`NarouEpisodeFetcher` がジョブから呼べる形** に整っていること
のみ。ジョブ管理本体は依存先。

### D11. テスト戦略

- **ユニット**: `NarouApiClient` のリクエストビルダーと mapper を 100% カバー。
  HTTP は `dio` の `MockAdapter` でレスポンスを差し替え。
- **スナップショット**: 実 API の代表的なレスポンス JSON 3〜5 件を
  `test/fixtures/narou/` に保存し、mapper の互換性を検証。
- **ウィジェット**: 検索 / ランキング / 詳細 / リーダー / 年齢確認ダイアログを
  ProviderScope で mock リポジトリを流し込んで描画確認。
- **integration_test**: 実 API を 1 回だけ叩く smoke test を `app/integration_test/`
  に置く（CI では skip、ローカル / リリース前に手動実行）。
- **R18 同意**: 同意なしで R18 リポジトリを構築すると例外、同意後はインスタンス化
  成功、を必ずカバー。

## Risks / Trade-offs

- **なろう API レスポンス形式変更** → mapper でフィールド欠損時に `null` を許容
  する設計にし、スナップショットテストで早期検知。重要フィールド（`ncode`,
  `title`）のみ必須、それ以外は optional。
- **R18 ダイアログを設定で誤って無効化された場合のフォールバック** →
  `NarouR18NovelRepository` のコンストラクタで `SiteConsent` を必ず再検査。
  同意 revoke が走ったら既存インスタンスを破棄する Riverpod の
  `ref.invalidate` を `SiteConsentRepository` 側のリスナーで強制。
- **`api.syosetu.com` の TLS 証明書 / DNS 障害** → `dio` の `connectTimeout`
  10 秒、`receiveTimeout` 30 秒、3 回リトライ（指数バックオフ）。失敗時は
  UI で「接続できません」エラーを出す。
- **長期連載作品 (1000+ 話) の Library 追加負荷** → ダウンロード起動時に
  「本作品は X 話あります。約 Y 分かかります。続行しますか?」の確認ダイアログを出す。
  Y は話数 ÷ 60 で算出（1 req/sec 換算）。
- **ルビ / 挿絵記法の解析誤検知** → 失敗時はプレーンテキストにフォールバック、
  解析ログを analytics に出さない（責任あるロギング規範）。
- **R18 拒否時の UX 劣化** → 拒否されたら R18 タブ自体を非表示にし、設定画面
  からのみ再有効化できるようにする。

## Migration Plan

- 既存ユーザーなし（greenfield）→ DB マイグレーションはなし
- ロールバック: change リバート → `Settings > オンライン小説 > 年齢確認` 項目
  と「なろう」セクションが消える。`site_consents` テーブルのレコードは残るが
  影響なし
- 依存先 change `add-online-novel-library` がまだ未実装の段階で本 change を
  apply しないこと（タスク段階で前提チェック）

## Open Questions

- **Q-D1**: なろう連載作品の本文取得の正規エンドポイント
  - 公式 API ドキュメント上、`out=json` の検索/詳細 API には本文フィールドがない
  - 各話本文取得は (a) `https://ncode.syosetu.com/<ncode>/<episode>/` の HTML
    パース、(b) 別途公開されているデータダンプの利用、(c) 短編のみ API で取得し
    連載は HTML パース、のいずれか
  - 暫定方針: (c) を採用。短編は `api/?ncode=...&out=epi` で本文取得、連載は
    `ncode.syosetu.com/<ncode>/<n>/` の HTML を `html` パッケージでパース
  - 実装時に再調査し、ADR を追加するか design を更新する
- **Q-D2**: ランキング画面の表示件数上限。100 件 / 300 件 / 全件のどれか
  - 暫定方針: 100 件固定。スクロール末尾で「もっと見る」→ 次の 100 件取得
- **Q-D3**: R18 同意の「期限」を設けるか
  - 暫定方針: 期限なし。明示的な revoke のみで失効
- **Q-D4**: 検索結果のキャッシュ TTL
  - 暫定方針: メモリキャッシュのみ 5 分、ディスクキャッシュなし（能動キャッシュ
    規範に揃える）
- **Q-D5**: なろうの年齢制限作品（R15）は一般 API にも含まれるか
  - 仕様調査が必要。暫定方針: 一般 API に含まれる場合はそのまま表示、ノクターン
    系統のみ年齢ゲートを通す

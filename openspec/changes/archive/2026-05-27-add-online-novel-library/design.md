## Context

GeekPlayer の v0.1 では「小説家になろう / ノクターン系 / カクヨム」の 3 サイトを 1 つのライブラリ体験に統合する。これらは取得方式が非対称（公式 API / 公式 API / RSS + HTML パース）で、[ADR-0001](../../../docs/adr/0001-online-novel-fetch-policy.md) により「能動キャッシュのみ」「カクヨムは 1req/2s」「同意ダイアログ」「指数バックオフ」など運用規範が固められている。

本 change はサイト別 change（後続の `add-narou-novel-reader` / `add-kakuyomu-novel-reader`）が安全に乗れる **インフラ層** を確立する。具体的には:

- サイト非依存の `NovelRepository` interface（`Site` / `Work` / `Episode`）
- `novel_works` / `novel_episodes` / `novel_bookmarks` / `site_consents` の drift スキーマ
- 「Library に追加」フロー（能動キャッシュの起点）
- サイト別同意ダイアログと設定画面の同意管理
- `RateLimiter` / User-Agent / `robots.txt` / 指数バックオフのネットワーク基盤
- ホーム画面の `NovelHomeSection`
- `add-local-video-playback` が定義した sealed `MediaSession` に `PageSession` を最小 API で増設

前提:

- 状態管理: Riverpod v2 (Notifier API)
- データ永続化: 単一 drift SQLite DB（[`app/lib/core/storage/database.dart`](../../../app/lib/core/storage/database.dart) を `add-local-video-playback` が初期化済み）
- HTTP クライアント: 本 change で **`dio`** を初導入
- 対象 OS: macOS / Windows / Android (v0.1)
- 既存抽象: `MediaSession`（sealed）/ `MediaPosition` / `MediaSpeed` / `MediaPlayState`（[ADR-0002](../../../docs/adr/0002-hybrid-media-engine.md) と `add-local-video-playback`）

## Goals / Non-Goals

**Goals:**

- サイト別 change が `NovelRepository` を `implements` するだけで、Library / 同意 / レート制限 / バックオフ / 通信ヘッダの全運用規範が自動で適用される
- 「Library に追加」がトリガーとなり、ユーザーが選んだ `Work` の全 `Episode` 本文を `novel_episodes.body` に書き込む（受動キャッシュは型レベルで存在しない）
- カクヨムだけ別レート（1req/2s、並列度 1）を強制できるよう、`Site` 単位で `RateLimiter` を持つ
- 同意なしの `Site` の `NovelRepository` 呼び出しは早期エラー（`SiteConsentRequiredError`）にする
- macOS / Windows / Android の 3 OS で同一の通信挙動（ADR-0001 規範）になる
- `PageSession` を sealed に増やしても、video / audio の既存テストを壊さない

**Non-Goals:**

- なろう / ノクターン / カクヨムの具体実装（後続 change）
- 検索 / ランキング / タグ絞り込み（後続 change）
- 書籍 / 漫画の本格 `PageSession`（v0.2）
- 縦書きレンダリング / フォント / しおり粒度（後続 change で `LibraryReader` が個別実装）
- オフライン差分同期 / 著者更新通知 / プッシュ通知（v0.2 以降）
- Linux / iOS / iPadOS のネットワーク entitlement（v0.2）

## Decisions

### D1. `NovelRepository` interface とサイト分離

```dart
abstract interface class NovelRepository {
  Site get site;
  Future<Work> fetchWork(WorkId id);
  Stream<Episode> fetchEpisodes(WorkId id);   // 進捗を逐次返す
  Future<EpisodeBody> fetchEpisodeBody(WorkId workId, EpisodeId episodeId);
}
```

- `WorkId` は `(Site site, String externalId)` の値オブジェクト。複合主キーで `novel_works` に保存。
- `Stream<Episode>` を返すのは、なろうの「全話一括」とカクヨムの「目次ページ → 各話」両方を統一して扱うため。
- `fetchEpisodeBody` は Library 追加時に逐次呼ばれる。サイト別実装が内部で `RateLimiter` を待つ。

**代替案**: `Future<List<Episode>>` を返す
→ なろう公式 API ならよいが、カクヨムは目次ページ取得後に各話 URL を 1 つずつ叩く必要があり、UI 進捗が出せない。Stream に統一する。

### D2. drift スキーマ：複合主キー、本文は別テーブル

```dart
class NovelWorks extends Table {
  TextColumn get site => text()();             // 'narou' / 'noc' / 'kakuyomu'
  TextColumn get externalId => text()();       // ncode / kakuyomu work id
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get synopsis => text().nullable()();
  IntColumn get episodeCount => integer()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  @override Set<Column> get primaryKey => {site, externalId};
}

class NovelEpisodes extends Table {
  TextColumn get site => text()();
  TextColumn get externalId => text()();        // work external id
  IntColumn get episodeIndex => integer()();    // 1-based
  TextColumn get title => text()();
  TextColumn get body => text()();              // 本文（プレーンテキスト or 軽量マークアップ）
  DateTimeColumn get fetchedAt => dateTime()();
  @override Set<Column> get primaryKey => {site, externalId, episodeIndex};
}

class NovelBookmarks extends Table {
  TextColumn get site => text()();
  TextColumn get externalId => text()();
  IntColumn get episodeIndex => integer()();
  RealColumn get scrollFraction => real()();    // 0.0..1.0
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column> get primaryKey => {site, externalId};
}

class SiteConsents extends Table {
  TextColumn get site => text()();
  BoolColumn get granted => boolean()();
  DateTimeColumn get decidedAt => dateTime()();
  TextColumn get policyVersion => text()();     // 同意した ADR-0001 のバージョン
  @override Set<Column> get primaryKey => {site};
}
```

- `NovelBookmarks` は **1 Work につき 1 つの "現在読書位置"** （ResumePoint 相当）。複数しおり / 章しおりは v0.2。
- `policyVersion` を持つことで、ADR-0001 が次バージョンで責任範囲を広げた場合に再同意を促せる。
- 本文（`body`）は `NovelEpisodes` 内に持ち、Work 一覧表示時には fat row を読まない（drift の select は明示カラム指定で済む）。

**代替案**: 本文を別テーブル `novel_episode_bodies` に分ける
→ 過剰正規化。drift では select 列を絞れば fat row 問題は起きない。

### D3. 能動キャッシュは型で強制する

`fetchEpisodeBody` の戻り値 `EpisodeBody` は domain 値で、**`novel_episodes.body` への書き込みは `LibraryRepository.addToLibrary` の中だけで行う**。`fetchEpisodeBody` 単体は `EpisodeBody` を返すだけで永続化しない。これにより「読んだだけのカクヨム作品が知らぬ間にキャッシュされる」事故を型レベルで防ぐ。

ADR-0001 §取得方針-1（能動キャッシュのみ）の機械可読版が `responsible-fetching` の Requirement と `online-novel-library` の Requirement の組み合わせ。

### D4. `RateLimiter` は token bucket、`Site` 単位でシングルトン

```dart
class RateLimiter {
  RateLimiter({required this.rate, required this.burst, required this.maxConcurrency});
  final double rate;          // tokens per second
  final int burst;
  final int maxConcurrency;
  Future<T> run<T>(Future<T> Function() task);
}
```

設定例:

- なろう / ノクターン: `rate: 1.0, burst: 5, maxConcurrency: 4`（公式 API 想定の保守値）
- カクヨム: `rate: 0.5, burst: 1, maxConcurrency: 1`（ADR-0001 §取得方針-3 を直訳）

`RateLimiter` インスタンスは `Site` ごとに 1 つ Riverpod provider で持たせる（`Provider<RateLimiter>.family<Site>`）。

**代替案**: `package:rate_limiter` を使う
→ Pub の rate_limiter は debounce/throttle 寄りで token bucket ではない。自前 50 行で書ける範囲なので外部依存を増やさない。

### D5. User-Agent と `robots.txt` 規律

User-Agent は `app/lib/core/network/user_agent.dart` の `buildUserAgent(version)` で生成:

```
GeekPlayer/<version> (+https://github.com/geekjapan/GeekPlayer; personal-use)
```

`version` は `package_info_plus` から取得。サイト別 `Dio` の `BaseOptions.headers` に注入する。

`robots.txt` は起動時に各 `Site` の `/robots.txt` を 1 回取得し、`robots_txt.dart` のパーサ（最小実装: `User-agent: *` と `Disallow:` のみサポート）で `Map<Site, RobotsRules>` をメモリキャッシュ（TTL 24 時間）。`NovelRepository` の各メソッドは `robots.allows(path)` で事前検査し、Disallow なら `RobotsDisallowedError` を投げる。

**代替案**: `robots.txt` を尊重しない（軽量）
→ ADR-0001 §取得方針-5 違反。やらない。

### D6. 指数バックオフ

`app/lib/core/network/backoff.dart` に `withExponentialBackoff<T>(Future<T> Function() task, {RetryPolicy policy})`。

- 初期 1s、2 倍ずつ、最大 5 分（ADR-0001 §取得方針-6）
- 対象ステータス: 429 / 503（その他は即時失敗）
- `Retry-After` ヘッダがあればそれを優先
- 最大試行 6 回（合計待ち時間 ≒ 5 分）
- Jitter ±20%

サイト別 `Dio` の interceptor で組み込む。`RateLimiter.run` の中でバックオフが回るため、待ち時間中も他リクエストはキューで待機する。

### D7. 同意ダイアログのフロー

初回起動時の Riverpod 初期化で `SiteConsentsDao.findAll()` を読み、3 サイトすべてに `granted=true` の行が無ければ `ConsentDialog` を表示。各サイトを独立にチェックでき、ユーザは少なくとも 1 つチェック（または「すべて拒否」）で閉じる。

- 「すべて拒否」を選んだ場合、`SiteConsents` に 3 行を `granted=false` で挿入し、`NovelHomeSection` に「同意が必要です」プレースホルダを表示
- 設定画面 [`settings_section.dart`](#) で同意の **再表示 / 取り消し** が可能（取り消しは Library エントリは残るが、新規取得・本文同期は停止）
- 「常時表示文言」（ADR-0001 §注意書き-③）は `settings_section.dart` 上部に固定テキストで掲示

`ConsentDialog` を閉じずにアプリを終了した場合は次回起動で再表示（ペンディング扱い）。

### D8. ホーム画面合流

`add-local-video-playback` で導入される [`HomeScreen`](../../../app/lib/features/library/home_screen.dart) は section コンポジット構造になる前提。本 change はそこに `NovelHomeSection` を追加するのみ:

```dart
HomeScreen(sections: [
  VideoHomeSection(),
  NovelHomeSection(),
]);
```

`NovelHomeSection` は:

- Library に登録した Work のカードグリッド（サイトバッジ付き）
- サイト別フィルタチップ（narou / noc / kakuyomu / すべて）
- 空状態: 「Library に小説はまだありません。検索画面から追加してください。」（検索画面はサイト別 change が提供 — 本 change ではボタンを placeholder にして "後続 change で有効化" の disabled 表示）

### D9. `PageSession` は最小 API、`media-session` capability を拡張

Dart 3 の `sealed class` は同一ライブラリ内のサブクラスに限定されるため
(GRILL-REPORT Q-CROSS-011)、`PageSession` は
`app/lib/core/media/page_session.dart` に置き、冒頭に `part of 'media_session.dart';`
を書く。video / audio と同じ物理レイアウト規約に従う。

`MediaSession` sealed hierarchy に追加:

```dart
part of 'media_session.dart';

sealed class PageSession extends MediaSession {
  Stream<PagePosition> get pagePositionStream;
  int get totalPages;
  Future<void> goToPage(int index);
  Future<void> updateScrollFraction(double fraction);
}

class PagePosition {
  final int pageIndex;        // >= 1
  final double scrollFraction;   // 0.0..1.0
  const PagePosition({required this.pageIndex, required this.scrollFraction});
}
```

`MediaSession` 既存 API（`play` / `pause` / `seek` / `setSpeed` / streams）は
no-op またはセマンティクスを再解釈:

- `play` / `pause` → 自動スクロール開始/停止（オーディオブック化の伏線）
- `seek(Duration)` → `UnsupportedError` を投げる（`goToPage` を明示的に使わせる）
- `setSpeed` → 自動スクロール速度

`dispose` 時に現在の `PagePosition` を `novel_bookmarks` テーブルへ upsert する。
scrollFraction (0.0〜1.0) で保存し、pixel offset は使わない（フォント / レイアウト
変更で位置を失わないため）。

これで video / audio との sealed 性は維持され、book / manga が乗る v0.2 の
`PageSession` 拡張に余地を残す。

### D10. HTTP は `dio`、サイト別 instance、interceptor 多段

`Dio` 1 インスタンスを全サイトで共有せず、`Site` ごとに `Dio` を作る:

```dart
Dio buildSiteDio(Site site, RateLimiter limiter, RobotsRules robots) {
  return Dio(BaseOptions(
    baseUrl: site.baseUrl,
    headers: {'User-Agent': buildUserAgent(appVersion)},
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ))
    ..interceptors.addAll([
      RobotsTxtInterceptor(robots),
      RateLimitInterceptor(limiter),
      BackoffInterceptor(),
      LoggingInterceptor(),  // ja-first ログ
    ]);
}
```

- `RateLimitInterceptor` が `Lock`/`semaphore` で並列度を絞り、token bucket で間隔を空ける
- `BackoffInterceptor` が 429/503 を捕捉して `RetryPolicy` で再試行
- order: robots → rate → backoff → logging（外側ほど先に走る）

### D11. テスト戦略

- **ユニット (`RateLimiter`)**: `FakeAsync` で 5 トークン消費 → 次は 2s 待ち、を時間モックで検証
- **ユニット (`BackoffInterceptor`)**: `dio` を `dio_mock` で 429 を 3 連発させ、待機時間 1s/2s/4s（±jitter）を `FakeAsync` で検証
- **ユニット (`RobotsTxtInterceptor`)**: 簡易 `robots.txt` 文字列を与えた時の許可/拒否
- **ユニット (`NovelRepository` モック)**: テスト用 `FakeNovelRepository` で Library 追加フローを検証
- **drift**: in-memory DB で `NovelWorksDao` / `NovelEpisodesDao` / `NovelBookmarksDao` / `SiteConsentsDao` の CRUD、複合主キーの一意性、`addToLibrary` トランザクション挙動
- **ウィジェット (`ConsentDialog`)**: 各サイトのチェック ON/OFF と「すべて拒否」の挙動、`SiteConsents` への正しい書き込み
- **ウィジェット (`NovelHomeSection`)**: 空状態文言、Library にエントリがあるときのカード描画、サイトフィルタ
- **integration (manual)**: 後続のサイト別 change が来るまで自動化不可。本 change は「ライブラリに固定ダミー Work を入れる開発者用 debug menu」で macOS / Windows / Android の DB 動作のみ確認

## Risks / Trade-offs

- **`dio` 依存の導入**: 既存依存 0 のネットワーク領域に `dio` を入れる選択。代替の `http` パッケージは interceptor が貧弱でレート制限の組み込みが冗長。リスクは `dio` のバージョン破壊変更だが、現在 v5 系で安定。pin はメジャーバージョンのみ。
  → Mitigation: `pubspec.yaml` で `dio: ^5.0.0` 程度に絞る。サイト別 change での実利用前に interceptor の API 互換性に変更がないか CI で目視。
- **カクヨム側 HTML 構造変更でパース失敗** (ADR-0001 §Consequences の主リスク): 本 change ではパース実装は持たないが、`NovelRepository.fetchEpisodeBody` の例外型ヒエラルキー（`HtmlParseError` を `NovelRepositoryError` の下に置く）を予約しておかないと、サイト別 change で例外設計が割れる。
  → Mitigation: `core/novel/errors.dart` に `NovelRepositoryError` / `RobotsDisallowedError` / `RateLimitExceededError` / `SiteConsentRequiredError` / `HtmlParseError`（後続用予約）/ `NetworkUnreachableError` を sealed で先に定義する。
- **`robots.txt` パーサの自前実装**: pub の `robots_txt` は更新が停滞気味で、自前実装に倒す。シンプル仕様（`User-agent: *` と `Disallow:` のみ対応）が ADR-0001 を満たす最小集合。
  → Mitigation: 仕様の制限事項を `robots_txt.dart` の docstring と `responsible-fetching` の Requirement Scenario に明記。`Allow:` 行が必要なサイトが出たら拡張する。
- **個人開発者によるリリース署名がないため、Android の `INSTALL_PACKAGES` 系で OS 側検証が緩い**: 同意ダイアログを「公的に検証された署名アプリ」扱いで保護できない。ストアを通さない OSS 配布の構造的問題。
  → Mitigation: 同意ダイアログに「このアプリは GitHub Releases から取得した OSS バイナリです。GitHub 上のチェックサムを確認してください」の文言を入れる（v0.1 では情報提示のみ、v0.2 で `sha256sum` 表示）。
- **`PageSession` の早期固定リスク**: v0.2 の書籍 / 漫画で API が足りないことが分かっても、sealed hierarchy なので追加メソッドは破壊的変更にならない（既存 case は default で no-op できる）が、`PagePosition` のフィールド構成は破壊変更を呼びうる。
  → Mitigation: `PagePosition` を最小フィールド（`pageIndex` / `scrollFraction`）に絞り、書籍系の追加メタは v0.2 で `BookPagePosition extends PagePosition` の継承で拡張する余地を残す。
- **`Site` enum の閉鎖性**: 将来「ハーメルン」「アルファポリス」追加時、`Site` の閉じた enum だと sealed 拡張が走る。が、本 change の `Site` は 3 値の `enum` で十分。
  → Mitigation: 後続で `Site` を拡張する change が出る前提で、`Site` の `String code` 表現を DB に保存（DB は enum 名そのものを持たない）。enum 追加 = DB マイグレーション不要。
- **`drift_dev` の codegen 漏れ**: `add-local-video-playback` と同じく `build_runner` 再生成を忘れると CI が落ちる。
  → Mitigation: tasks.md に build_runner 実行ステップを明示。
- **macOS sandbox の `network.client` entitlement 漏れ**: 入れ忘れると HTTP が全失敗する。
  → Mitigation: tasks にチェック項目、`flutter run -d macos` で curl 確認を 1 step 入れる。

## Migration Plan

- 既存ユーザーなし（新規プロジェクト）
- drift スキーマは `add-local-video-playback` が **v1** で `playback_positions` / `recent_items` を導入済み。本 change は **v1 → v2 の schema bump** を行い、`novel_works` / `novel_episodes` / `novel_bookmarks` / `site_consents` の 4 テーブルを追加する
- `MigrationStrategy.onUpgrade(from: 1, to: 2)` で 4 テーブルを `create` する migration を `app/lib/core/storage/database.dart` に記述
- migration テスト: in-memory v1 DB に `playback_positions` データを書き込んでから v2 にアップグレード → 既存データが消えないこと + 新 4 テーブルが空で作成されることを検証
- 後続 `add-app-settings` change が **v2 → v3** で `app_settings` テーブルを追加する前提（連続マイグレーション）
- 実装順序の制約上、本 change の `database.dart` 編集は `add-local-video-playback` のマージ後を前提
- ロールバック: 本 change を revert すると `NovelHomeSection` がホームから外れ、`novel_*` テーブルは空のまま残る（drop は不要、未参照になるだけ）

## Open Questions

- **Q-D1**: なろう / ノクターン系の API キー（あれば）の保管場所は? → 公式 API は API キー不要のため未対応で OK（後続 narou change で確認、必要なら `flutter_secure_storage` を追加 change で導入）
- **Q-D2**: 「Library に追加」時、`fetchEpisodes` の途中で失敗したらどうする? → 部分保存を残し、再度「Library に追加」で続きから再開する（drift の upsert で冪等）。tasks 段階で冪等性テストを追加。
- **Q-D3**: `policyVersion` の初期値は? → `'2026-05-27'`（ADR-0001 acceptance date）。ADR-0001 が新版になったら値を上げ、同意済みユーザーに「ポリシーが更新されました」モーダルを出す（実装は v0.2、本 change では値の格納のみ）
- **Q-D4**: 同意なしサイトの `NovelHomeSection` カードは表示する? → 表示しない。Library に登録があっても、`SiteConsent.granted == false` のサイト分は「同意が無効化されています — 設定で再同意」のグループ見出しでまとめる（design として決定済み、tasks で具体実装）
- **Q-D5**: `robots.txt` 取得自体が 5xx の時の挙動は? → fail-closed（取得失敗 = Disallow とみなす）。`responsible-fetching` の Scenario に明記。

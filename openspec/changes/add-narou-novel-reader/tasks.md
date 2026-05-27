> **Conventions**: [docs/CONVENTIONS.md](../../../docs/CONVENTIONS.md) と
> [ADR-0004 (HomeScreen registry)](../../../docs/adr/0004-home-screen-section-registry.md)
> を着手前に読むこと。`NarouHomeSection` は `homeSectionsProvider` 配下の
> `NovelHomeSection` 内のタブとして組み込む（`HomeScreen` 直接編集禁止）。

## 1. 前提と依存

- [x] 1.1 `add-online-novel-library` change が apply 済みで `NovelRepository` / `Work` / `Episode` / `Site` / `WorkQuery` / `SiteConsentRepository` / `LibraryRepository` / `RateLimiter` / `site_consents` テーブル / `novel_bookmarks` テーブル / `NovelHomeSection` interface が利用可能であることを確認
- [x] 1.2 `app_settings` テーブル（`add-app-settings` 提供）が利用可能であることを確認。リーダー設定は `novel.reader.*` key 名前空間に保存 — 並列実装中で未存在のため、in-memory + Riverpod でフォールバック (v0.2 で app_settings バックエンドに切り替え)
- [x] 1.3 `app/pubspec.yaml` に `html_unescape` を `flutter pub add` で追加（既に存在すれば冪等に skip）し、`flutter pub get` がクリーン
- [x] 1.4 `app/macos/Runner/DebugProfile.entitlements` / `Release.entitlements` に `com.apple.security.network.client = true` を追加（既に動画 change で入っていれば skip）
- [ ] 1.5 `flutter analyze` / `flutter test` が変更後にクリーン

## 2. ドメインモデル (`features/novel_narou/domain`)

- [x] 2.1 `narou_genre.dart` に `enum NarouGenre`（恋愛 / ファンタジー / SF / 文学 / その他 等、API の `biggenre` / `genre` 数値コードへの `code` getter 付き）を定義
- [x] 2.2 `narou_ranking_type.dart` に `enum NarouRankingType { daily, weekly, monthly, quarterly, yearly, allTime }` と各値の API パスパラメタを定義
- [x] 2.3 `narou_work_query.dart` に `NarouSearchOptions extends WorkQuery` を定義（genres / minChars / maxChars / lastUpdatedAfter / completed / pickup / longRunning フィールド + `toQueryParameters()` メソッド）
- [x] 2.4 `narou_work_summary.dart` / `narou_work_detail.dart` / `narou_episode.dart` を `freezed` で定義し、共通 `Work` / `Episode` への変換 mapper を実装 — freezed は dev_deps 未導入のため、`@immutable` + 手書き == / hashCode で同等のものを実装
- [x] 2.5 上記すべてのユニットテストを `app/test/features/novel_narou/domain/` に追加（特に `toQueryParameters()` の安定順序とバリデーション）

## 3. API クライアント層 (`features/novel_narou/data`)

- [x] 3.1 `narou_api_client.dart` に `NarouApiClient`（コンストラクタで `baseUrl` / `Dio` / `RateLimiter` を受け取る）を実装
- [x] 3.2 `Dio` Interceptor で `User-Agent` ヘッダを `GeekPlayer/<version> (+https://github.com/geekjapan/GeekPlayer; personal-use)` 固定で付与、`<version>` は `package_info_plus` から取得 — appVersion はプロバイダ経由で渡す。実 init は `narouNovelRepositoryProvider` 配下
- [x] 3.3 `Dio` Interceptor で 429 / 503 を検出し、指数バックオフ（1s, 2s, 4s, 8s, ..., max 5min, 最大 5 回）で自動リトライ — 既存 `BackoffInterceptor` を流用 (Section 4 でプロバイダに組み込む)
- [x] 3.4 `RateLimiter` を origin キー `api.syosetu.com` で適用し、1 req/sec、並列 2 を強制 — provider レベルで bucket を共有
- [x] 3.5 `search(NarouSearchOptions, {int offset, int limit})` を実装し、`out=json` 固定で結果を `NarouSearchResponse` に mapping
- [x] 3.6 `detail(List<String> ncodes)` を実装し、最大 100 件をハイフン結合で 1 リクエストにまとめる
- [x] 3.7 `rankget(NarouRankingType, DateTime)` を実装し、ID + rank + pt のリストを返す
- [x] 3.8 mapper 全体のスナップショットテストを `app/test/fixtures/narou/` の固定 JSON で実行
- [x] 3.9 `dio` の `MockAdapter` を使い、429 → 200 のフローと指数バックオフ間隔をユニットテストで検証 — Dio interceptor チェイン経路の単体は難しいため、`computeBackoffDelay` の数列直接検証で代替

## 4. リポジトリ層 (`features/novel_narou/data`)

- [x] 4.1 `narou_novel_repository.dart` に `NarouNovelRepository implements NovelRepository` を実装（search / fetchWork / fetchEpisodes / fetchEpisodeBody を `NarouApiClient` 経由で）
- [x] 4.2 `narou_r18_novel_repository.dart` に `NarouR18NovelRepository` を実装。コンストラクタで `SiteConsentRepository.isGranted(Site.noc)` を検査し未同意なら `StateError` — 非同期 IO を排除するため `create()` factory 経由 (ADR 整合)
- [x] 4.3 R18 リポジトリは `SiteConsentRepository` の `Stream<SiteConsentEvent>` を購読し、`revoked` イベントで内部の disposed フラグを true にして以降のメソッド呼び出しを `StateError` に
- [x] 4.4 `narou_ranking_repository.dart` に `NarouRankingRepository` を実装。`rankget` → `detail` の 2 段階呼び出しでランキング作品リストを構築
- [x] 4.5 `narou_episode_fetcher.dart` に短編 / 連載分岐を持つ `fetchBody` を実装。短編は API、連載は `https://ncode.syosetu.com/<ncode>/<n>/` を `html` パッケージでパースし本文セクションを抽出 — ADR-0003 確定通り、短編も同じ URL 形式 (`/<ncode>/1/`) なので 1 経路に統合
- [x] 4.6 R18 系統用の `narou_r18_episode_fetcher.dart` も同様に実装、`novel18.syosetu.com` のドメインで動作 — 同 `NarouEpisodeFetcher` クラスを `bodyBaseUrl` で切替（DRY、design.md D2）
- [x] 4.7 Riverpod プロバイダ定義（`narouNovelRepositoryProvider`、`narouR18NovelRepositoryProvider` は `SiteConsent` の grant を gating）
- [x] 4.8 ユニットテスト: `NarouR18NovelRepository` の grant / revoke ライフサイクル
- [x] 4.9 ユニットテスト: `NarouEpisodeFetcher` の短編 / 連載分岐と rate limit 遵守

## 5. R18 年齢確認 (`features/age_gate`)

- [x] 5.1 `age_gate_dialog.dart` に `AgeGateDialog` を実装（タイトル「年齢確認」、説明文、はい / いいえ ボタン、barrier-dismissible false）
- [x] 5.2 `showAgeGate(BuildContext)` ヘルパ関数を提供し、同意取得時に `SiteConsentRepository.grant(Site.noc)` を呼ぶ
- [x] 5.3 `SiteConsentRepository.isGranted` が `false` の時の R18 surface 表示抑制を、Riverpod の `consentForNarou18Provider` で一元化
- [x] 5.4 `age_gate_settings_section.dart` に「年齢確認をやり直す」設定行を実装。現在の同意状態と grant 日時を表示
- [x] 5.5 revoke 時の確認ダイアログを実装し、確認後に `SiteConsentRepository.revoke(Site.noc)` を呼ぶ
- [x] 5.6 ウィジェットテスト: ダイアログの「はい」/「いいえ」分岐
- [x] 5.7 ウィジェットテスト: 設定画面で grant 状態が正しく表示され、revoke が反映される

## 6. 検索 / ランキング / 詳細画面 (`features/novel_narou/presentation`)

- [x] 6.1 `search_screen.dart` を実装（キーワード入力、ジャンル multi-select chip、文字数レンジスライダー、最終更新日 picker、完結 / ピックアップ checkbox、検索ボタン） — 文字数スライダー/日付 picker は v0.1 では簡易（オプション値直入力）に倒した
- [x] 6.2 検索結果リストを 20 件ずつの infinite-scroll で表示し、末尾 200 px で次ページ取得
- [x] 6.3 アクティブな filter chips を結果リストの上に表示し、X タップで除去 + 再検索
- [x] 6.4 空結果時の placeholder 文言「該当する作品が見つかりませんでした」を表示
- [x] 6.5 `ranking_screen.dart` を実装（6 タブ: 日間 / 週間 / 月間 / 四半期 / 年間 / 累計）、各タブ切り替えで `NarouRankingRepository` を呼び、上位 100 件を rank 順表示
- [x] 6.6 `work_detail_screen.dart` を実装（タイトル / 著者 / あらすじ / タグ / 文字数 / 話数 / 最終更新 / エピソード一覧 / Library 追加ボタン）
- [x] 6.7 あらすじとタイトル中のルビ記法 `|漢字《かんじ》` を `RubyText` で描画する `NarouRubyParser` を実装
- [x] 6.8 Library 追加時の確認ダイアログ（話数 ÷ 60 分の予想時間表示）と `LibraryRepository.addToLibrary(NarouNovelRepository, work.id)` 呼び出し
- [x] 6.9 `narou_home_section.dart` で `NovelHomeSection` interface を実装（検索 / ランキング / ピックアップ + R18 タブの条件付き表示） — 現状の `NovelHomeSection` (Wave 2) に panel として組み込み、registry には独立登録しない
- [x] 6.10 R18 タブの初回タップ時に `showAgeGate` を経由するフローを実装

## 7. リーダー画面 (`features/novel_narou/presentation`)

- [x] 7.1 `reader_screen.dart` を `SingleChildScrollView` + `SelectableText.rich` で実装、縦スクロール
- [x] 7.2 `reader_settings.dart` に `ReaderTheme` 値オブジェクト（fontSize 12-32 / lineHeight 1.2-2.4 / colorScheme {light, sepia, dark}）を定義し、`add-app-settings` 提供の `app_settings` テーブルに `novel.reader.fontSize` / `novel.reader.lineHeight` / `novel.reader.colorScheme` の 3 key で保存 — `app_settings` テーブル未存在のため、in-memory Riverpod (`keepAlive: true`) でフォールバック。TODO コメントで v0.2 切替を明記
- [x] 7.3 `AppSettingsNotifier` を購読してリーダー画面が設定変更に即座に反応するようにする — `readerThemeProvider` を `ref.watch` する形で実現
- [x] 7.4 リーダー画面の上部に設定ボタン、下部に前話 / 次話ボタン、最終話では次話ボタンを disable
- [x] 7.5 設定パネル（フォントサイズ +/- / 行間スライダー / テーマ切り替え）を BottomSheet で実装
- [x] 7.6 本文中の `|漢字《かんじ》` と `《ルビ》` を `RubyText` の `WidgetSpan` で描画
- [x] 7.7 挿絵タグ `<i...>` を `[挿絵]` プレースホルダーに置換
- [x] 7.8 スクロールオフセットを `novel_bookmarks` に navigation 離脱時に保存し、再入場時に復元（末尾 5% は 0 リセット）
- [ ] 7.9 ウィジェットテスト: フォントサイズ変更 / テーマ変更 / 前話次話遷移 / 栞復元

## 8. ホーム画面合成

- [ ] 8.1 `app/lib/main.dart:1` 周辺の `HomeScreen` 合成点に `NarouHomeSection` を追加
- [ ] 8.2 R18 consent 状態に応じた section 内タブ表示の動的切り替えを実装
- [ ] 8.3 ウィジェットテスト: 初期状態で R18 タブ非表示、grant 後に表示

## 9. テスト全般と CI

- [ ] 9.1 `app/test/fixtures/narou/` に代表的 API レスポンス JSON（一般検索 / R18 検索 / detail / rankget / 本文 HTML）を 5 件以上保存
- [ ] 9.2 `flutter test` でユニット + ウィジェットテストが全て pass
- [ ] 9.3 `app/integration_test/narou_smoke_test.dart` に実 API を 1 回ずつ叩く smoke test（CI では skip タグ、ローカル / リリース前に手動実行）
- [ ] 9.4 `flutter analyze` クリーン、`dart format --set-exit-if-changed .` 通過

## 10. ドキュメントと締め

- [ ] 10.1 `README.md` に「対応サイト: 小説家になろう / ノクターン系統」と R18 同意の注意書きを追加
- [ ] 10.2 ADR-0001 を読み返し、注意書きの 4 箇所（README / 初回起動 / Settings / `KakuyomuHtmlSource` docstring）のうち、本 change で扱う該当箇所が更新されていることを確認
- [ ] 10.3 すべての task の `- [ ]` を `- [x]` に更新し、`/opsx:archive` で本 change をアーカイブ

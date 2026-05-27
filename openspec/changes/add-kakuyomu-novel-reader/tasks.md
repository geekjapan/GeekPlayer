> **Conventions**: [docs/CONVENTIONS.md](../../../docs/CONVENTIONS.md) と
> [ADR-0004 (HomeScreen registry)](../../../docs/adr/0004-home-screen-section-registry.md)
> を着手前に読むこと。`KakuyomuSection` は `homeSectionsProvider` 配下の
> `NovelHomeSection` 内のタブとして組み込む（`HomeScreen` 直接編集禁止）。

## 1. 依存と前提

- [x] 1.1 `add-online-novel-library` で `NovelRepository` / `LibraryRepository` / `RateLimiter` / `SiteConsentRepository` / `Site` enum / `Work` / `Episode` / drift `novel_works` / `novel_episodes` / `novel_bookmarks` / `site_consents` テーブルが定義されていることを確認
- [x] 1.2 `app/pubspec.yaml` に `url_launcher` を `flutter pub add` で追加（冪等: 既に存在すれば skip）。`webfeed_revised` / `html` / `dio` / `package_info_plus` は共通 change で導入済み前提
- [x] 1.3 `flutter pub get` がクリーンで通り、`flutter analyze` が green
- [x] 1.4 `THIRD_PARTY_NOTICES.md` に `webfeed_revised` / `html` / `url_launcher` / `package_info_plus` のライセンス記載を追加
- [x] 1.5 `app/lib/core/config/feature_flags.dart` に `const bool kakuyomuEnabled = true;` を追加（kill-switch）

## 2. ドメインモデルと例外

- [x] 2.1 `app/lib/features/novel/kakuyomu/domain/kakuyomu_work.dart` に `KakuyomuWorkDetail`（id / title / author / synopsis / tags / episodes / lastUpdatedAt）を `freezed` で定義 — placed under `features/novel_kakuyomu/domain/`; plain `@immutable` (no freezed in pubspec, follows existing core/novel models convention)
- [x] 2.2 `kakuyomu_episode.dart` に `KakuyomuEpisodeSummary`（id / title / publishedAt）と `KakuyomuEpisodeBody`（id / paragraphs: List<ReaderSegment>）を定義 — also added sealed `ReaderSegment` (Paragraph/Blank/RubyParagraph) in `reader_segment.dart`
- [x] 2.3 `kakuyomu_feed_item.dart` に `KakuyomuFeedItem`（title / workId / url / author / publishedAt / summary）を定義
- [x] 2.4 `kakuyomu_search_query.dart` に `KakuyomuSearchQuery`（keyword / genre? / sort?）を定義
- [x] 2.5 `domain/exceptions.dart` に `SiteConsentDeniedException` / `KakuyomuParseException` / `KakuyomuEpisodeNotFoundException` / `KakuyomuUpstreamUnavailableException` / `RobotsDisallowedException` を実装 — `SiteConsentDeniedException` / `RobotsDisallowedException` are typedef aliases of the cross-site sealed types in `core/{novel,network}/errors.dart`
- [x] 2.6 ドメインモデルの freezed / json codegen を `dart run build_runner build --delete-conflicting-outputs` で生成 — N/A (no freezed); plain `toJson` methods are hand-written

## 3. HTTP / レート制限 / robots.txt インフラ

- [ ] 3.1 `data/kakuyomu_dio_factory.dart` を実装: `Dio` インスタンスを生成し、`BaseOptions.headers['User-Agent']` を `GeekPlayer/<version> (+https://github.com/geekjapan/GeekPlayer; personal-use)` 形式で設定（`package_info_plus` 経由）
- [ ] 3.2 共通 `RateLimiter` を `RateLimiter(rate: 0.5, burst: 1, maxConcurrency: 1)`（0.5 req/sec = 2 秒に 1 回）で構築する Riverpod プロバイダを実装
- [ ] 3.3 Dio `InterceptorsWrapper` を実装: `onRequest` で `limiter.run(() async { ... })` でラップ、`onError` で 429/503 を捕捉して指数バックオフ（初期 1s / ×2 / 上限 5min / `Retry-After` 優先 / 最大 6 リトライ）でリトライし、6 回失敗で `KakuyomuUpstreamUnavailableException` に変換
- [ ] 3.4 `data/kakuyomu_robots_txt_cache.dart` を実装: 初回 fetch / 24 時間メモリキャッシュ / disallow 評価 / 取得失敗時の許可リストフォールバック（`/works/`, `/works/.+/episodes/`, RSS endpoints）
- [ ] 3.5 Dio Interceptor に robots 評価を組み込み、disallow パスへの送信前に `RobotsDisallowedException` を投げる
- [ ] 3.6 ユニットテスト: User-Agent 正規表現、2 秒間隔、並列度 1、429/503 バックオフ、`Retry-After` 優先、robots disallow 拒否、robots fetch 失敗時の許可リスト動作

## 4. RSS / Atom ソース

- [ ] 4.1 `data/kakuyomu_rss_source.dart` を実装: `search(query)` / `latest()` / `ranking(period)` / `workUpdates(workId)` のメソッド、`Content-Type` で RSS / Atom 振り分け、`webfeed_revised` でパース
- [ ] 4.2 `KakuyomuFeedItem` への正規化ロジック（`item.link` から `workId` を URL パスから抽出）を実装
- [ ] 4.3 アイテム単位 try-catch でベストエフォート（壊れたアイテムは skip + warn）
- [ ] 4.4 fixture `app/test/fixtures/kakuyomu/rss/latest.xml` / `ranking_daily.xml` / `ranking_weekly.xml` を実環境から月 1 回手動取得して保存
- [ ] 4.5 ゴールデン JSON `*.golden.json` を初回生成し、CI 比較テストを `app/test/features/novel/kakuyomu/kakuyomu_rss_source_test.dart` に実装
- [ ] 4.6 1 アイテム破損で全体が落ちないことのテストを追加

## 5. HTML ソースとパーサ

- [ ] 5.1 `data/kakuyomu_html_parser.dart` を実装: `parseWorkPage(html)` と `parseEpisodePage(html)`。CSS セレクタはファイル先頭に `const` で集約
- [ ] 5.2 ルビ（`<ruby>` / `<rt>`）、段落、空行を `ReaderSegment` 列に正規化するロジックを実装
- [ ] 5.3 `data/kakuyomu_html_source.dart` を実装: `fetchWork(workId)` / `fetchEpisodeBody(workId, episodeId)`、404 を `KakuyomuEpisodeNotFoundException` にマップ、パース失敗を `KakuyomuParseException` に
- [ ] 5.4 `KakuyomuHtmlSource` のクラス docstring に ADR-0001 の注意書き（「個人利用」「能動キャッシュ」「1 リクエスト / 2 秒」「robots.txt」「429」「503」「ADR-0001」全部含む）を書き、ADR-0001 への相対リンクを記載
- [ ] 5.5 fixture `app/test/fixtures/kakuyomu/html/work_001.html` 〜 `work_005.html`、`episode_001.html` 〜 `episode_005.html` を実環境から月 1 回手動取得して保存（ジャンル / 本文長 / ルビ有無で分散）
- [ ] 5.6 ゴールデン JSON `*.golden.json` を初回生成し、CI 比較テストを `kakuyomu_html_parser_test.dart` に実装
- [ ] 5.7 `app/test/fixtures/kakuyomu/README.md` に月 1 回更新手順、レート制限を尊重する手動取得の注意、golden 再生成手順を記載（30 行以上、「月 1 回」「robots.txt」「golden」を含む）

## 6. Repository と同意連携

- [ ] 6.1 `data/kakuyomu_novel_repository.dart` に `KakuyomuNovelRepository implements NovelRepository` を実装し、`search` / `latest` / `ranking` / `fetchWork` / `fetchEpisodes` / `fetchEpisodeBody` を提供。Library 追加は共通の `LibraryRepository.addToLibrary(KakuyomuNovelRepository, workId)` で呼び出される（このリポジトリ自体に `addToLibrary` メソッドは持たない）
- [ ] 6.2 各メソッドの先頭で `SiteConsentRepository.isGranted(Site.kakuyomu)` を確認し、未同意なら `SiteConsentDeniedException` を投げる（HTTP は飛ばさない）
- [ ] 6.3 `LibraryRepository.addToLibrary` から呼ばれる `fetchEpisodes` / `fetchEpisodeBody` が、本文取得を順次行えること（レート制限・キャンセル可能）を保証。永続化は共通 `LibraryRepository` 側の責務
- [ ] 6.4 `CancelToken` 連携でフェッチ中断対応
- [ ] 6.5 同意取り消し時の本文キャッシュ削除は共通 `LibraryRepository.purgeBySite(Site.kakuyomu)` を呼ぶ
- [ ] 6.6 リポジトリ単体テスト: 同意なし → 全メソッドが HTTP を飛ばさず例外、能動キャッシュ（reader 開きはキャッシュしない / library add のみキャッシュ）

## 7. 同意ダイアログと設定画面

- [ ] 7.1 `presentation/kakuyomu_consent_dialog.dart` を実装: 「個人利用に限定」「能動キャッシュのみ」「robots.txt 尊重」を箇条書き、ADR-0001 / README / カクヨム公式 ToS へのリンク、「同意する」「同意しない」を同等視認性
- [ ] 7.2 ダイアログを「カクヨムセクション初回タップ」「設定画面の OFF→ON トグル」から呼び出す統合
- [ ] 7.3 設定画面のカクヨムセクション（`add-online-novel-library` の settings に挿入）に同意トグル / 注意書き / レート制限現状値「1 リクエスト / 2 秒、並列度 1」 / README リンクを実装
- [ ] 7.4 OFF トグル時の確認ダイアログ → `LibraryRepository.purgeBySite(Site.kakuyomu)` 呼び出し → トグル反映
- [ ] 7.5 文言レビュー: ダークパターンになっていないか、ADR-0001 の 4 箇所注意のうち「ダイアログ」「設定画面」の文言が ADR-0001 と齟齬なく一致するかを目視レビュー task として明示

## 8. UI 画面

- [ ] 8.1 `presentation/search_screen.dart`: クエリ入力 → `repository.search` → カードリスト + 空状態「結果が見つかりませんでした」 + エラー時「再試行」CTA
- [ ] 8.2 `presentation/latest_feed_screen.dart`: 新着 RSS を時系列表示、pull-to-refresh、レートリミッタ経由で多重リフレッシュを coalesce
- [ ] 8.3 `presentation/ranking_screen.dart`: 日次 / 週次 / 月次 / 累計 4 タブ、タブ毎にセッション内メモリキャッシュ
- [ ] 8.4 `presentation/work_detail_screen.dart`: 概要 / タグ / エピソードリスト / 「Library に追加」ボタン、追加中はプログレスとキャンセル
- [ ] 8.5 `presentation/reader_screen.dart`: 本文表示（段落 / 空行 / `<ruby>`）、`ResumePoint` 復元と保存（共通 change 側のテーブル経由）、前後エピソードナビ
- [ ] 8.6 `presentation/parser_failure_fallback.dart`: パース失敗時に reader screen に差し込まれる fallback panel、「公式ビューアで開く」（`url_launcher` で OS デフォルトブラウザ）と「詳細をコピー」（失敗セレクタ / URL / app version / OS 名のみ）
- [ ] 8.7 `presentation/kakuyomu_section.dart`: ホーム画面に組み込まれる入口。`kakuyomuEnabled == false` か未同意なら非表示
- [ ] 8.8 deep link で Kakuyomu 画面に直接来た場合の未同意フォールバック画面を実装
- [ ] 8.9 同意 revoke 時の即時 UI 撤去（Riverpod 監視 + Navigator pop）と in-flight CancelToken 起動

## 9. テスト

- [ ] 9.1 robots.txt キャッシュ: 1 時間 TTL、許可リストフォールバック、disallow 拒否のユニットテスト
- [ ] 9.2 Dio Interceptor: User-Agent、2 秒間隔、429/503 指数バックオフ、`Retry-After` 優先、3 回で諦め、のユニットテスト
- [ ] 9.3 RSS スナップショット: latest / daily / weekly fixture と golden 一致
- [ ] 9.4 HTML スナップショット: 5 work + 5 episode fixture と golden 一致、diff メッセージにセレクタパス
- [ ] 9.5 Repository: 同意なしショートサーキット、能動キャッシュのみ（reader 開きで書き込まないこと）、library add で全話キャッシュ、キャンセル
- [ ] 9.6 同意ダイアログ widget test: 「同意しない」選択 → 設定状態反映、ホーム画面で Kakuyomu 非表示
- [ ] 9.7 各 UI 画面 widget test: 空状態 / 読み込み中 / エラー / 同意なし状態
- [ ] 9.8 fallback panel widget test: 「公式ビューアで開く」タップで `url_launcher` 呼び出し、「詳細をコピー」のクリップボード文字列に device id / IP / HTML body が含まれないこと
- [ ] 9.9 kill-switch test: `kakuyomuEnabled = false` で UI 非表示 / Repository 未登録 / 起動時パージ確認ダイアログ
- [ ] 9.10 integration test (mock source): 同意 → 検索 → 作品詳細 → リーダー → 「次へ」 → 同意 OFF → UI 撤去の通し動作

## 10. ドキュメントと締め

- [ ] 10.1 README.md の「カクヨム機能の注意事項」セクションが ADR-0001 とこの change の実装と齟齬ないか確認、必要なら同期
- [ ] 10.2 `KakuyomuHtmlSource` docstring と同意ダイアログ文言と設定画面文言の 3 箇所が ADR-0001 と一字一句以上の趣旨で一致しているか目視チェック（README と合わせて 4 箇所）
- [ ] 10.3 `flutter analyze` / `flutter test` / `dart format --set-exit-if-changed .` がローカルと CI で green
- [ ] 10.4 手動 smoke: macOS / Windows / Android で同意 → 検索 → 作品詳細 → リーダー → Library 追加 → 同意 OFF パージの一連を実機確認
- [ ] 10.5 全 task の `- [ ]` を `- [x]` に更新し、`/opsx:archive add-kakuyomu-novel-reader` で本 change をアーカイブ

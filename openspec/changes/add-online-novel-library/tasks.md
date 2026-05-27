> **Conventions**: [docs/CONVENTIONS.md](../../../docs/CONVENTIONS.md) と
> [ADR-0004 (HomeScreen registry)](../../../docs/adr/0004-home-screen-section-registry.md)
> を着手前に読むこと。`NovelHomeSection` は `homeSectionsProvider` にサブプロバイダ
> として登録する（`HomeScreen` 直接編集禁止）。

## 1. 依存とプラットフォーム設定

- [x] 1.1 `app/pubspec.yaml` に `dio`、`package_info_plus`、`html`、`xml`、`collection` を `flutter pub add` で **冪等に**追加（既に存在すれば skip。CONVENTIONS.md §2 参照）し、`flutter pub get` がクリーン
- [x] 1.2 `app/android/app/src/main/AndroidManifest.xml` に `<uses-permission android:name="android.permission.INTERNET"/>` を追加（既存ならスキップ）
- [x] 1.3 `app/macos/Runner/DebugProfile.entitlements` と `Release.entitlements` に `com.apple.security.network.client = true` を追加
- [x] 1.4 `flutter analyze` と `flutter test` が依存変更後にクリーン

## 2. ネットワーク基盤 (`core/network`)

- [ ] 2.1 `app/lib/core/network/user_agent.dart` に `buildUserAgent(String version)` を実装し、ADR-0001 §取得方針-4 のフォーマットを返す
- [ ] 2.2 `app/lib/core/network/rate_limiter.dart` に token-bucket 実装（`rate`, `burst`, `maxConcurrency`, `Future<T> run<T>(Future<T> Function() task)`）
- [ ] 2.3 `app/lib/core/network/backoff.dart` に `RetryPolicy`（初期 1s、2 倍、最大 5min、最大 6 回、±20% jitter、`Retry-After` 優先）と `withExponentialBackoff<T>` を実装
- [ ] 2.4 `app/lib/core/network/robots_txt.dart` に `RobotsRules`（`User-agent: *` と `Disallow:` のみサポート）と `Allows(path) -> bool` を実装。docstring に仕様制限を明記
- [ ] 2.5 `app/lib/core/network/errors.dart` に sealed `NetworkError` ヒエラルキー（`RobotsDisallowedError`, `RateLimitExceededError`, `NetworkUnreachableError`）を定義
- [ ] 2.6 `app/lib/core/network/interceptors/{robots_txt_interceptor.dart, rate_limit_interceptor.dart, backoff_interceptor.dart, logging_interceptor.dart}` を実装し、`buildSiteDio(Site, RateLimiter, RobotsRules)` で 4 段の interceptor を装着
- [ ] 2.7 `app/test/core/network/rate_limiter_test.dart` で `FakeAsync` を使い、kakuyomu プロファイル（0.5/1/1）の 2 タスク間隔が 2s であること、narou プロファイル（1.0/5/4）の maxConcurrency が 4 であることを検証
- [ ] 2.8 `app/test/core/network/backoff_test.dart` で 429 を 3 連発 → 4 回目で 200 を返すモックに対し、待ち時間が 1s/2s/4s（±jitter 20%）であること、`Retry-After: 30` 時に exactly 30s 待つことを検証
- [ ] 2.9 `app/test/core/network/robots_txt_test.dart` で `User-agent: *\nDisallow: /private/` のパースと `allows('/public/page') == true`、`allows('/private/page') == false` を検証

## 3. ドメインモデル (`core/novel/models`)

- [ ] 3.1 `app/lib/core/novel/models/site.dart` に `enum Site { narou, noc, kakuyomu }` と `String get code` / `Uri get baseUrl` を実装
- [ ] 3.2 `app/lib/core/novel/models/work_id.dart` に `WorkId({required Site site, required String externalId})` を `@immutable` + `operator ==` / `hashCode` 込みで実装
- [ ] 3.3 `app/lib/core/novel/models/work.dart` に `Work`（`id`, `title`, `author`, `synopsis?`, `episodeCount`, `addedAt`, `lastSyncedAt?`）を実装
- [ ] 3.4 `app/lib/core/novel/models/episode.dart` に `EpisodeId(int index)` と `Episode(id, title)`、`EpisodeBody(String body, DateTime fetchedAt)` を実装
- [ ] 3.5 `app/lib/core/novel/errors.dart` に sealed `NovelRepositoryError` を定義し、`SiteConsentRequiredError`, `HtmlParseError`（予約）, `WorkNotFoundError`, `EpisodeNotFoundError` を含める
- [ ] 3.6 `app/test/core/novel/models_test.dart` で `WorkId` の構造的等価、`Site` の exhaustive switch、`Episode` の不変性を検証

## 4. NovelRepository interface

- [ ] 4.1 `app/lib/core/novel/novel_repository.dart` に `abstract interface class NovelRepository` を定義（`site`, `fetchWork`, `fetchEpisodes (Stream<Episode>)`, `fetchEpisodeBody`）
- [ ] 4.2 `app/lib/core/novel/fake_novel_repository.dart` にテスト用 `FakeNovelRepository`（in-memory map ベース、人工遅延注入可）を実装
- [ ] 4.3 `app/test/core/novel/fake_novel_repository_test.dart` で `fetchEpisodes` が `Stream` で逐次返ること、`fetchEpisodeBody` が永続化しないこと（drift を触らない）を検証

## 5. drift スキーマ拡張

- [x] 5.1 `app/lib/core/storage/tables/novel_works.dart` に `NovelWorks` テーブル（複合主キー `{site, externalId}`）を定義
- [x] 5.2 `app/lib/core/storage/tables/novel_episodes.dart` に `NovelEpisodes` テーブル（複合主キー `{site, externalId, episodeIndex}`）を定義
- [x] 5.3 `app/lib/core/storage/tables/novel_bookmarks.dart` に `NovelBookmarks` テーブル（複合主キー `{site, externalId}`、`scrollFraction REAL`）を定義
- [x] 5.4 `app/lib/core/storage/tables/site_consents.dart` に `SiteConsents` テーブル（主キー `site`、`granted BOOL`, `policyVersion TEXT`）を定義
- [x] 5.5 `app/lib/core/storage/database.dart` の `@DriftDatabase(tables: [...])` に 4 テーブルを追加し、`add-local-video-playback` のスキーマ v1 を維持
- [x] 5.6 `flutter pub run build_runner build --delete-conflicting-outputs` を実行し `database.g.dart` を再生成、コミット
- [x] 5.7 `NovelWorksDao` / `NovelEpisodesDao` / `NovelBookmarksDao` / `SiteConsentsDao` を実装（upsert / get / list / delete、Work 削除時の cascade トランザクション）
- [x] 5.8 `app/test/core/storage/novel_dao_test.dart` を in-memory drift で書き、複合主キーの一意性、Work cascade 削除、idempotent upsert を検証 (+ migration v1->v2 test)
- [x] 5.9 `SiteConsentsDao` の `policyVersion` 比較ヘルパ（`hasFreshConsent(Site, currentVersion) -> bool`）と単体テスト

## 6. PageSession と media-session 拡張

GRILL-REPORT Q-CROSS-011 に従い、Dart 3 の sealed-class 制約のため
`page_session.dart` は `core/media/` に置き `part of 'media_session.dart';` で結合する。

- [x] 6.1 `app/lib/core/media/page_position.dart` に `PagePosition({required int pageIndex, required double scrollFraction})` を実装し、`pageIndex >= 1` / `0.0 <= scrollFraction <= 1.0` バリデーション
- [x] 6.2 `app/lib/core/media/page_session.dart` の冒頭に `part of 'media_session.dart';` を書き、`sealed abstract class PageSession extends MediaSession`（`pagePositionStream`, `totalPages`, `goToPage`, `updateScrollFraction`、`seek` で `UnsupportedError`）を実装
- [x] 6.3 [`app/lib/core/media/media_session.dart`](../../../app/lib/core/media/media_session.dart) に `part 'page_session.dart';` 行を追加し、sealed hierarchy に `PageSession` を含めることをコメントで明示
- [x] 6.4 `NovelPageSession`（drift `NovelBookmarks` と `NovelEpisodesDao` を裏で叩く実装）を `app/lib/features/novel/data/novel_page_session.dart` に実装、dispose 時に `novel_bookmarks` へ upsert
- [x] 6.5 `app/test/core/media/page_position_test.dart` でバリデーションと等価性を検証
- [x] 6.6 `app/test/features/novel/novel_page_session_test.dart` で `goToPage` / `updateScrollFraction` のストリーム遷移、`seek` の `UnsupportedError`、dispose 時の `novel_bookmarks` upsert を検証
- [x] 6.7 既存の `app/test/core/media/` テスト群が `MediaSession` の sealed exhaustivity 拡張で壊れないことを確認（必要なら `PageSession` ケースを追加）

## 7. SiteConsent 機能 (`features/novel/consent`)

- [x] 7.1 `app/lib/features/novel/data/consent_repository.dart` に `ConsentRepository`（`SiteConsentsDao` ラッパー、`hasFreshConsent(Site)`, `grant(Site)`, `revoke(Site)`, `getAll()`）を実装
- [x] 7.2 `app/lib/features/novel/presentation/consent_dialog.dart` に `ConsentDialog` ウィジェットを実装（3 サイトのチェックボックス、「決定」「すべて拒否」、外側タップで閉じない）
- [x] 7.3 `app/lib/features/novel/presentation/settings_section.dart` に `NovelSettingsSection` を実装（ADR-0001 §注意書き-③ の常時表示文言、各サイトの consent トグル）
- [x] 7.4 起動フックを `app/lib/main.dart` に追加：Riverpod 初期化で `hasFreshConsent` を全サイト確認し、無ければ `ConsentDialog` を `WidgetsBinding.instance.addPostFrameCallback` でモーダル表示
- [x] 7.5 `policyVersion = '2026-05-27'` を `app/lib/core/novel/policy_version.dart` に定義
- [ ] 7.6 `app/test/features/novel/consent_dialog_test.dart` でチェック ON/OFF、「すべて拒否」の DB 書き込み、外側タップで閉じないことを検証
- [ ] 7.7 `app/test/features/novel/consent_enforcement_test.dart` で `ConsentRepository` が `granted=false` の時に対応する `NovelRepository` 呼び出しが `SiteConsentRequiredError` を投げることを検証（`FakeNovelRepository` を `ConsentGuardedRepository` でラップして検証）

## 8. Library 機能 (`features/novel/library`)

- [ ] 8.1 `app/lib/features/novel/data/library_repository.dart` に `LibraryRepository`（`addToLibrary(NovelRepository, WorkId)`, `removeFromLibrary(WorkId)`, `listLibrary()`, `getBookmark(WorkId)`, `saveBookmark(WorkId, PagePosition)`）を実装
- [ ] 8.2 `addToLibrary` の冪等性: 既存 `novel_episodes` 行は再フェッチせず、欠けている `episodeIndex` のみ `fetchEpisodeBody` を呼ぶ
- [ ] 8.3 `addToLibrary` の途中失敗時、成功分は残し、再実行で続きから再開できることをトランザクション境界で保証
- [ ] 8.4 `app/lib/features/novel/domain/{add_to_library_use_case.dart, remove_from_library_use_case.dart, list_library_use_case.dart}` を実装し、Riverpod provider に登録
- [ ] 8.5 `app/lib/features/novel/data/consent_guarded_repository.dart` に `NovelRepository` を decorate するクラスを実装：全メソッドの先頭で `ConsentRepository.hasFreshConsent(site)` を確認、不可なら同期的に `SiteConsentRequiredError` を投げる
- [ ] 8.6 `app/test/features/novel/library_repository_test.dart` で `FakeNovelRepository` + in-memory drift を組み合わせ、能動キャッシュ（閲覧では書かない / 追加で書く）、再開、cascade 削除、消費同意（granted=false で `SiteConsentRequiredError`）を検証
- [ ] 8.7 `app/test/features/novel/add_to_library_partial_resume_test.dart` で 10 話中 4 話成功 → 5 話目失敗 → 再実行で 5..10 話だけ取りに行くことを検証

## 9. ホーム画面と UI 統合

- [ ] 9.1 `app/lib/features/novel/presentation/home_section.dart` に `NovelHomeSection`（Library カードグリッド、サイトバッジ、空状態 placeholder、disabled な「検索画面を開く」ボタン）を実装
- [ ] 9.2 サイト別フィルタチップ（narou / noc / kakuyomu / すべて）と Riverpod state（`Provider<Site?>`）を実装
- [ ] 9.3 同意なしサイトのグループ見出し「同意が無効化されています — 設定で再同意」を実装し、該当グループの Work カードは disabled 表示
- [ ] 9.4 `app/lib/main.dart` の `HomeScreen` セクション配列に `NovelHomeSection` を追加（`add-local-video-playback` の `VideoHomeSection` の隣）
- [ ] 9.5 設定画面（仮の画面ルート、本 change ではホームから遷移できる最小実装）に `NovelSettingsSection` を組み込む
- [ ] 9.6 `app/test/features/novel/home_section_test.dart` で空状態、Library エントリ表示、フィルタチップ、disabled 表示（granted=false 時）を widget test
- [ ] 9.7 「Library に追加」を試す開発者向け debug menu を `app/lib/features/novel/presentation/debug_menu.dart` に追加（`FakeNovelRepository` のダミー Work を 1 つ Library に投入できる、後続サイト別 change まで UI 確認用）

## 10. 締め

- [ ] 10.1 `flutter analyze` / `flutter test` / `dart format --set-exit-if-changed .` が green
- [ ] 10.2 macOS / Windows / Android で `debug_menu` 経由のダミー Library 追加 / 削除 / 再起動後の永続化を実機/エミュレータで確認
- [ ] 10.3 `ConsentDialog` の初回起動フローを各 OS で動作確認（外側タップで閉じない、「すべて拒否」で NovelHomeSection が placeholder 表示）
- [ ] 10.4 `README.md` の機能セクションに「オンライン小説ライブラリ（インフラ層）」の一行追記（具体的なサイト対応はサイト別 change で更新する旨を併記）
- [ ] 10.5 すべての task の `- [ ]` を `- [x]` に更新し、`/opsx:archive` で本 change をアーカイブ

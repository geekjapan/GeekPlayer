## Why

GeekPlayer v0.1 の柱の 1 つは「3 サイト統合のオンライン小説体験」だが、なろう / ノクターン系 / カクヨムはそれぞれ取得方式が異なる（公式 API / 公式 API / RSS + HTML パース）。サイト別の change（後続の `add-narou-novel-reader` / `add-kakuyomu-novel-reader`）が個別に DB スキーマ・能動キャッシュ規範・同意ダイアログ・レート制限を再実装すると、[ADR-0001](../../../docs/adr/0001-online-novel-fetch-policy.md) で固めた運用規範が分散・劣化する。先にサイト非依存の **インフラ層** を共有 capability として固定する必要がある。現状リポジトリには `app/lib/features/novel/` に scaffold は無く（[`app/lib/main.dart:1`](../../../app/lib/main.dart) は `_HelloScreen` のまま — `add-local-video-playback` で `HomeScreen` に置き換えられる前提）、`app/lib/core/network/` も未作成。

## What Changes

- **新規**: サイト非依存の **`NovelRepository`** インターフェイス（`Site` / `Work` / `Episode` 抽象）を `app/lib/core/novel/novel_repository.dart` に定義。後続のサイト別 change が `NarouNovelRepository` / `KakuyomuNovelRepository` として実装する。
- **新規**: drift スキーマに `novel_works` / `novel_episodes` / `novel_bookmarks` / `site_consents` テーブルを追加。
- **新規**: **「Library に追加」機能**（能動キャッシュの起点、[ADR-0001](../../../docs/adr/0001-online-novel-fetch-policy.md) §取得方針-1）— サイト別ソースが返す `Work` をユーザーが明示的に Library 化したときだけ全 `Episode` 本文をローカル保存する。
- **新規**: **サイト別同意ダイアログ** と `SiteConsent` 管理（ADR-0001 §注意書きの 4 箇所のうち、初回起動ダイアログ（②）と設定画面の常時表示（③）をこの change で実装。①README と ④`KakuyomuHtmlSource` docstring はサイト別 change の責務）。
- **新規**: ホーム画面の **`NovelHomeSection`**（ライブラリ一覧、サイト別フィルタ、空状態）— `add-local-video-playback` が作る `HomeScreen` にセクションとして合流する。
- **新規**: 共通の `RateLimiter`（token bucket）を `app/lib/core/network/rate_limiter.dart` に実装。User-Agent 構築・`robots.txt` 取得・429/503 指数バックオフのヘルパも `core/network/` に集約。
- **拡張**: `add-local-video-playback` が定義した `MediaSession` sealed hierarchy に **`PageSession`** バリアントを追加（読書位置 / ページめくり）。Dart 3 の sealed-class 制約上、`app/lib/core/media/page_session.dart` を `part of 'media_session.dart';` で結合する（GRILL-REPORT Q-CROSS-011 参照）。v0.2 の書籍 / 漫画と共有する最小 API で着地。

## Capabilities

### New Capabilities

- `online-novel-library`: `NovelRepository` 抽象、`Work` / `Episode` ドメインモデル、Library への追加 / 削除 / 一覧、能動キャッシュ動作、ホーム画面 `NovelHomeSection`。
- `site-consent`: 初回起動時のサイト別同意ダイアログ、設定画面での再同意 / 取り消し、同意なしサイトの機能無効化。
- `responsible-fetching`: `RateLimiter`（token bucket）、`User-Agent` 構築規約、`robots.txt` 尊重、429 / 503 指数バックオフ。ADR-0001 の運用規範を機械可読な要件に落とす。

### Modified Capabilities

- `media-session`: `add-local-video-playback` で定義された sealed `MediaSession` に `PageSession` バリアントを追加し、読書位置（ページ番号 / スクロール率）を `PagePosition` で表現できるよう要件を拡張。Dart 3 の sealed 制約に従い `part of 'media_session.dart';` 構造で結合する。

## Impact

**新規ディレクトリ / ファイル:**

- `app/lib/core/novel/novel_repository.dart` — `NovelRepository` interface
- `app/lib/core/novel/models/{site.dart, work.dart, episode.dart, work_id.dart}` — ドメイン値オブジェクト
- `app/lib/core/media/page_session.dart` — `MediaSession` sealed の `PageSession` バリアント（`part of 'media_session.dart';`）
- `app/lib/core/network/rate_limiter.dart` — token bucket 実装
- `app/lib/core/network/user_agent.dart` — UA ビルダー
- `app/lib/core/network/robots_txt.dart` — `robots.txt` パーサ + キャッシュ
- `app/lib/core/network/backoff.dart` — 指数バックオフ
- `app/lib/core/storage/tables/novel_works.dart`
- `app/lib/core/storage/tables/novel_episodes.dart`
- `app/lib/core/storage/tables/novel_bookmarks.dart`
- `app/lib/core/storage/tables/site_consents.dart`
- `app/lib/features/novel/data/library_repository.dart` — drift DAO を NovelRepository に紐付けるユーザ向け API
- `app/lib/features/novel/domain/{add_to_library_use_case.dart, remove_from_library_use_case.dart, list_library_use_case.dart}`
- `app/lib/features/novel/presentation/{home_section.dart, library_screen.dart, consent_dialog.dart, settings_section.dart}`

**変更:**

- [`app/lib/core/storage/database.dart`](../../../app/lib/core/storage/database.dart) — `add-local-video-playback` が定義する `@DriftDatabase` を **schema v1 → v2 へ bump** し、4 テーブルと対応 DAO を追加（`MigrationStrategy.onUpgrade(from:1, to:2)` で create）
- [`app/lib/core/media/media_session.dart`](../../../app/lib/core/media/media_session.dart) — sealed hierarchy に `part 'page_session.dart';` を追加して `PageSession` を結合
- `app/pubspec.yaml` — `dio`（HTTP）、`html`（カクヨムパーサで再利用するが本 change ではパース呼び出しは無し）、`xml`（RSS 用も後続 change 起点で再利用）、`crypto`（UA バージョン hash 用任意）を追加。サイト別 change が import するのを前提に、ここで土台だけ整える。
- `app/lib/main.dart` — `add-local-video-playback` で導入された `HomeScreen` に `NovelHomeSection` を差し込み、初回起動時に `ConsentDialog` を表示するフックを追加

**プラットフォーム影響:**

- v0.1 対象の macOS / Windows / Android で `dio` の HTTP が動作する
- Android で `<uses-permission android:name="android.permission.INTERNET"/>` を `AndroidManifest.xml` に明示
- macOS の sandbox に `com.apple.security.network.client = true` の entitlement を追加（[`app/macos/Runner/DebugProfile.entitlements`](../../../app/macos/Runner/DebugProfile.entitlements) と `Release.entitlements`）

**Non-goals:**

- なろう / ノクターン系 / カクヨムの **具体的なソース実装**（`NarouApiSource` / `NoctureApiSource` / `KakuyomuRssSource` / `KakuyomuHtmlSource`）— 後続 `add-narou-novel-reader` / `add-kakuyomu-novel-reader` の責務
- 検索 UI / ランキング UI / タグ絞り込み — サイト別 change で扱う
- 書籍（PDF / EPUB）/ 漫画 ZIP — v0.2 ロードマップ
- 動画 / 音楽（別 change）
- `PageSession` の完全な書籍/漫画 API（縦書きレイアウト、ピンチズーム、見開き、しおり）— v0.2 の `books-reader` / `manga-viewer`。本 change では小説の「現在何話の何 % まで読んだ」を表せる最小 API のみ。
- 自動アップデート、英語 UI、CarPlay / Android Auto 連携

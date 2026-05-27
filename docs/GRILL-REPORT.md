# GeekPlayer Self-Grill Report

> **Generated**: 2026-05-27T04:31:06Z
> **Model**: Opus 4.7 (1M context), effort=max
> **Scope**: 7 proposals under `openspec/changes/`
> **Status**: ⚠️ Sub-agent stalled at the final write step (stream watchdog 600s). The Q&A below is compiled from the agent's salvaged analytical output. **No HIGH-confidence auto-edits were applied** — every finding is left for user review.

## How to use this report

This file is a handoff document. Re-enter a future session with:

> `docs/GRILL-REPORT.md` の Open Questions Index を上から順に解決してください。
> 解決した question は `- [x]` にチェックし、適用した変更を Applied Edits に追記し、
> 必要に応じて該当 proposal の artifact を編集してください。

Stable IDs (e.g. `Q-CROSS-001`) never change once assigned. A subsequent grill round
should append new questions with the next available number per category.

### ID prefixes

| Prefix | Category |
|---|---|
| `Q-CROSS-NNN` | Cross-cutting between proposals |
| `Q-VID-NNN`   | `add-local-video-playback` |
| `Q-AUD-NNN`   | `add-local-audio-playback` |
| `Q-NOV-NNN`   | `add-online-novel-library` |
| `Q-NAR-NNN`   | `add-narou-novel-reader` |
| `Q-KAK-NNN`   | `add-kakuyomu-novel-reader` |
| `Q-SET-NNN`   | `add-app-settings` |
| `Q-ABT-NNN`   | `add-about-and-licenses` |
| `Q-GAP-NNN`   | Infrastructure / cross-feature gaps |
| `Q-RISK-NNN`  | Operational / legal / dependency risk |
| `Q-UX-NNN`    | UX-level open decisions |

### Confidence levels

- **HIGH** — Answer is derivable from existing ADRs / decisions; safe to apply
- **MEDIUM** — Reasonable default exists, but worth user confirmation
- **LOW** — Strategic / preference / external dependency; user must decide

## Summary

| Confidence | Count | Action |
|---|---|---|
| HIGH | 6 | Awaiting user review (auto-edit deferred — see status note) |
| MEDIUM | 19 | Awaiting user confirmation |
| LOW | 13 | Awaiting user input |
| **Total** | **38** | |

By category: CROSS=20, VID=0, AUD=2, NOV=2, NAR=3, KAK=3, SET=2, ABT=0, GAP=4, RISK=1, UX=1.

---

## Cross-cutting questions

### Q-CROSS-001 — drift schema versioning sequence is directly contradicted across 3 proposals

- **Tags**: CROSS, RISK
- **Affected**: `add-local-video-playback`, `add-online-novel-library`, `add-app-settings`
- **Question**: drift schema バージョンの確定済み順序はどれか?
- **Evidence**:
  - `add-local-video-playback/design.md` D4: "drift schema は v1 から開始"
  - `add-online-novel-library/design.md` Migration Plan: "v1 のまま — 4 テーブル追加、pre-release なので bump なし"
  - `add-app-settings/design.md` D3: "v1=video の核, v2=novel-library, v3=app-settings"
  - `docs/HANDOFF.md` も `app-settings/design.md` と同じ前提
- **My answer**: HANDOFF / app-settings 系を **正** とし、`add-online-novel-library/design.md` Migration Plan を「v1 → v2 へ schema bump、`MigrationStrategy.onUpgrade(from: 1, to: 2)` で novel 系 4 テーブル追加」に修正する。理由: pre-release でも開発中に CI が永続化テストを走らせる前提があり、schema versioning は最初から正しく回すほうが apply 時の事故が少ない。
- **Confidence**: HIGH
- **Action**: edit `add-online-novel-library/design.md` Migration Plan + 対応 tasks に migration コード追加。`add-app-settings` tasks には `v2 → v3` の migration を明示
- **Resolved**: [ ]

### Q-CROSS-002 — `Site` enum の名前と値が 3 proposal で異なる

- **Tags**: CROSS, GLOSSARY
- **Affected**: `add-online-novel-library`, `add-narou-novel-reader`, `add-kakuyomu-novel-reader`
- **Evidence**:
  - novel-library: `enum Site { narou, noc, kakuyomu }`（3 値、ノクターン系を `noc`）
  - narou-reader spec: `SiteId.narou18`（型名が `SiteId`、ノクターン系を `narou18`）
  - kakuyomu-reader spec: 文字列キー `'kakuyomu'` を `SiteConsentReader.isGranted('kakuyomu')` で直接使用
  - HANDOFF: 用語混在
- **Question**: 共通の sealed 型 / enum 名と値はどれを正とするか?
- **My answer**: `enum Site { narou, noc, kakuyomu }`（novel-library 採用）に統一。narou-reader の `SiteId` は廃止、`Site` を import。kakuyomu-reader の文字列 `'kakuyomu'` は `Site.kakuyomu.id` に置き換え（`Site` に `String get id` を生やす）。CONTEXT.md にも反映。
- **Confidence**: HIGH（novel-library が共通インフラを所有するため）
- **Action**: 全 novel 系 proposal の spec.md / design.md の `Site` 参照を統一。CONTEXT.md に `Site` 用語を追加（現状未記載）
- **Resolved**: [ ]

### Q-CROSS-003 — `SiteConsent` の型名・API が 3 proposal で乖離

- **Tags**: CROSS, GAP
- **Affected**: `add-online-novel-library`, `add-narou-novel-reader`, `add-kakuyomu-novel-reader`, `add-app-settings`
- **Evidence**:
  - novel-library: `SiteConsentRepository`、`grant(Site)` の単一引数
  - narou-reader: `SiteConsentRepository.grant(SiteId.narou18, grantedAt: <now>)` の 2 引数
  - kakuyomu-reader: `SiteConsentReader` という別名で `.isGranted('kakuyomu')`
  - app-settings: 設定画面から consent UI を呼ぶが、interface 名が明示されていない
- **Question**: interface 名・メソッドシグネチャの正は?
- **My answer**: `SiteConsentRepository`（novel-library 命名）を共通とし、メソッドは:
  - `Future<bool> isGranted(Site site)`
  - `Future<void> grant(Site site, {required String policyVersion})`
  - `Future<void> revoke(Site site)`
  - `Stream<SiteConsentEvent> watch()`
  policyVersion は ADR-0001 由来でカクヨムが使う。narou18 は age-gate 用に別 capability で独立した状態を持つ（→ Q-CROSS-008 参照）
- **Confidence**: MEDIUM
- **Action**: novel-library/site-consent spec を canonical 定義として明示、narou-reader / kakuyomu-reader / app-settings の参照を全て調整
- **Resolved**: [ ]

### Q-CROSS-004 — `NovelRepository` のメソッド名 / 戻り型が実装と契約で乖離

- **Tags**: CROSS, GAP
- **Affected**: `add-online-novel-library`, `add-narou-novel-reader`, `add-kakuyomu-novel-reader`
- **Evidence**:
  - novel-library: `Future<Work> fetchWork(WorkId)`, `Stream<Episode> fetchEpisodes(WorkId)`, `Future<EpisodeBody> fetchEpisodeBody(workId, episodeId)`
  - narou-reader: `NarouNovelRepository.fetchDetail('n4830bu')`（`fetchDetail`）+ `NarouEpisodeFetcher.fetchBody(ncode, episodeIndex) -> String`
  - kakuyomu-reader: `KakuyomuHtmlSource.fetchWork(workId)` + `.fetchEpisodeBody(workId, episodeId) -> KakuyomuEpisodeBody`
- **Question**: interface の最終形と各サイトの内部実装名は?
- **My answer**: novel-library が定義する `NovelRepository` interface の `fetchWork` / `fetchEpisodes` / `fetchEpisodeBody` を **必須メソッド**、各サイトリポジトリ実装は同名で公開。内部 helper（`KakuyomuHtmlSource` 等）は別ファイルに分離し、外部 API は interface 経由に統一。narou の `fetchDetail` は実装ファイル内部の名前として残しても良いが、`NarouNovelRepository.fetchWork` から呼ぶ形にする。
- **Confidence**: MEDIUM
- **Action**: narou-reader spec の `fetchDetail` 表記を `fetchWork` に変更、kakuyomu の戻り型 `KakuyomuEpisodeBody` を共通 `EpisodeBody` に変換 mapper を介すことを明示
- **Resolved**: [ ]

### Q-CROSS-005 — `Work` モデルの field が site 実装で破綻している

- **Tags**: CROSS, GAP
- **Affected**: `add-online-novel-library`, `add-narou-novel-reader`
- **Evidence**:
  - novel-library spec: `Work` は `id (WorkId)`, `title`, `author`, `episodeCount`, optional `synopsis`
  - narou-reader spec: "Work whose **`episodes` field** contains an Episode for every `general_all_no`"
  - 共通 `Work` には `episodes` field がない（`episodeCount` のみ）
- **Question**: `Work` に `List<Episode> episodes` を持たせるか、`episodeCount` だけにしてエピソード本体は別 query にするか?
- **My answer**: `Work` は概要のみ（`episodeCount`）にし、エピソード一覧は `NovelRepository.fetchEpisodes(WorkId)` でストリーム取得。理由: なろう作品で 1000 話超があり、`Work` に全エピソードを抱えるとメタデータ取得が遅い。narou-reader の spec 表記を `episodes` から `fetchEpisodes` 呼び出しに修正。
- **Confidence**: HIGH
- **Action**: narou-reader spec の `Work.episodes` 言及を `fetchEpisodes` 呼び出しに置換
- **Resolved**: [ ]

### Q-CROSS-006 — `addToLibrary` の API 位置が 3 proposal でバラバラ

- **Tags**: CROSS
- **Affected**: `add-online-novel-library`, `add-narou-novel-reader`, `add-kakuyomu-novel-reader`
- **Evidence**:
  - novel-library: `LibraryRepository.addToLibrary(NovelRepository, WorkId)`
  - kakuyomu-reader: `KakuyomuNovelRepository.addToLibrary(workId)` — サイトリポジトリ自身に持つ
  - narou-reader: `LibraryService.add(work)` — `Service` という別の型
- **Question**: 「Library に追加」操作の owner と署名は?
- **My answer**: novel-library が定義する `LibraryRepository.addToLibrary(NovelRepository, WorkId)` を canonical。site repo に直接生やさない（site repo は data source、library 操作は orchestration なので別レイヤ）。narou-reader / kakuyomu-reader spec の表現を統一する。`LibraryService` 命名は捨てる（`LibraryRepository` に集約）。
- **Confidence**: HIGH
- **Action**: narou + kakuyomu reader spec の library 追加表現を `LibraryRepository.addToLibrary` に統一
- **Resolved**: [ ]

### Q-CROSS-007 — `RateLimiter` の API が 2 proposal で完全に違う

- **Tags**: CROSS, RISK
- **Affected**: `add-online-novel-library`, `add-kakuyomu-novel-reader`
- **Evidence**:
  - novel-library: `RateLimiter({rate, burst, maxConcurrency}); run<T>(Future<T> Function())`
  - kakuyomu-reader: `RateLimiter(siteKey: 'kakuyomu', minInterval: Duration, maxConcurrent: 1)` and `limiter.acquire('kakuyomu')`
- **Question**: 共通 `RateLimiter` の API は?
- **My answer**: novel-library 側の `RateLimiter({rate, burst, maxConcurrency}).run(() async {...})` を canonical（site key 引数は持たず、サイト別にインスタンスを分離して DI）。`acquire('siteKey')` 形式は廃止。
- **Confidence**: HIGH
- **Action**: kakuyomu-reader spec / design / tasks の RateLimiter 言及を統一
- **Resolved**: [ ]

### Q-CROSS-008 — kakuyomu max retries (3 vs 6) の数値が直接矛盾

- **Tags**: CROSS, RISK
- **Affected**: `add-online-novel-library`, `add-kakuyomu-novel-reader`
- **Evidence**:
  - novel-library responsible-fetching spec: max retries **6**
  - kakuyomu-reader D4: max **3** retries
- **Question**: カクヨムのリトライ回数最大値は?
- **My answer**: ADR-0001 は明示数値を持たないが「max 5 分」までのバックオフを定めている。指数バックオフ (`2^n` 秒、初回 1s) で 6 回なら最終遅延が 32s、累計 ~63s で 5 分内に収まる。3 回だと 1+2+4=7s で諦めるため過剰早すぎ。**6 回を正**とする。
- **Confidence**: MEDIUM
- **Action**: kakuyomu-reader D4 の数値を 6 に修正
- **Resolved**: [ ]

### Q-CROSS-009 — `robots.txt` TTL (24h vs 1h) の数値が矛盾

- **Tags**: CROSS
- **Affected**: `add-online-novel-library`, `add-kakuyomu-novel-reader`
- **Evidence**:
  - novel-library responsible-fetching: 24h TTL
  - kakuyomu-reader D6: 1h TTL
- **Question**: `robots.txt` キャッシュ TTL は?
- **My answer**: 24h を採用（一般的な web cache の良識的範囲、サイト側 ToS 変更の即時反映は別途同意ダイアログのバージョン管理で対応）。kakuyomu spec を 24h に揃える。
- **Confidence**: MEDIUM
- **Action**: kakuyomu-reader D6 修正
- **Resolved**: [ ]

### Q-CROSS-010 — `recent_items.kind` 列の `novel` 値が未定義（GAP）

- **Tags**: CROSS, GAP
- **Affected**: `add-online-novel-library`, `add-narou-novel-reader`, `add-kakuyomu-novel-reader`
- **Evidence**:
  - video change: `kind='video'`
  - audio change: DAO に `kind` 引数追加（`'audio'`）
  - novel 系: `recent_items` に書き込む記述なし。代わりに `novel_bookmarks` で完結している
- **Question**: 「最近読んだ小説」はホーム画面の `recent_items` に乗せるか、独自テーブルから引くか?
- **My answer**: 一貫性のため `recent_items` に `kind='novel'` で乗せる（ホーム画面が動画/音楽/小説を統一的に出せる）。`novel_bookmarks` は読書位置の保存に専念、`recent_items` は「最後に開いた作品単位の一覧」。novel-library spec に「Library 内の作品を開いたら `recent_items` に `kind='novel'` で upsert」の Requirement を追加。
- **Confidence**: MEDIUM
- **Action**: novel-library spec に Requirement 追加 / tasks に書き込み処理追加
- **Resolved**: [ ]

### Q-CROSS-011 — `MediaSession` sealed 拡張の Dart 言語制約

- **Tags**: CROSS, RISK
- **Affected**: `add-local-video-playback`, `add-local-audio-playback`, `add-online-novel-library`
- **Evidence**:
  - Dart 3 の `sealed class` は **同一ライブラリ内のサブクラスのみ** 許可（別ファイルは `part of` で同一 library にする必要あり）
  - video: `MediaSession` を `app/lib/core/media/media_session.dart` に定義、`VideoSession` を `app/lib/core/media/video_session.dart` に
  - audio: `AudioSession` を `app/lib/core/media/audio_session.dart` に
  - novel-library: `PageSession` を `app/lib/core/novel/page_session.dart`（**別ディレクトリ**）に
- **Question**: sealed 拡張をどう実装するか?
- **My answer**: 2 案。**(a)** すべてのサブクラスを `app/lib/core/media/` 配下に置き `part of 'media_session.dart';` で結合。**(b)** `MediaSession` を sealed ではなく `abstract base` にして、サブクラスを別 library に置く（exhaustive switch は失われる）。**推奨は (a)**: `PageSession` も `core/media/page_session.dart` に置き、`part of` で結合する。novel 機能側からは re-export。
- **Confidence**: HIGH（Dart 言語仕様）
- **Action**: novel-library design D9 を修正（PageSession の物理パスを `core/media/page_session.dart` に）+ video / audio designs に `part of` 構造を明示
- **Resolved**: [ ]

### Q-CROSS-012 — `Episode` ID 型が int 前提だが kakuyomu が string

- **Tags**: CROSS, GAP, RISK
- **Affected**: `add-online-novel-library`, `add-kakuyomu-novel-reader`
- **Evidence**:
  - novel-library `Episode` model: `EpisodeId(int index)` 1-based
  - なろう: ncode 内の整数連番 (`general_all_no`) — int で表現可能
  - カクヨム: episode ID が UUID/数値文字列（URL: `/works/W/episodes/E` の `E` は数値文字列だが API 観点では string で扱うべき）
- **Question**: `EpisodeId` の型は int / String / sealed どれか?
- **My answer**: `sealed class EpisodeId { final String value; }` にして、`NarouEpisodeId(String value)` / `KakuyomuEpisodeId(String value)` を持つ。内部表現は String 統一、なろうは `int.toString()`、カクヨムはそのまま。`int index` でのソート用に optional `int? ordering` を持たせる。
- **Confidence**: MEDIUM
- **Action**: novel-library spec `Episode` 定義の見直し、narou/kakuyomu spec の ID 表現を統一
- **Resolved**: [ ]

### Q-CROSS-013 — `HomeScreen` を 6 つの change が編集する競合

- **Tags**: CROSS, UX
- **Affected**: video, audio, novel-library, narou, kakuyomu, app-settings, about（実質 7 change）
- **Evidence**:
  - video: `VideoHomeSection` を追加（オーナー）
  - audio: `AudioHomeSection`, `MiniPlayer` を追加
  - novel-library: `NovelHomeSection` を追加
  - narou-reader: `NarouHomeSection` を追加
  - kakuyomu-reader: `KakuyomuSection` を追加
  - about: AppBar に info アイコン追加
  - app-settings: AppBar に gear アイコン追加
- **Question**: `HomeScreen` の所有権と複数 change の同居方法は?
- **My answer**: `HomeScreen` は **`features/library/home_screen.dart` 上のセクション集約コンテナ**として書き、各 change は **自身のセクションウィジェットを `home_section_registry` に登録するだけ**にする。Riverpod の `homeSectionsProvider` が登録済みセクションを順序付きリストで返し、`HomeScreen` はそれを `ListView` で描画。これにより各 change は他 change を編集せず追加可能。AppBar アイコンも同様に `homeAppBarActionsProvider` で集約。
- **Confidence**: MEDIUM（軽い設計追加だが各 change の tasks に整合させる必要）
- **Action**: 新規 ADR-0003 候補「Home screen composition via registry providers」を立てる、各 change の design.md にこのパターンを反映
- **Resolved**: [ ]

### Q-CROSS-014 — Riverpod v2 と v3 の API が混在

- **Tags**: CROSS, RISK
- **Affected**: 全 7 change
- **Evidence**:
  - `app/pubspec.yaml`: `flutter_riverpod: ^3.3.1` (v3) + `riverpod_annotation: ^4.0.2` (v3 codegen)
  - `docs/HANDOFF.md`: "Riverpod v2 (Notifier API)" と記載
  - video / audio designs: `AutoDisposeNotifierProvider<...>`（v2 style）
  - app-settings D2: `@Riverpod(keepAlive: true) class AppSettingsNotifier extends _$AppSettingsNotifier`（v3 codegen style）
  - `riverpod_generator` は pubspec の dev_dependencies に **未追加** → codegen は走らない
- **Question**: v2 / v3 どちらに揃えるか?
- **My answer**: pubspec が既に v3 系のため **v3 + codegen に統一**。`riverpod_generator: ^3.x.x` を `dev_dependencies` に追加し、全 change の design / tasks を `@Riverpod` 記法に揃える。HANDOFF.md も「v3 (codegen)」に修正。
- **Confidence**: HIGH（pubspec が事実上の正）
- **Action**: pubspec に `riverpod_generator` 追加 / HANDOFF.md 修正 / 各 change design の Notifier 記述を v3 codegen に変更
- **Resolved**: [ ]

### Q-CROSS-015 — `episode_resume_points` テーブルが novel-library で未定義のまま narou-reader が依存

- **Tags**: CROSS, GAP
- **Affected**: `add-online-novel-library`, `add-narou-novel-reader`
- **Evidence**:
  - narou-reader spec: `episode_resume_points(workId, episodeIndex, scrollOffset)` を参照
  - novel-library spec: 同名テーブルなし。`novel_bookmarks(site, externalId, episodeIndex, scrollFraction, updatedAt)` のみ
- **Question**: 読書位置保存テーブルの正は?
- **My answer**: novel-library の `novel_bookmarks` を正とし、`scrollFraction` (0.0〜1.0) で保存。narou-reader spec の `episode_resume_points` 参照を `novel_bookmarks` に置換、`scrollOffset` (pixel) を `scrollFraction` に変換するヘルパを `core/novel/` に置く（フォント変更でレイアウトが変わってもページ位置を保てる）。
- **Confidence**: HIGH（共通テーブル定義は novel-library が所有）
- **Action**: narou-reader spec を `novel_bookmarks` ベースに修正
- **Resolved**: [ ]

### Q-CROSS-016 — `reader_settings` テーブルと `app_settings` テーブルが二重所有

- **Tags**: CROSS
- **Affected**: `add-narou-novel-reader`, `add-app-settings`
- **Evidence**:
  - narou-reader D8: 独自の `reader_settings` drift テーブル（単一行）
  - app-settings: `app_settings(key TEXT PK, value TEXT)` が「小説フォント / 行間 / テーマ別背景色」を保存する canonical store
- **Question**: 読書設定の保存先は?
- **My answer**: `app_settings` を canonical とし、`reader_settings` は削除。読書設定の key は `novel.reader.fontSize`, `novel.reader.lineHeight`, `novel.reader.fontFamily`, `novel.reader.background.light`, `novel.reader.background.dark` のように prefix で名前空間を切る。narou と kakuyomu の reader 画面はこの設定を購読。
- **Confidence**: HIGH
- **Action**: narou-reader spec / design / tasks の `reader_settings` テーブル言及を削除し、`app_settings` の key 参照に置換
- **Resolved**: [ ]

### Q-CROSS-017 — AndroidManifest.xml への変更が複数 change で累積する管理

- **Tags**: CROSS
- **Affected**: video, audio, novel-library, about
- **Evidence**:
  - video: `READ_MEDIA_VIDEO`, `READ_EXTERNAL_STORAGE (maxSdkVersion=32)`
  - audio: `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, audio_service `<service>` + `<receiver>`
  - novel-library: `INTERNET`
  - about: `<queries>` for `https` URL launch
- **Question**: 各 change が AndroidManifest を編集する apply 時の競合をどう避けるか?
- **My answer**: apply 順序を documented：video → audio → novel-library → narou → kakuyomu → app-settings → about の通り適用すれば conflict なし（accumulate のみ）。各 tasks の「AndroidManifest 編集」task に **既存セクションの保持** を明記。あるいは `flutter_native_splash` のような注入式ツールは使わず、手動編集で十分。
- **Confidence**: MEDIUM
- **Action**: 各 change tasks に「既存 manifest との差分のみを追加する」注記を入れる
- **Resolved**: [ ]

### Q-CROSS-018 — macOS entitlements の累積管理

- **Tags**: CROSS, RISK
- **Affected**: video, audio, novel-library, about
- **Evidence**:
  - video: `com.apple.security.files.user-selected.read-only`
  - audio: `LSBackgroundModes = audio`（`Info.plist`）+ background entitlement
  - novel-library: `com.apple.security.network.client`
  - about: `LSApplicationQueriesSchemes` for URL open
- **Question**: macOS の sandbox entitlements / Info.plist 変更の累積方法は?
- **My answer**: Q-CROSS-017 と同じ問題。apply 順序通りに重ねれば OK。ただし macOS の `DebugProfile.entitlements` と `Release.entitlements` の **両方** を編集する必要があり、忘れやすい。各 tasks に両方への明記が必要。
- **Confidence**: MEDIUM
- **Action**: 各 change tasks の macOS 編集 task に「Debug + Release の両方の `.entitlements`」を明示
- **Resolved**: [ ]

### Q-CROSS-019 — `package_info_plus` を複数 change が同時に追加しようとする

- **Tags**: CROSS, GAP
- **Affected**: novel-library, about-and-licenses
- **Evidence**:
  - novel-library tasks 1.1: `package_info_plus` を追加
  - about-and-licenses tasks: 同じく追加
- **Question**: 同一依存追加 task の冪等性はどう担保するか?
- **My answer**: 各 tasks に「`flutter pub add <pkg>` を実行し、既に追加されていれば pubspec が変わらないことを確認」と書く。あるいは「依存追加を専用の最小 change `add-shared-deps` にまとめる」案もあるが、過剰設計。各 change の 1.1 task に「冪等」を明記すれば十分。
- **Confidence**: HIGH
- **Action**: 該当 tasks に冪等性 note を追加
- **Resolved**: [ ]

### Q-CROSS-020 — `url_launcher` を 2 change が追加しようとする

- **Tags**: CROSS
- **Affected**: kakuyomu-reader, about-and-licenses
- **Evidence**:
  - kakuyomu-reader 1.2: `url_launcher`
  - about-and-licenses 1.1: 同じ
- **Question**: Q-CROSS-019 と同じ
- **My answer**: 同上、冪等 note で対応
- **Confidence**: HIGH
- **Action**: tasks に冪等 note 追加
- **Resolved**: [ ]

---

## Per-proposal questions

### `add-local-audio-playback`

#### Q-AUD-001 — `audio-background` entitlement のキー名が macOS では iOS と異なる

- **Tags**: AUD, RISK
- **Question**: macOS で音楽バックグラウンド再生を有効化する entitlement キー名は?
- **My answer**: iOS は `UIBackgroundModes = [audio]` だが macOS は通常の app sandbox + `LSBackgroundModes` を `Info.plist` に書く方式（macOS ではバックグラウンドという概念自体が iOS と異なり、アプリ起動中はそのまま再生継続）。design.md の表現を「`Info.plist` の `LSBackgroundModes` に `audio` を追加」と「macOS では特別な entitlement は不要」に修正。
- **Confidence**: MEDIUM
- **Action**: audio design D2 / 1.3 task の表記を実機検証して訂正
- **Resolved**: [ ]

#### Q-AUD-002 — アートワークなしファイルのフォールバック asset を誰が用意するか

- **Tags**: AUD, UX
- **Question**: `audio_metadata_reader` がアートワークを返さなかった時の placeholder 画像はどこに置くか?
- **My answer**: `app/lib/features/audio/assets/default_artwork.svg` に音符アイコンを置き、`pubspec.yaml` の `flutter.assets` に追加。タスクに「アセット作成」項を追加。
- **Confidence**: MEDIUM
- **Action**: audio tasks に asset 作成 task を追加 / pubspec assets セクション更新
- **Resolved**: [ ]

### `add-online-novel-library`

#### Q-NOV-001 — `PageSession` を v0.1 で出すか v0.2 に押し出すか

- **Tags**: NOV, UX
- **Question**: novel-library で `PageSession` を `MediaSession` の sealed バリアントとして公開するか?
- **My answer**: v0.1 では出さない。novel 機能の読書位置保存は `novel_bookmarks` テーブルで完結しており、`MediaSession` の抽象を共有する必要は薄い（小説の「再生中」は曖昧）。v0.2 の書籍/漫画ビューア時に PageSession を導入する。novel-library spec の `media-session` capability の MODIFIED を **削除**。
- **Confidence**: MEDIUM
- **Action**: novel-library specs/media-session/spec.md を削除 / design D9 の PageSession 言及を v0.2 ロードマップへ移動
- **Resolved**: [ ]

#### Q-NOV-002 — `WorkQueryExtensions` という型が narou-reader から参照されるが、novel-library spec に存在しない

- **Tags**: NOV, GAP
- **Question**: 検索 query のサイト別拡張型をどう設計するか?
- **My answer**: `WorkQuery` を sealed にせず、共通 `WorkQuery { String? keyword; SortOrder? sort; }` を提供、サイト別の追加 query は `NarouSearchOptions extends WorkQuery` のような単純継承で表現する。novel-library spec に `WorkQuery` 基底型を Requirement として追加。narou-reader spec の `WorkQueryExtensions` 言及を `NarouSearchOptions` に置換。
- **Confidence**: MEDIUM
- **Action**: novel-library spec に `WorkQuery` 基底型 Requirement 追加 / narou spec 訂正
- **Resolved**: [ ]

### `add-narou-novel-reader`

#### Q-NAR-001 — R18 consent と scraping consent の意味論が同じテーブルで管理されている

- **Tags**: NAR, RISK
- **Question**: `site_consents` テーブルで「ノクターン年齢確認」と「カクヨムスクレイピング同意」を **同列の `policyVersion` 付き行** として扱って良いか?
- **My answer**: 別レコードとして扱うが、意味論は明確に違う:
  - kakuyomu: 「スクレイピング規範への同意」、`policyVersion` が ADR-0001 のバージョン
  - narou18: 「自分は 18 歳以上である」、`policyVersion` の概念が薄い
  両方とも `site_consents` に乗せるが、narou-reader 側で `policyVersion='age-verified'` のような固定値で識別する。あるいは別テーブル `age_verifications` を切る案もあり、こちらの方が semantic に綺麗。**推奨: 別テーブル**。
- **Confidence**: LOW（設計判断、ユーザー方針による）
- **Action**: 判断後 narou-reader spec を更新
- **Resolved**: [ ]

#### Q-NAR-002 — なろう公式 API の「本文取得」エンドポイントが design.md で「要調査」のまま

- **Tags**: NAR, GAP
- **Question**: なろうは検索 API は持つが、本文取得 API は別系統?
- **My answer**: なろうの公式 API は **検索/メタデータのみ**。本文は `https://ncode.syosetu.com/<ncode>/<episode>/` の HTML をパースするのが現実。これは ADR-0001 の方針に抵触する（カクヨムと同じスクレイピング扱い）。なろう本体への扱いを **ADR-0001 に追加するか、新 ADR を立てる** 必要がある。
- **Confidence**: LOW（運用方針）
- **Action**: ユーザーに確認、必要なら ADR-0003 を起こす
- **Resolved**: [ ]

#### Q-NAR-003 — R18 consent revoke 時のキャッシュ削除動作が未定義

- **Tags**: NAR, GAP
- **Question**: ノクターン同意を取り消した時、既に Library に追加済みの R18 作品本文キャッシュをどうするか?
- **My answer**: 取り消し時に「該当サイトの本文キャッシュをクリアしますか?」とダイアログ → ユーザー選択。デフォルト「クリアする」。
- **Confidence**: MEDIUM
- **Action**: narou-reader spec に Requirement 追加
- **Resolved**: [ ]

### `add-kakuyomu-novel-reader`

#### Q-KAK-001 — カクヨムの公式 RSS は「新着」「ランキング」を提供するが、任意キーワード検索は提供していない

- **Tags**: KAK, UX
- **Question**: 検索 UI から任意キーワードで作品を探す機能は v0.1 で提供するか?
- **My answer**: v0.1 では「新着 / ランキング / タグ別」のみ。任意キーワード検索は公式手段がない（HTML 検索パースは ADR-0001 違反）。kakuyomu-reader spec の「検索画面」Requirement を「ブラウズ画面」に rename し、機能を絞る。
- **Confidence**: MEDIUM
- **Action**: kakuyomu spec の「検索」を「ブラウズ」に
- **Resolved**: [ ]

#### Q-KAK-002 — HTML 構造変更で失敗した時のフォールバック動作

- **Tags**: KAK, RISK
- **Question**: パース失敗時に in-app WebView に倒すか、外部ブラウザに送るか?
- **My answer**: 外部ブラウザ送りを優先（WebView を入れると iOS 配布時に審査が増える、Android で WebView バージョン依存が出る等）。`url_launcher` で公式 URL を開く。`kakuyomu-resilience` capability にこの Requirement を明示。
- **Confidence**: MEDIUM
- **Action**: kakuyomu-resilience spec に Requirement 追加 / WebView 依存を除外
- **Resolved**: [ ]

#### Q-KAK-003 — スナップショットテストの実 HTML サンプルをリポジトリに置く方針

- **Tags**: KAK, RISK
- **Question**: パーサテスト用の HTML fixture をリポジトリに含めるか?
- **My answer**: 含める（`app/test/fixtures/kakuyomu/*.html`）。ただし著作権配慮で「最小限の構造抜粋（本文は短縮）」とする。CI で `flutter test` 時に実行。
- **Confidence**: MEDIUM
- **Action**: kakuyomu tasks に fixture 作成 task を追加
- **Resolved**: [ ]

### `add-app-settings`

#### Q-SET-001 — drift migration v2 → v3 のテスト戦略

- **Tags**: SET, RISK
- **Question**: app_settings 追加時の v2 → v3 migration テストは?
- **My answer**: `drift_dev` の `MigrationStrategy` テストガイド通り、v2 DB を作って v3 にアップグレード → 既存 `novel_works` などのデータが消えないこと + 新 `app_settings` が空で作成されることを検証。tasks にこの test を明示。
- **Confidence**: HIGH
- **Action**: app-settings tasks に migration test 追加
- **Resolved**: [ ]

#### Q-SET-002 — 設定値変更時の再生中アプリへのリアルタイム反映

- **Tags**: SET, UX
- **Question**: 動画再生中にテーマや字幕設定を変更したら、即座にプレイヤー画面に反映されるか?
- **My answer**: Riverpod `AppSettingsNotifier` を購読する形にしておけば自動的に反映される（v3 codegen でも v2 NotifierProvider でも可）。各 feature の Notifier が `ref.watch(appSettingsProvider)` で購読することを設計に明示。
- **Confidence**: MEDIUM
- **Action**: app-settings design に「features 側の購読パターン」を追記
- **Resolved**: [ ]

---

## Infrastructure / cross-feature gaps

### Q-GAP-001 — `AppError` / 共通エラー UX が定義されていない

- **Tags**: GAP, UX
- **Affected**: 全 change
- **Question**: 共通の `AppError` 型 / トースト UI / 再試行 UX を別 change として起こすか、各 change に注記するか?
- **My answer**: 別 change として **`add-error-ux-infra`** を立てる（v0.1 範囲内）。`sealed AppError` + `ErrorToast` ウィジェット + retry 戦略。これがあると後続 change のエラー文言が散らからない。
- **Confidence**: MEDIUM
- **Action**: 新規 change `add-error-ux-infra` の propose を別途実行
- **Resolved**: [ ]

### Q-GAP-002 — `riverpod_generator` が dev_dependencies に未追加

- **Tags**: GAP, RISK
- **Question**: codegen の動作確認は?
- **My answer**: `flutter pub add --dev riverpod_generator` を実行し `pubspec.yaml` に追加。Q-CROSS-014 と連動。
- **Confidence**: HIGH
- **Action**: pubspec 更新 / scaffold 検証
- **Resolved**: [ ]

### Q-GAP-003 — `THIRD_PARTY_NOTICES.md` の `webfeed` 表記が実依存 `webfeed_revised` と乖離

- **Tags**: GAP
- **Question**: 表記揺れの修正は?
- **My answer**: `THIRD_PARTY_NOTICES.md` を `webfeed_revised` (MIT) に修正。
- **Confidence**: HIGH
- **Action**: 1 行修正
- **Resolved**: [ ]

### Q-GAP-004 — about-and-licenses の `flutter_oss_licenses` 出力に libmpv が載らない問題は対処済みだが、テストで担保していない

- **Tags**: GAP, RISK
- **Question**: libmpv 通知が画面に常に表示されることをどうテストするか?
- **My answer**: about-screen のウィジェットテストで「LGPL 専用通知セクションが存在し、`mpv-player/mpv` URL を含むテキストを表示する」を確認する Requirement を `lgpl-compliance` spec に追加。
- **Confidence**: MEDIUM
- **Action**: about spec に Requirement 追加 / tasks にテスト task 追加
- **Resolved**: [ ]

---

## Risk

### Q-RISK-001 — iOS / iPadOS 配布時に LGPL 動的リンクが App Store と相性が悪い

- **Tags**: RISK
- **Affected**: v0.2 計画
- **Question**: iOS 対応時の libmpv 取り扱いは?
- **My answer**: 既に `docs/HANDOFF.md` で言及済みだが、v0.2 の `add-platform-ios` change を起こす前に **ADR-0004 案件として正式に決める**。選択肢: (a) iOS は AltStore / 直配布のみ（LGPL OK） (b) iOS では `media_kit` を捨てて `video_player` に切り替え (c) media_kit のソース改変要件を満たす分離配布。
- **Confidence**: LOW
- **Action**: v0.2 計画開始時に ADR を起こす
- **Resolved**: [ ]

---

## UX

### Q-UX-001 — ja-first の文言を ARB ファイルに切り出すタイミング

- **Tags**: UX
- **Question**: 各 change で UI 文言をハードコードする方針だが、後で en localization する時の負債が膨らむ
- **My answer**: v0.1 では `intl_translation` の skeleton（`l10n.yaml` + `lib/l10n/app_ja.arb`）を立てておき、ハードコード文字列の代わりに `AppLocalizations.of(context).foo` を使う規約にする。en の ARB は v0.2 の `add-english-localization` で書く。
- **Confidence**: MEDIUM
- **Action**: 新規 change `add-i18n-skeleton` を v0.1 範囲で起こすか、各 change の最初の 1 つ（video）に内包させるか
- **Resolved**: [ ]

---

## Open Questions Index

### HIGH-priority for user (resolve first)

- [ ] **Q-CROSS-001** — drift schema versioning sequence: pre-release だが v1/v2/v3 で正しく bump するか
- [ ] **Q-CROSS-002** — `Site` enum の正は `enum Site { narou, noc, kakuyomu }` で良いか
- [ ] **Q-CROSS-005** — `Work` モデルから `episodes` field を取り除き `fetchEpisodes(WorkId)` 経由に統一
- [ ] **Q-CROSS-006** — `LibraryRepository.addToLibrary` に統一（`LibraryService`, `KakuyomuNovelRepository.addToLibrary` を捨てる）
- [ ] **Q-CROSS-007** — `RateLimiter` API を novel-library 版に統一
- [ ] **Q-CROSS-011** — `MediaSession` sealed の物理配置を `part of` で `core/media/` に集約
- [ ] **Q-CROSS-014** — Riverpod v3 + codegen に統一（`riverpod_generator` を dev_deps に追加）
- [ ] **Q-CROSS-015** — narou-reader の `episode_resume_points` を `novel_bookmarks` に修正
- [ ] **Q-CROSS-016** — `reader_settings` テーブルを廃止、`app_settings` に統合
- [ ] **Q-NOV-001** — `PageSession` を v0.1 から外す（novel-library の `media-session` MODIFIED を削除）
- [ ] **Q-NAR-002** — なろう本文取得は実質 HTML パースになる事実を ADR-0001 に追記するか別 ADR を立てるか
- [ ] **Q-GAP-001** — `add-error-ux-infra` を v0.1 範囲で別 change として起こすか
- [ ] **Q-GAP-002** — `riverpod_generator` を dev_dependencies に追加

### MEDIUM-priority for user

- [ ] Q-CROSS-003 — `SiteConsentRepository` の API シグネチャを統一
- [ ] Q-CROSS-004 — `NovelRepository` のメソッド名を `fetchWork` / `fetchEpisodes` / `fetchEpisodeBody` に統一
- [ ] Q-CROSS-008 — kakuyomu max retries を 6 に統一
- [ ] Q-CROSS-009 — `robots.txt` TTL を 24h に統一
- [ ] Q-CROSS-010 — 小説作品を `recent_items` に乗せるか
- [ ] Q-CROSS-012 — `EpisodeId` を sealed 化（int + string ハイブリッド）
- [ ] Q-CROSS-013 — `HomeScreen` をセクションレジストリ方式に（ADR-0003 候補）
- [ ] Q-CROSS-017 — AndroidManifest 累積編集の冪等性方針
- [ ] Q-CROSS-018 — macOS entitlements Debug/Release 両対応の明示
- [ ] Q-CROSS-019 — `package_info_plus` 冪等追加
- [ ] Q-CROSS-020 — `url_launcher` 冪等追加
- [ ] Q-AUD-001 — macOS audio entitlement のキー名訂正
- [ ] Q-AUD-002 — アートワーク placeholder asset の用意
- [ ] Q-NOV-002 — `WorkQuery` 基底 + `NarouSearchOptions` の継承パターン
- [ ] Q-NAR-003 — R18 同意取消時の R18 キャッシュ削除動作
- [ ] Q-KAK-001 — カクヨム任意キーワード検索を諦めるか
- [ ] Q-KAK-002 — HTML パース失敗時は外部ブラウザに倒す
- [ ] Q-KAK-003 — カクヨム HTML fixture をテストに含める
- [ ] Q-SET-001 — drift migration v2 → v3 テスト

### LOW-priority (cosmetic / future)

- [ ] Q-NAR-001 — R18 consent vs scraping consent の意味論分離（別テーブル化検討）
- [ ] Q-SET-002 — 設定値リアルタイム反映の購読パターン明文化
- [ ] Q-GAP-003 — `THIRD_PARTY_NOTICES.md` の `webfeed` → `webfeed_revised` 表記修正
- [ ] Q-GAP-004 — about-screen の LGPL セクション必須表示テスト
- [ ] Q-RISK-001 — iOS 対応時の libmpv 取り扱い（v0.2 で ADR）
- [ ] Q-UX-001 — i18n skeleton の導入タイミング

---

## Applied Edits

⚠️ **このセクションは現時点で空です**。サブエージェントが GRILL-REPORT.md 書き出し直前で stall したため、HIGH 自動編集は実行していません。

各 question の `Resolved: [ ]` を解決する際は、artifact 編集を行ったら以下のフォーマットで追記してください:

```
### Edit #N (motivated by Q-XXX-NNN)
- **File**: openspec/changes/.../...
- **Diff summary**: (1〜2 行)
- **Before**: (該当ブロック抜粋)
- **After**: (該当ブロック抜粋)
```

---

## Re-entry instructions

To continue grilling in a future session:

1. Read this file end-to-end.
2. For each unresolved question in `## Open Questions Index`, decide:
   - **Apply my answer as-is**: edit the relevant artifact, append an `Applied Edit` entry, check `[x]` the question.
   - **Disagree with my answer**: append `**User answer**:` to the question and explain. Then edit accordingly.
   - **Need more grilling**: append a new question with suffix `-rev2` (e.g. `Q-CROSS-001-rev2`).
3. After resolving a batch, regenerate the `## Summary` and `## Open Questions Index` tables.
4. New questions discovered during grilling go in the same category with the next available number.

### Suggested re-entry prompt for the next session

```
docs/GRILL-REPORT.md の Open Questions Index を上から順に解決してください。
HIGH-priority から着手し、各 question について:
  - Resolved を [x] にする
  - 該当 artifact を編集する場合は Applied Edits に Edit #N を追記する
  - 私の判断が必要な question は AskUserQuestion で聞いてください
```

---

## Status note

このレポートは Opus 4.7 サブエージェントの分析結果（40 件超の指摘）を salvage して整形した
ものです。サブエージェントは最終 Write 直前で stream watchdog timeout (600s) により停止
しました。分析の網羅性は維持していますが、より深い grill が必要な分野（特に CI 自動化、
テストカバレッジ、各 spec の Requirement の冗長性チェック）は次回 self-grill で扱うことを
推奨します。

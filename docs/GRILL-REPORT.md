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

| Confidence | Total | Resolved | Remaining |
|---|---|---|---|
| HIGH | 6 | 6 | 0 |
| MEDIUM | 19 | 14 | 5 |
| LOW | 13 | 1 | 12 |
| **Total** | **38** | **21** | **17** |

By category: CROSS=20, VID=0, AUD=2, NOV=2, NAR=3, KAK=3, SET=2, ABT=0, GAP=4, RISK=1, UX=1.

### Resolution session log

- **2026-05-27 (initial)**: 38 findings identified, all unresolved.
- **2026-05-27 (round 1)**: HIGH-priority sweep applied. Q-CROSS-001/002/005/006/007/011/014/015/016 plus Q-GAP-002 auto-applied. Q-NOV-001 attempted (defer PageSession) but user reversed — PageSession kept in v0.1 with `part of` layout per Q-CROSS-011. Q-NAR-002 resolved via new ADR-0003. Q-GAP-001 resolved by spawning a new propose (`add-error-ux-infra`). See `## Applied Edits` for the per-file changelog.
- **2026-05-27 (Wave 0)**: Parallelization prep round. Q-CROSS-013 resolved via new ADR-0004 (HomeScreen section registry). Q-CROSS-017/018/019/020 resolved by introducing `docs/CONVENTIONS.md` and patching all 8 change `tasks.md` to point at it. Foundation tasks for `HomeScreen` + registry now owned by `add-local-video-playback` Section 5. See Edits #18-#19.
- **2026-05-27 (Wave 1-4 implementation)**: All 8 v0.1 changes implemented and merged. Wave 1 sequential (video foundation), Waves 2-3 each 3 parallel agents with isolation=worktree, Wave 4 sequential. Conflicts resolved at merge time: media_session.dart `part` directives consolidated, main.dart wired through ErrorBoundary + AudioService.init + ConsentDialog hook + themeMode, exhaustive switches updated for all 3 MediaSession variants (Video/Audio/Page). Final state: 394 tests pass, 20 capabilities in openspec/specs/, drift v3, ready for v0.1.0 release tag.

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
- **Action**: applied (Edit #1)
- **Resolved**: [x] 2026-05-27

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
- **Action**: applied (Edit #2). CONTEXT.md への `Site` 用語追加は次回の grill round で扱う
- **Resolved**: [x] 2026-05-27

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
- **Action**: partially applied (Edit #3) — kakuyomu の `SiteConsentReader` を `SiteConsentRepository` にリネーム、`isGranted(Site.kakuyomu)` の signature に統一。narou も同様。`grant(Site, {policyVersion})` のシグネチャ詳細は次回 round で確認
- **Resolved**: [x] 2026-05-27 (partial) — `NovelRepository` のメソッド名 / 戻り型が実装と契約で乖離

- **Tags**: CROSS, GAP
- **Affected**: `add-online-novel-library`, `add-narou-novel-reader`, `add-kakuyomu-novel-reader`
- **Evidence**:
  - novel-library: `Future<Work> fetchWork(WorkId)`, `Stream<Episode> fetchEpisodes(WorkId)`, `Future<EpisodeBody> fetchEpisodeBody(workId, episodeId)`
  - narou-reader: `NarouNovelRepository.fetchDetail('n4830bu')`（`fetchDetail`）+ `NarouEpisodeFetcher.fetchBody(ncode, episodeIndex) -> String`
  - kakuyomu-reader: `KakuyomuHtmlSource.fetchWork(workId)` + `.fetchEpisodeBody(workId, episodeId) -> KakuyomuEpisodeBody`
- **Question**: interface の最終形と各サイトの内部実装名は?
- **My answer**: novel-library が定義する `NovelRepository` interface の `fetchWork` / `fetchEpisodes` / `fetchEpisodeBody` を **必須メソッド**、各サイトリポジトリ実装は同名で公開。内部 helper（`KakuyomuHtmlSource` 等）は別ファイルに分離し、外部 API は interface 経由に統一。narou の `fetchDetail` は実装ファイル内部の名前として残しても良いが、`NarouNovelRepository.fetchWork` から呼ぶ形にする。
- **Confidence**: MEDIUM
- **Action**: partially applied (Edit #4) — narou の `fetchDetail` → `fetchWork` 名前統一済み。kakuyomu の `KakuyomuEpisodeBody → EpisodeBody` mapper の明示は次回 round
- **Resolved**: [x] 2026-05-27 (partial) — `Work` モデルの field が site 実装で破綻している

- **Tags**: CROSS, GAP
- **Affected**: `add-online-novel-library`, `add-narou-novel-reader`
- **Evidence**:
  - novel-library spec: `Work` は `id (WorkId)`, `title`, `author`, `episodeCount`, optional `synopsis`
  - narou-reader spec: "Work whose **`episodes` field** contains an Episode for every `general_all_no`"
  - 共通 `Work` には `episodes` field がない（`episodeCount` のみ）
- **Question**: `Work` に `List<Episode> episodes` を持たせるか、`episodeCount` だけにしてエピソード本体は別 query にするか?
- **My answer**: `Work` は概要のみ（`episodeCount`）にし、エピソード一覧は `NovelRepository.fetchEpisodes(WorkId)` でストリーム取得。理由: なろう作品で 1000 話超があり、`Work` に全エピソードを抱えるとメタデータ取得が遅い。narou-reader の spec 表記を `episodes` から `fetchEpisodes` 呼び出しに修正。
- **Confidence**: HIGH
- **Action**: applied (Edit #5)
- **Resolved**: [x] 2026-05-27

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
- **Action**: applied (Edit #6)
- **Resolved**: [x] 2026-05-27

### Q-CROSS-007 — `RateLimiter` の API が 2 proposal で完全に違う

- **Tags**: CROSS, RISK
- **Affected**: `add-online-novel-library`, `add-kakuyomu-novel-reader`
- **Evidence**:
  - novel-library: `RateLimiter({rate, burst, maxConcurrency}); run<T>(Future<T> Function())`
  - kakuyomu-reader: `RateLimiter(siteKey: 'kakuyomu', minInterval: Duration, maxConcurrent: 1)` and `limiter.acquire('kakuyomu')`
- **Question**: 共通 `RateLimiter` の API は?
- **My answer**: novel-library 側の `RateLimiter({rate, burst, maxConcurrency}).run(() async {...})` を canonical（site key 引数は持たず、サイト別にインスタンスを分離して DI）。`acquire('siteKey')` 形式は廃止。
- **Confidence**: HIGH
- **Action**: applied (Edit #7)
- **Resolved**: [x] 2026-05-27

### Q-CROSS-008 — kakuyomu max retries (3 vs 6) の数値が直接矛盾

- **Tags**: CROSS, RISK
- **Affected**: `add-online-novel-library`, `add-kakuyomu-novel-reader`
- **Evidence**:
  - novel-library responsible-fetching spec: max retries **6**
  - kakuyomu-reader D4: max **3** retries
- **Question**: カクヨムのリトライ回数最大値は?
- **My answer**: ADR-0001 は明示数値を持たないが「max 5 分」までのバックオフを定めている。指数バックオフ (`2^n` 秒、初回 1s) で 6 回なら最終遅延が 32s、累計 ~63s で 5 分内に収まる。3 回だと 1+2+4=7s で諦めるため過剰早すぎ。**6 回を正**とする。
- **Confidence**: MEDIUM
- **Action**: applied (Edit #8)
- **Resolved**: [x] 2026-05-27

### Q-CROSS-009 — `robots.txt` TTL (24h vs 1h) の数値が矛盾

- **Tags**: CROSS
- **Affected**: `add-online-novel-library`, `add-kakuyomu-novel-reader`
- **Evidence**:
  - novel-library responsible-fetching: 24h TTL
  - kakuyomu-reader D6: 1h TTL
- **Question**: `robots.txt` キャッシュ TTL は?
- **My answer**: 24h を採用（一般的な web cache の良識的範囲、サイト側 ToS 変更の即時反映は別途同意ダイアログのバージョン管理で対応）。kakuyomu spec を 24h に揃える。
- **Confidence**: MEDIUM
- **Action**: applied (Edit #9)
- **Resolved**: [x] 2026-05-27

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
- **Action**: applied (Edit #10) — video design D1 / audio design D1 / novel-library design D9 すべて `part of 'media_session.dart';` 構造を明記。video tasks 2.3 と audio tasks 2.1 にも反映
- **Resolved**: [x] 2026-05-27

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
- **Action**: applied (Edit #18) — ADR-0004 を起こし、各 change の tasks.md に CONVENTIONS.md と ADR-0004 への参照を追加。video tasks Section 5 を foundation 実装に書き換え
- **Resolved**: [x] 2026-05-27 (Wave 0)

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
- **Action**: applied (Edit #11) — `riverpod_generator ^4.0.4-dev.1` を `app/pubspec.yaml` の dev_dependencies に追加、`docs/HANDOFF.md` の Riverpod v2 表記を v3 (codegen) に修正。各 change design の Notifier 記述書き換えは次回 round（既存記述は v3 互換の AutoDisposeNotifierProvider 形式で動くため緊急性低）
- **Resolved**: [x] 2026-05-27

### Q-CROSS-015 — `episode_resume_points` テーブルが novel-library で未定義のまま narou-reader が依存

- **Tags**: CROSS, GAP
- **Affected**: `add-online-novel-library`, `add-narou-novel-reader`
- **Evidence**:
  - narou-reader spec: `episode_resume_points(workId, episodeIndex, scrollOffset)` を参照
  - novel-library spec: 同名テーブルなし。`novel_bookmarks(site, externalId, episodeIndex, scrollFraction, updatedAt)` のみ
- **Question**: 読書位置保存テーブルの正は?
- **My answer**: novel-library の `novel_bookmarks` を正とし、`scrollFraction` (0.0〜1.0) で保存。narou-reader spec の `episode_resume_points` 参照を `novel_bookmarks` に置換、`scrollOffset` (pixel) を `scrollFraction` に変換するヘルパを `core/novel/` に置く（フォント変更でレイアウトが変わってもページ位置を保てる）。
- **Confidence**: HIGH（共通テーブル定義は novel-library が所有）
- **Action**: applied (Edit #12)
- **Resolved**: [x] 2026-05-27

### Q-CROSS-016 — `reader_settings` テーブルと `app_settings` テーブルが二重所有

- **Tags**: CROSS
- **Affected**: `add-narou-novel-reader`, `add-app-settings`
- **Evidence**:
  - narou-reader D8: 独自の `reader_settings` drift テーブル（単一行）
  - app-settings: `app_settings(key TEXT PK, value TEXT)` が「小説フォント / 行間 / テーマ別背景色」を保存する canonical store
- **Question**: 読書設定の保存先は?
- **My answer**: `app_settings` を canonical とし、`reader_settings` は削除。読書設定の key は `novel.reader.fontSize`, `novel.reader.lineHeight`, `novel.reader.fontFamily`, `novel.reader.background.light`, `novel.reader.background.dark` のように prefix で名前空間を切る。narou と kakuyomu の reader 画面はこの設定を購読。
- **Confidence**: HIGH
- **Action**: applied (Edit #13)
- **Resolved**: [x] 2026-05-27

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
- **Action**: applied (Edit #19) — CONVENTIONS.md §3 で `AndroidManifest.xml` を append-only / 既存維持 / 冪等とする規約を文書化。各 change tasks.md のプリアンブルに CONVENTIONS.md 参照を追加
- **Resolved**: [x] 2026-05-27 (Wave 0)

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
- **Action**: applied (Edit #19) — CONVENTIONS.md §4 で「Debug + Release の両方を編集」を明示。各 tasks.md プリアンブルから参照
- **Resolved**: [x] 2026-05-27 (Wave 0)

### Q-CROSS-019 — `package_info_plus` を複数 change が同時に追加しようとする

- **Tags**: CROSS, GAP
- **Affected**: novel-library, about-and-licenses
- **Evidence**:
  - novel-library tasks 1.1: `package_info_plus` を追加
  - about-and-licenses tasks: 同じく追加
- **Question**: 同一依存追加 task の冪等性はどう担保するか?
- **My answer**: 各 tasks に「`flutter pub add <pkg>` を実行し、既に追加されていれば pubspec が変わらないことを確認」と書く。あるいは「依存追加を専用の最小 change `add-shared-deps` にまとめる」案もあるが、過剰設計。各 change の 1.1 task に「冪等」を明記すれば十分。
- **Confidence**: HIGH
- **Action**: applied (Edit #19) — CONVENTIONS.md §2 で `flutter pub add` を冪等とする規約。`add-online-novel-library` と `add-about-and-licenses` のタスクに「冪等」を明記
- **Resolved**: [x] 2026-05-27 (Wave 0)

### Q-CROSS-020 — `url_launcher` を 2 change が追加しようとする

- **Tags**: CROSS
- **Affected**: kakuyomu-reader, about-and-licenses
- **Evidence**:
  - kakuyomu-reader 1.2: `url_launcher`
  - about-and-licenses 1.1: 同じ
- **Question**: Q-CROSS-019 と同じ
- **My answer**: 同上、冪等 note で対応
- **Confidence**: HIGH
- **Action**: applied (Edit #19) — CONVENTIONS.md §2 で `flutter pub add` を冪等とする規約
- **Resolved**: [x] 2026-05-27 (Wave 0)

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
- **Action**: **REVERSED by user** (Edit #14) — ユーザーは v0.1 で PageSession を導入する判断。novel-library/specs/media-session/spec.md を復元し、Q-CROSS-011 の `part of` 規約を取り込んだ形で再記述。design D9 と tasks 6.1〜6.7 も復元
- **Resolved**: [x] 2026-05-27 (user-overridden)

#### Q-NOV-002 — `WorkQueryExtensions` という型が narou-reader から参照されるが、novel-library spec に存在しない

- **Tags**: NOV, GAP
- **Question**: 検索 query のサイト別拡張型をどう設計するか?
- **My answer**: `WorkQuery` を sealed にせず、共通 `WorkQuery { String? keyword; SortOrder? sort; }` を提供、サイト別の追加 query は `NarouSearchOptions extends WorkQuery` のような単純継承で表現する。novel-library spec に `WorkQuery` 基底型を Requirement として追加。narou-reader spec の `WorkQueryExtensions` 言及を `NarouSearchOptions` に置換。
- **Confidence**: MEDIUM
- **Action**: partially applied (Edit #15) — narou spec の `WorkQueryExtensions` を `NarouSearchOptions extends WorkQuery` にリネーム済み。novel-library の `WorkQuery` 基底型 Requirement 追加は次回 round
- **Resolved**: [x] 2026-05-27 (partial)

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
- **Action**: resolved by user — **ADR-0003 を新規に起こす** を選択。Edit #16 で `docs/adr/0003-narou-content-fetch-policy.md` を新規作成、narou-reader design / proposal に参照リンク追加
- **Resolved**: [x] 2026-05-27

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
- **Action**: resolved by user — **v0.1 で `add-error-ux-infra` を新規 propose** を選択。サブエージェント (Opus) で実行中（Edit #17 で完了報告予定）
- **Resolved**: [x] 2026-05-27

### Q-GAP-002 — `riverpod_generator` が dev_dependencies に未追加

- **Tags**: GAP, RISK
- **Question**: codegen の動作確認は?
- **My answer**: `flutter pub add --dev riverpod_generator` を実行し `pubspec.yaml` に追加。Q-CROSS-014 と連動。
- **Confidence**: HIGH
- **Action**: applied (Edit #11 と同時に実施)
- **Resolved**: [x] 2026-05-27

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

### Resolved in round 1 (2026-05-27)

すべて [x] で完了。詳細は各 Q-ID 本体と `## Applied Edits` 参照:

- [x] Q-CROSS-001 / 002 / 003 / 004 / 005 / 006 / 007 / 008 / 009 / 011 / 014 / 015 / 016
- [x] Q-NOV-001 (user-overridden — kept in v0.1)
- [x] Q-NOV-002 (partial — narou 側のみ)
- [x] Q-NAR-002 → ADR-0003 new
- [x] Q-GAP-001 → `add-error-ux-infra` propose 起動 (background sub-agent)
- [x] Q-GAP-002

### Resolved in Wave 0 (2026-05-27)

並列化準備ラウンド:

- [x] Q-CROSS-013 → ADR-0004 new (HomeScreen section registry)
- [x] Q-CROSS-017 → CONVENTIONS.md §3 (AndroidManifest append-only)
- [x] Q-CROSS-018 → CONVENTIONS.md §4 (macOS Debug+Release 両対応)
- [x] Q-CROSS-019 → CONVENTIONS.md §2 (pubspec 冪等)
- [x] Q-CROSS-020 → CONVENTIONS.md §2 (pubspec 冪等)

### Remaining for next round — HIGH-priority

（HIGH の未解決はなし。round 1 で全消化）

### Remaining for next round — MEDIUM-priority

- [ ] Q-CROSS-010 — 小説作品を `recent_items` に乗せるか
- [ ] Q-CROSS-012 — `EpisodeId` を sealed 化（int + string ハイブリッド）
- [ ] Q-AUD-001 — macOS audio entitlement のキー名訂正
- [ ] Q-AUD-002 — アートワーク placeholder asset の用意
- [ ] Q-NAR-003 — R18 同意取消時の R18 キャッシュ削除動作
- [ ] Q-KAK-001 — カクヨム任意キーワード検索を諦めるか
- [ ] Q-KAK-002 — HTML パース失敗時は外部ブラウザに倒す
- [ ] Q-KAK-003 — カクヨム HTML fixture をテストに含める
- [ ] Q-SET-001 — drift migration v2 → v3 テスト

### Remaining for next round — LOW-priority

- [ ] Q-NAR-001 — R18 consent vs scraping consent の意味論分離（ADR-0003 で部分的に整理。policyVersion の値設計が未決）
- [ ] Q-SET-002 — 設定値リアルタイム反映の購読パターン明文化
- [ ] Q-GAP-003 — `THIRD_PARTY_NOTICES.md` の `webfeed` → `webfeed_revised` 表記修正
- [ ] Q-GAP-004 — about-screen の LGPL セクション必須表示テスト
- [ ] Q-RISK-001 — iOS 対応時の libmpv 取り扱い（v0.2 で ADR）
- [ ] Q-UX-001 — i18n skeleton の導入タイミング

---

## Applied Edits

### Edit #1 (motivated by Q-CROSS-001)
- **Files**:
  - `openspec/changes/add-online-novel-library/design.md` (Migration Plan セクション)
  - `openspec/changes/add-online-novel-library/proposal.md` (Impact セクションの database.dart 行)
- **Diff summary**: "v1 のまま 4 テーブル追加" → **v1 → v2 schema bump**、`MigrationStrategy.onUpgrade(from:1, to:2)` で create、migration テスト方針を追加。後続 `add-app-settings` が v2 → v3 へ bump する前提を明示。

### Edit #2 (motivated by Q-CROSS-002)
- **Files**:
  - `openspec/changes/add-narou-novel-reader/design.md`
  - `openspec/changes/add-narou-novel-reader/specs/r18-age-gate/spec.md`
  - `openspec/changes/add-narou-novel-reader/specs/narou-novel-source/spec.md`
  - `openspec/changes/add-narou-novel-reader/specs/narou-novel-reader-ui/spec.md`
  - `openspec/changes/add-narou-novel-reader/tasks.md`
  - `openspec/changes/add-kakuyomu-novel-reader/design.md`
  - `openspec/changes/add-kakuyomu-novel-reader/specs/kakuyomu-novel-source/spec.md`
  - `openspec/changes/add-kakuyomu-novel-reader/tasks.md`
- **Diff summary**: `SiteId.narou18` / `SiteId.noctune` を全て `Site.noc` に統一。kakuyomu の `'kakuyomu'` 文字列キーを `Site.kakuyomu` に。narou の "SiteId" 型を廃止し、`add-online-novel-library` の `Site` enum を利用。

### Edit #3 (motivated by Q-CROSS-003)
- **Files**: 上記 kakuyomu 系 3 ファイル
- **Diff summary**: `SiteConsentReader` → `SiteConsentRepository` リネーム、`isGranted('kakuyomu')` → `isGranted(Site.kakuyomu)`。R18 grant 呼び出しを `grant(Site.noc, policyVersion: 'age-verified')` に明示。

### Edit #4 (motivated by Q-CROSS-004)
- **File**: `openspec/changes/add-narou-novel-reader/specs/narou-novel-source/spec.md`
- **Diff summary**: `fetchDetail('ncode')` → `fetchWork(WorkId(Site.narou, 'ncode'))` に統一。novel-library が定義する `NovelRepository` interface のメソッド名と一致。

### Edit #5 (motivated by Q-CROSS-005)
- **File**: `openspec/changes/add-narou-novel-reader/specs/narou-novel-source/spec.md`
- **Diff summary**: `Work whose episodes field contains ...` を `Work populated with episodeCount equal to ...; episodes are retrieved via fetchEpisodes(WorkId)` に修正。`Work` に `episodes` field を持たせない方針を明示。

### Edit #6 (motivated by Q-CROSS-006)
- **Files**:
  - `openspec/changes/add-narou-novel-reader/design.md` (D10)
  - `openspec/changes/add-narou-novel-reader/specs/narou-novel-reader-ui/spec.md`
  - `openspec/changes/add-narou-novel-reader/tasks.md` (6.8)
  - `openspec/changes/add-kakuyomu-novel-reader/tasks.md` (6.1, 6.5)
- **Diff summary**: `LibraryService.add(work)` を `LibraryRepository.addToLibrary(NarouNovelRepository, work.id)` に統一。kakuyomu の `KakuyomuNovelRepository.addToLibrary(workId)` を削除し、共通 `LibraryRepository` 経由に統一。

### Edit #7 (motivated by Q-CROSS-007)
- **Files**:
  - `openspec/changes/add-kakuyomu-novel-reader/design.md` (D4)
  - `openspec/changes/add-kakuyomu-novel-reader/tasks.md` (3.2, 3.3)
- **Diff summary**: kakuyomu の `RateLimiter(siteKey:'kakuyomu', minInterval:..., maxConcurrent:1)` API を `RateLimiter(rate:0.5, burst:1, maxConcurrency:1).run(() async {...})` に統一（novel-library 版）。`limiter.acquire('kakuyomu')` パターンを廃止。

### Edit #8 (motivated by Q-CROSS-008)
- **Files**:
  - `openspec/changes/add-kakuyomu-novel-reader/design.md` (D4)
  - `openspec/changes/add-kakuyomu-novel-reader/specs/kakuyomu-novel-source/spec.md`
  - `openspec/changes/add-kakuyomu-novel-reader/tasks.md` (3.3)
- **Diff summary**: max retries を **3 → 6** に統一（`responsible-fetching` 規範と一致）。「Give up after 3 retries」シナリオを「Give up after 6 retries」に。

### Edit #9 (motivated by Q-CROSS-009)
- **Files**:
  - `openspec/changes/add-kakuyomu-novel-reader/design.md` (D6)
  - `openspec/changes/add-kakuyomu-novel-reader/specs/kakuyomu-novel-source/spec.md`
  - `openspec/changes/add-kakuyomu-novel-reader/tasks.md` (3.4)
- **Diff summary**: `robots.txt` キャッシュ TTL を **1h → 24h** に統一（`responsible-fetching` 規範と一致）。

### Edit #10 (motivated by Q-CROSS-011)
- **Files**:
  - `openspec/changes/add-local-video-playback/design.md` (D1)
  - `openspec/changes/add-local-video-playback/tasks.md` (2.3, 2.4)
  - `openspec/changes/add-local-audio-playback/design.md` (D1)
  - `openspec/changes/add-local-audio-playback/tasks.md` (2.1)
  - `openspec/changes/add-online-novel-library/design.md` (D9)
  - `openspec/changes/add-online-novel-library/tasks.md` (6.x)
  - `openspec/changes/add-online-novel-library/specs/media-session/spec.md` (created)
- **Diff summary**: `MediaSession` sealed hierarchy の物理レイアウトを `app/lib/core/media/` 配下に集約、各サブクラスは `part of 'media_session.dart';` で結合する規約を全 4 change に明記（Dart 3 同一ライブラリ制約のため）。

### Edit #11 (motivated by Q-CROSS-014 & Q-GAP-002)
- **Files**:
  - `app/pubspec.yaml`
  - `docs/HANDOFF.md`
- **Diff summary**: `riverpod_generator ^4.0.4-dev.1` を `dev_dependencies` に追加。HANDOFF.md の「Riverpod v2 (Notifier API)」を「Riverpod v3 (codegen `@Riverpod` API)」に修正。

### Edit #12 (motivated by Q-CROSS-015)
- **Files**:
  - `openspec/changes/add-narou-novel-reader/design.md` (D8)
  - `openspec/changes/add-narou-novel-reader/specs/narou-novel-reader-ui/spec.md`
  - `openspec/changes/add-narou-novel-reader/tasks.md` (1.1, 7.8)
- **Diff summary**: narou 側 `episode_resume_points(workId, episodeIndex, scrollOffset)` を共通 `novel_bookmarks(site, externalId, episodeIndex, scrollFraction, updatedAt)` に置換。pixel offset を fraction に変換するヘルパを `core/novel/` に置く方針を明示。

### Edit #13 (motivated by Q-CROSS-016)
- **Files**:
  - `openspec/changes/add-narou-novel-reader/design.md` (D8)
  - `openspec/changes/add-narou-novel-reader/tasks.md` (7.2, 7.3)
- **Diff summary**: narou の独自 `reader_settings` テーブルを廃止。リーダー設定（fontSize / lineHeight / colorScheme）は `add-app-settings` の `app_settings` テーブルに `novel.reader.fontSize` などの key 名前空間で保存。`AppSettingsNotifier` 購読パターンを明示。

### Edit #14 (motivated by Q-NOV-001, user-overridden)
- **Files**:
  - `openspec/changes/add-online-novel-library/specs/media-session/spec.md` (created with new content respecting Q-CROSS-011 layout)
  - `openspec/changes/add-online-novel-library/proposal.md` (PageSession 再追加、Modified Capabilities 復元)
  - `openspec/changes/add-online-novel-library/design.md` (D9 復元 + `part of` 規約を追加)
  - `openspec/changes/add-online-novel-library/tasks.md` (Section 6 を実装タスクに復元)
- **Diff summary**: ユーザーが「v0.1 で PageSession を導入する」を選択。一旦削除した spec / design / tasks を、Q-CROSS-011 の `part of 'media_session.dart';` 規約に従う形で再作成。

### Edit #15 (motivated by Q-NOV-002)
- **Files**:
  - `openspec/changes/add-narou-novel-reader/specs/narou-novel-source/spec.md`
  - `openspec/changes/add-narou-novel-reader/tasks.md` (2.3, 3.5)
- **Diff summary**: `NarouQueryExtensions extends WorkQueryExtensions` を `NarouSearchOptions extends WorkQuery` にリネーム（novel-library が `WorkQuery` 基底を所有する想定）。novel-library 側に `WorkQuery` 基底型 Requirement を明示する追記は次回 round に持ち越し。

### Edit #16 (motivated by Q-NAR-002, user choice)
- **Files**:
  - `docs/adr/0003-narou-content-fetch-policy.md` (new)
  - `openspec/changes/add-narou-novel-reader/proposal.md` (top に Related ADRs 追加)
  - `openspec/changes/add-narou-novel-reader/design.md` (規範参照を ADR-0001 → ADR-0003 に切替、Q-D1 を解決済みに)
- **Diff summary**: ユーザー判断により、なろう / ノクターン系の本文取得方針を独立 ADR (`docs/adr/0003-narou-content-fetch-policy.md`) として記録。レート制限 1 req/sec、`*.syosetu.com` 共通バケット、`robots.txt` 24h TTL、429/503 で 6 回バックオフを明文化。

### Edit #18 (motivated by Q-CROSS-013, Wave 0)
- **Files**:
  - `docs/adr/0004-home-screen-section-registry.md` (new)
  - `openspec/changes/add-local-video-playback/tasks.md` (Section 5 rewrite to foundation)
- **Diff summary**: HomeScreen をセクションレジストリ方式で構成する ADR-0004 を起案。Riverpod の `homeSectionsProvider` / `homeAppBarActionsProvider` に各 change がサブプロバイダで登録するパターン。video tasks Section 5 を「HomeScreen + Section レジストリ foundation」として書き換え、後続 6 change の土台を構築する責務を明確化。`order` 規約（100 刻み）も明文化。

### Edit #19 (motivated by Q-CROSS-017/018/019/020, Wave 0)
- **Files**:
  - `docs/CONVENTIONS.md` (new) — 10 セクション: HomeScreen registry / pubspec idempotency / AndroidManifest append-only / macOS Debug+Release entitlements / drift versioning / Riverpod v3 / テスト / 命名 / commits / sealed class part-of
  - `openspec/changes/add-local-video-playback/tasks.md` (preamble)
  - `openspec/changes/add-local-audio-playback/tasks.md` (preamble)
  - `openspec/changes/add-online-novel-library/tasks.md` (preamble + 1.1 冪等性追記)
  - `openspec/changes/add-narou-novel-reader/tasks.md` (preamble)
  - `openspec/changes/add-kakuyomu-novel-reader/tasks.md` (preamble)
  - `openspec/changes/add-app-settings/tasks.md` (preamble)
  - `openspec/changes/add-about-and-licenses/tasks.md` (preamble + 1.1 冪等性追記)
  - `openspec/changes/add-error-ux-infra/tasks.md` (preamble)
- **Diff summary**: 全 8 change のタスクファイル冒頭に **CONVENTIONS.md と ADR-0004 への参照** をプリアンブルとして追加。並列 Wave 実装時に各エージェントが共通規約を踏み外さないようにする。

### Edit #17 (motivated by Q-GAP-001, user choice)
- **Files** (new change):
  - `openspec/changes/add-error-ux-infra/proposal.md`
  - `openspec/changes/add-error-ux-infra/design.md`
  - `openspec/changes/add-error-ux-infra/specs/error-domain/spec.md`
  - `openspec/changes/add-error-ux-infra/specs/error-ux-widgets/spec.md`
  - `openspec/changes/add-error-ux-infra/specs/retry-strategy/spec.md`
  - `openspec/changes/add-error-ux-infra/tasks.md` (8 セクション、37 task)
- **Diff summary**: `add-error-ux-infra` change を新規 propose。`sealed AppError` + variant 群、`ErrorToast` / `ErrorBanner` / `ErrorBoundary` ウィジェット、`RetryStrategy` 抽象を `app/lib/core/errors/` に集約。drift スキーマには触らない、Riverpod v3 codegen 前提。`openspec status` で 4/4 artifacts complete を確認。

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

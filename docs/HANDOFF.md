# GeekPlayer — ハンドオフ資料

このドキュメントは、後続の人 / 後続のエージェントが **対話履歴を読まずに**
すぐ作業を再開できるよう、リポジトリの現状・進捗・次の作業を集約したものです。

最終更新: 2026-06-21（**active changes は 3 件。次は PR / archive / Linux 実機確認の整理**）。

---

## 0. ドキュメントマップ

| 質問 | ファイル |
|---|---|
| 何を作っているの? | このファイル §1〜§3 |
| 開発環境のセットアップは? | このファイル §4 |
| 過去の設計判断と理由は? | [`docs/adr/`](adr/) (0001〜0007) |
| コーディング規約は? | [`docs/CONVENTIONS.md`](CONVENTIONS.md) |
| v0.1 実装手順（履歴, Wave / worktree） | [`docs/IMPLEMENTATION-PLAN.md`](IMPLEMENTATION-PLAN.md) |
| リリース手順 / CI 配布ビルド | [`docs/release.md`](release.md) |
| 解決済み・未解決の設計論点 | [`docs/GRILL-REPORT.md`](GRILL-REPORT.md) |
| ロードマップ (v0.1 / v0.2 / v1.0) | [`docs/roadmap.md`](roadmap.md) |
| ドメイン用語集 | [`CONTEXT.md`](../CONTEXT.md) |
| AI ハーネス用プロジェクトルール | [`CLAUDE.md`](../CLAUDE.md) / [`AGENTS.md`](../AGENTS.md) |
| GitHub Issue / OpenSpec / Codex の役割分担 | [`docs/WORKFLOW.md`](WORKFLOW.md) |

## 1. プロジェクト一行説明

GeekPlayer は **動画 / 音楽 / 書籍 / 漫画ZIP / オンライン小説**（小説家になろう /
ノクターンノベルズ / カクヨム）を 1 つのアプリで扱う Flutter 製クロスプラットフォーム・
マルチメディアプレイヤー。AI 高画質化機能（Real-ESRGAN + ONNX Runtime）を搭載済み（Experimental、既定 OFF）。

## 2. 現在の権威ある状態 (2026-06-21)

このセクションが **唯一の権威あるベースライン** です。

### リリース

- **最新リリース**: `v0.1.1`（タグ `v0.1.1`、pubspec `0.1.1+2`）
- **配布**: GitHub Releases 自動ビルド（`.github/workflows/release-artifacts.yaml`）
  - `v*` tag push → Windows zip / macOS dmg / Android APK / Linux AppImage の 4 資産を自動添付
  - `workflow_dispatch` → 手動テストビルド（Release 未作成、14 日保存）
- **前バージョン**: `v0.1.0`

### OpenSpec

- **アクティブ changes**: 3 件
  - `ui-phase-2-batch-3-localize-raw-errors-and-format-dates` (13/14) — task 5.1（PR 作成 + GitHub Actions `analyze-and-test` green 確認）のみ pending。
  - `polish-settings-actions-a11y` (18/18) — OpenSpec 上は complete。ただし active のままなので、GitHub 側の PR / merge 状況を確認し、完了済みなら archive する。
  - `release-all-platform-installers` (13/14) — task 5.4（Linux 実機 AppImage 起動確認）のみ pending。物理 Linux 環境が必要で当面未実施。
- **アーカイブ**: 31 件（`openspec/changes/archive/`）
- **capability specs**: 41 件（`openspec/specs/`）

### スタック

| 項目 | 値 |
|---|---|
| Flutter | 3.44 stable (Dart 3.12) |
| 状態管理 | Riverpod v3 (codegen `@Riverpod`) |
| DB | drift SQLite、現行 schema **v6** |
| テーマ | Material 3、`ColorScheme.fromSeed(seedColor: Color(0xFF109A78))`（Teal）、dark-first |
| デザイントークン | `app/lib/core/theme/tokens.dart` (`AppSpacing` / `AppRadius` / `AppBreakpoints` / `AppSizes`) |
| テーマビルダー | `app/lib/core/theme/app_theme.dart` (`buildAppTheme(Brightness)`) |
| CI | 7 ジョブ: `analyze-and-test` + 6 ビルド (android-debug / windows / macos / linux / ios / android-release[tag only]) |
| 対象 OS | macOS / Windows / Android / Linux / iOS・iPadOS |
| 配布 | OSS / GitHub Releases 直配布（ストア配布なし） |
| ライセンス | Apache-2.0（libmpv は LGPL 動的リンク） |
| AI 高画質化 | ONNX Runtime + Real-ESRGAN x4plus_anime_6B、Experimental default-OFF |

### drift schema（v6 確定）

| Version | 導入 change | テーブル |
|---|---|---|
| v1 | `add-local-video-playback` | `playback_positions`, `recent_items` |
| v2 | `add-online-novel-library` | `novel_works`, `novel_episodes`, `novel_bookmarks`, `site_consents` |
| v3 | `add-app-settings` | `app_settings` |
| v4 | `add-pdf-epub-reader` | `book_metadata`, `book_bookmarks` |
| v5 | `add-manga-zip-viewer` | `manga_metadata`, `manga_bookmarks` |
| v6 | `add-media-library` | `media_index`, `watch_history`, `favorites`, `playlists`, `playlist_items` |

### デザインシステム (Phase 1 完了)

- **ブランド色**: Teal seed `#109A78`
- **既定テーマ**: dark-first（`AppSettings.defaults().themeMode == ThemeMode.dark`）
- **テーマビルダー**: `app/lib/core/theme/app_theme.dart` — `buildAppTheme(Brightness)` で `ColorScheme.fromSeed` + M3 コンポーネントテーマを一元管理
- **デザイントークン**: `app/lib/core/theme/tokens.dart` — spacing / radius / breakpoints / sizes を `abstract final class` const で定義
- **テスト**: `app/test/core/theme/app_theme_test.dart`

## 3. リポジトリ構成

```
GeekPlayer/
├── app/                              # Flutter project
│   ├── lib/
│   │   ├── core/                     # di, storage, network, media, theme, consent, ml, novel
│   │   └── features/                 # video, audio, novel, novel_narou, novel_kakuyomu,
│   │                                   library, book, manga, settings, about
│   ├── test/                         # unit + widget tests
│   ├── pubspec.yaml                  # version: 0.1.1+2
│   └── ...                           # android/, ios/, linux/, macos/, windows/
├── docs/
│   ├── adr/                          # 0001〜0007 (全 accepted)
│   ├── roadmap.md                    # v0.1 / v0.2 / v1.0
│   ├── release.md                    # リリース手順 + CI 配布ビルド
│   ├── CONVENTIONS.md                # 開発規約
│   ├── IMPLEMENTATION-PLAN.md        # v0.1 Wave 実装手順（履歴）
│   ├── GRILL-REPORT.md               # 設計論点 Q&A
│   └── HANDOFF.md                    # このファイル
├── openspec/
│   ├── config.yaml                   # context + rules
│   ├── changes/                      # active: 3 / archive/: 31
│   └── specs/                        # 41 capability specs
├── .github/workflows/
│   ├── ci.yaml                       # analyze-and-test + 6 builds
│   └── release-artifacts.yaml        # v* tag → 4-platform release
├── CLAUDE.md / AGENTS.md             # AI ハーネス向け instructions
├── CONTEXT.md                        # ドメイン用語集
├── LICENSE                           # Apache-2.0
├── README.md
└── THIRD_PARTY_NOTICES.md
```

GitHub: **https://github.com/geekjapan/GeekPlayer** (PRIVATE)

## 4. 開発環境

### 重要: ローカルに Flutter/Dart はない

このローカル環境には **Flutter/Dart がインストールされていません**。
`flutter analyze` / `dart format` / `flutter test` はローカルで実行できず、
**GitHub Actions の `analyze-and-test` ジョブが唯一のチェッカー** です。

CI の注意点:
- ゲートは順番に失敗する: (1) `dart format` → (2) `flutter analyze` → (3) `flutter test`。1 つ直すと次のエラーが出る。
- `dart format` は「どのファイルが変わったか」だけ報告し、diff は見せない。
- Dart 3.7+ "tall" formatter は短い multiline コンストラクタを 80 桁以内に折り畳む。手で展開しても CI で戻される。
- `dangling_library_doc_comments` lint: ファイル先頭の `///` doc comment は `library;` ディレクティブが必要。
- デフォルト値を変えるとテストのセンチネル値が壊れる（例: `ThemeMode.dark` がデフォルトになった → テストで "異なる値" として使っていた `ThemeMode.dark` が no-op に）。
- **1 回の push→CI サイクルは約 1.5〜3 分（analyze-and-test）、フルビルドは約 7 分（キャッシュ HIT 時）**。バッチごとに数サイクル見込むこと。

### ツール

- **`gh` CLI** — 認証済み（アカウント: `geekjapan`）
- **`openspec` CLI** — 利用可能
- **Git** — `git` コマンド利用可能

### よく使うコマンド

```bash
# OpenSpec
openspec list --json                              # アクティブ changes
openspec new change "<name>"                      # 新規 change scaffold
openspec status --change "<name>" --json          # artifact 状態
openspec instructions <artifact-id> --change "<name>" --json

# CI / リリース
gh run list -w "CI" -L 5                          # 最近の CI runs
gh pr create --title "..." --body "..."           # PR 作成
git tag v0.1.2 && git push origin v0.1.2          # リリース
```

### スラッシュコマンド（Claude Code / Codex / π 共通）

| コマンド | 用途 |
|---|---|
| `/opsx:explore [topic]` | 思考パートナーモード |
| `/opsx:propose <name>` | 新規 change scaffold + artifact 生成 |
| `/opsx:apply [name]` | tasks.md のチェックボックスを順に実装 |
| `/opsx:archive [name]` | 完了 change をアーカイブ + specs 更新 |

## 5. 確定済みの主要決定

| # | テーマ | 決定 |
|---|---|---|
| Q1 | MVP の境界 | thin + 小説のみリッチ寄り最小 |
| Q2 | v0.1 対象 OS | macOS + Windows + Android |
| Q3 | メディア再生エンジン | ハイブリッド: 動画=`media_kit`(libmpv) / 音楽=`just_audio`+`audio_service` ([ADR-0002](adr/0002-hybrid-media-engine.md)) |
| Q4 | カクヨム本文取得 | HTML パース + 注意書き 4 箇所 ([ADR-0001](adr/0001-online-novel-fetch-policy.md)) |
| Q5 | AI 高画質化ランタイム | ONNX Runtime + EP 一本化、preferred/effective 分離、bicubic CPU floor ([ADR-0007](adr/0007-ai-upscaling-runtime-strategy.md)) |
| Q6 | iOS 配布 | libmpv 継続 + 非ストア配布 ([ADR-0006](adr/0006-ios-media-engine-distribution-policy.md)) |
| Q7 | UI テーマ | Teal seed `#109A78`、M3 `ColorScheme.fromSeed`、dark-first |

その他:
- 配布: OSS / GitHub Releases（App Store / Play Store には出さない）
- ライセンス: Apache-2.0（libmpv は LGPL 動的リンク）
- 状態管理: Riverpod v3 codegen
- UI 言語: ja-first（en ロケール基盤済み、`intl` / ARB）

## 6. changes 一覧（サマリ）

### v0.1 MVP（8 changes — 全アーカイブ済み）

`archive/2026-05-27-*` に保管。capabilities は `openspec/specs/` に確定。

| Change | 主な Capabilities |
|---|---|
| `add-local-video-playback` | local-video-playback, media-session |
| `add-local-audio-playback` | local-audio-playback |
| `add-online-novel-library` | online-novel-library, site-consent, responsible-fetching |
| `add-error-ux-infra` | error-domain, error-ux-widgets, retry-strategy |
| `add-narou-novel-reader` | narou-novel-source, narou-novel-reader-ui, r18-age-gate |
| `add-kakuyomu-novel-reader` | kakuyomu-novel-source, kakuyomu-novel-reader-ui, kakuyomu-resilience |
| `add-app-settings` | app-settings, settings-persistence |
| `add-about-and-licenses` | about-screen, oss-license-notices, lgpl-compliance |

### v0.2 拡張（11 changes — 全アーカイブ済み）

`archive/2026-06-03-*` に保管。

| Change | 役割 |
|---|---|
| `prepare-v0-2-foundation` | ドキュメント整合性・ADR-0006・sequencing 整備 |
| `add-english-localization` | en ロケール基盤・ARB parity test |
| `add-pdf-epub-reader` | PDF/EPUB リーダー (drift v4) |
| `add-manga-zip-viewer` | 漫画 ZIP/CBZ ビューア (drift v5) |
| `add-media-library` | フォルダスキャン・視聴履歴・お気に入り・プレイリスト (drift v6) |
| `expand-ci-and-platforms` | CI ビルドマトリクス + Linux scaffolding |
| `add-auto-update` | GitHub Releases in-app update バナー |
| `expand-auto-update-delivery` | OS 別 DL + install handoff |
| `add-ml-runtime-abstraction` | ML runtime seam (core/ml/) |
| `add-platform-ios` | iOS/iPadOS ビルド + CI smoke |
| `add-ai-image-upscaler` | CPU bicubic upscaler + manga viewer 統合 |

### v1.0 AI 高画質化（6 changes — 全アーカイブ済み）

`archive/2026-06-0X-*` に保管。

| Change | 役割 |
|---|---|
| `refactor-ml-runtime-effective-backend` | preferred/effective + probe + フォールバック |
| `add-onnx-upscaler-runtime` | ORT CPU EP の `OnnxImageUpscaler` |
| `add-upscale-model-distribution` | `ModelRepository` + Experimental 設定 UI |
| `enable-gpu-execution-providers` | CoreML/NNAPI EP + backend 上書き UI |
| `add-android-16kb-page-support` | 16 KB ELF アラインメント監査 + CI ゲート |
| `add-upscale-model-selection` | Real-ESRGAN x4plus_anime_6B + タイリング |

### CI / リリース（4 changes — アーカイブ済み）

| Change | 役割 |
|---|---|
| `enable-ci-auto-triggers` | push/PR トリガー整備 |
| `harden-ci-native-downloads` | ネイティブ資産リトライ + CocoaPods 強制 |
| `cache-ci-native-downloads` | pub-cache / Gradle / CocoaPods キャッシュ |
| `release-all-platform-installers` | 4-platform release (13/14、5.4 Linux 実機=pending) |

### デザイン / UI 修正（2 changes — アーカイブ済み）

| Change | 役割 |
|---|---|
| `add-design-system-foundation` | Teal テーマビルダー + トークン + dark-first (Phase 1) |
| `fix-ui-correctness-sweep` | エピソード一覧修正 + エラー色セマンティック化 (Phase 2a バッチ1) |

## 7. 次にやるべきこと（後続の人/エージェントへ）

### 最優先: active changes の整理

Phase 2a バッチ1（なろうエピソード一覧 + ホームエラー色）は PR #40 でマージ済み。
現在の再開ポイントは以下です。運用ルールは [`docs/WORKFLOW.md`](WORKFLOW.md) を参照してください。

| 優先 | Change | 状態 | 次の確認 |
|---|---|---|---|
| 1 | `ui-phase-2-batch-3-localize-raw-errors-and-format-dates` | 13/14 | PR を作成し、GitHub Actions `analyze-and-test` が green になることを確認する |
| 2 | `polish-settings-actions-a11y` | 18/18 complete | GitHub 側の PR / merge 状況を確認し、完了済みなら OpenSpec archive する |
| 3 | `release-all-platform-installers` | 13/14 | Linux 実機で AppImage 起動確認。物理 Linux 環境が必要 |
| 4 | UI Phase 2 バッチ4 | 未作成 | 永久無効プレースホルダボタン + `policyVersion` デバッグ文言除去。`online-novel-library` spec と絡むため単独で扱う |

### その他の候補

| 候補 | 説明 |
|---|---|
| `release-all-platform-installers` 5.4 完了 | Linux 実機で AppImage 起動確認（物理 Linux 環境が必要） |
| v1.0 動画 AI | Anime4K リアルタイム / Real-ESRGAN オフライン / RIFE 補間（別トラック・別 ADR） |
| iOS 配布の本番化 | 署名証明書/プロビジョニング整備 |
| 実モデルの視覚確認 | manga viewer で Real-ESRGAN の 2x/4x 出力を目視確認、タイルサイズ実測 |

### 新規 change を起こす際のチェックリスト

`docs/roadmap.md` の **v0.2 proposal readiness checklist** を参照。特に:
- drift schema を触る場合は latest+1（現行 v6 → v7）
- 新規ユーザー可視文字列は `AppLocalizations` 経由（日英）
- `dart format` / `flutter analyze --fatal-infos` / `flutter test` を tasks に含める
- **ローカルに Flutter が無い** ことを前提に、CI サイクルを見込んだバッチ設計にする

## 8. 既知の宿題 / 注意点

### コード

- **`oss_licenses.dart`**: pubspec version bump 時は再生成が必要。Flutter が無い場合は `_geekplayer` エントリの 2 箇所（`/// geekplayer <ver>` と `version: '<ver>'`）を手修正（[`docs/release.md`](release.md) 参照）
- **Android file-provider**: `expand-auto-update-delivery` の install handoff で AndroidManifest file-provider 宣言が残課題
- **DirectML (Windows GPU)**: `onnxruntime` 1.4.1 が高レベル API で非公開 → Windows は ORT CPU EP に縮退（ADR-0007 amendment）
- **Android 16 KB ページ互換**: `libonnxruntime.so` のみ非対応。上流対応待ち（AI upscale は Experimental default-OFF、ストア配布なし）

### 法務

- libmpv (LGPL) 動的リンク — `lgpl-compliance` capability で書面通知実装済み
- カクヨム HTML パース — ADR-0001 の運用規範を厳守

## 9. 変更前に参照する文書

- Workflow / agent skill placement: [`docs/WORKFLOW.md`](WORKFLOW.md), [`CLAUDE.md`](../CLAUDE.md), [`AGENTS.md`](../AGENTS.md)
- Accepted specs / active changes: [`openspec/`](../openspec/)
- ADR history: [`docs/adr/`](adr/)

## 10. 最近のコミット履歴（参考）

```
cc2dd1c chore(openspec): archive fix-ui-correctness-sweep + sync narou spec
70dea45 fix(ui): Narou episode list + semantic home error color (#40)
bb946ee chore(openspec): archive add-design-system-foundation + sync specs (#39)
a8f0a21 feat(ui): design-system foundation — teal theme builder + tokens + dark-first (#38)
6b2ba70 docs(release): update release.md for 4-platform artifacts + version-bump note (#37)
64c86ed docs(openspec): verify release 5.3 — v0.1.1 release with 4 assets + auto notes (#36)
d1c4c56 chore(release): bump version to 0.1.1+2 (#35)
```

最新の状態は `git log --oneline -20` で確認してください。

---

質問があれば、まず以下を読むと早い:
- `CLAUDE.md` — プロジェクト全体ルール
- `docs/roadmap.md` — 機能スコープ
- `docs/adr/` — 過去の判断
- `CONTEXT.md` — ドメイン用語

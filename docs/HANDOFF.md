# GeekPlayer — ハンドオフ資料

このドキュメントは、ここまでの設計・足場作りを引き継ぐ後続の人 / 後続のエージェントが、
**読まなくて済む対話履歴をスキップして** すぐに作業に入れることを目的にしています。
最終更新: 2026-06-03（**v0.1 リリース済み (`v0.1.0` タグ) — 全 8 changes archived、20 capabilities 確定。現在は v0.2 着手フェーズ**）。

## 現在の権威ある状態 (2026-06-03)

このセクションが **唯一の権威あるベースライン** です。過去の "Wave / apply 未着手" 記述は
すべて履歴であり、以下が現状を表します。

- **リリース**: `v0.1.0` タグ済み（`git tag` で確認可能）。配布は GitHub Releases 手動アップロード（`docs/release.md`）。
- **OpenSpec archive**: v0.1 の 8 changes（`archive/2026-05-27-*`）に加え、v0.2 の 9 changes（`archive/2026-06-03-*`）もすべて archive 済み。
  - v0.1: video / audio / online-novel-library / error-ux-infra / narou / kakuyomu / app-settings / about-and-licenses
  - v0.2: prepare-v0-2-foundation / add-english-localization / add-pdf-epub-reader / add-manga-zip-viewer / add-media-library / expand-ci-and-platforms / add-auto-update / add-ml-runtime-abstraction / expand-auto-update-delivery / add-platform-ios / add-ai-image-upscaler
- **capabilities**: 34 capability が `openspec/specs/` に確定（手動編集禁止、`/opsx:archive` 経由でのみ更新）。`openspec validate --specs --strict` は 34/34 pass。
- **drift schema**: **v6**（v1: playback_positions, recent_items / v2: novel_*, site_consents / v3: app_settings / v4: book_metadata, book_bookmarks / v5: manga_metadata, manga_bookmarks / v6: media_index, watch_history, favorites, playlists, playlist_items）。
- **CI**: `.github/workflows/ci.yaml` は 6 ジョブ — `analyze-and-test`(ubuntu) / `build-android-debug` / `build-windows-release` / `build-macos`(macos-latest) / `build-linux`(ubuntu, apt: libmpv-dev ninja-build libgtk-3-dev) / `build-ios`(macos-latest, SPM 無効化 + `flutter build ios --no-codesign`)。全ジョブ Flutter 3.44.0 ピン + build_runner + GIT_SHA dart-define。
- **対象プラットフォーム**: macOS / Windows / Android / **Linux** / **iOS・iPadOS**。iOS は libmpv/media_kit を CocoaPods 経由でビルド（ADR-0006 Option A、非ストア配布、deployment target 14.0）。
- **アクティブな v0.2 changes**: なし（上記 11 件すべて archive 済み）。v0.2 の全スコープ（書籍/漫画リーダー・ライブラリ・英語UI・CI拡張+Linux+iOS・自動アップデート delivery・AI 高画質化 seam+CPU upscaler）は実装完了。**残るは v1.0 の GPU/ネイティブ ML バックエンドと配布の本番化**。詳細は §6・§9。

> **v0.1 の Wave 実装手順について**: `docs/IMPLEMENTATION-PLAN.md` の wave/worktree/sub-agent
> 手順は **v0.1 実装時の履歴** です。v0.1 は完了・archive 済みのため、これらは新規実装の
> 出発点ではありません。v0.2 を始める場合は上記アクティブ changes と roadmap の sequencing に従ってください。

---

## 0. ドキュメントマップ

| 質問 | ファイル |
|---|---|
| 何を作っているの? | このファイル §1〜§3 |
| 開発環境のセットアップは? | このファイル §4 |
| 過去の設計判断と理由は? | [`docs/adr/`](adr/) (0001-0004, 0006) |
| プロジェクト全般のコーディング規約は? | [`docs/CONVENTIONS.md`](CONVENTIONS.md) |
| v0.1 実装手順（履歴, Wave / worktree） | [`docs/IMPLEMENTATION-PLAN.md`](IMPLEMENTATION-PLAN.md) |
| v0.2 のアクティブ change と apply 順 | このファイル §5 + [`docs/roadmap.md`](roadmap.md) |
| 解決済み・未解決の設計論点 | [`docs/GRILL-REPORT.md`](GRILL-REPORT.md) |
| ロードマップ (v0.2 / v1.0) | [`docs/roadmap.md`](roadmap.md) |
| ドメイン用語集 | [`CONTEXT.md`](../CONTEXT.md) |
| AI ハーネス用プロジェクトルール | [`CLAUDE.md`](../CLAUDE.md) / [`AGENTS.md`](../AGENTS.md) |

## 1. プロジェクト一行説明

GeekPlayer は **動画 / 音楽 / 書籍 / 漫画ZIP / オンライン小説**（小説家になろう / ノクターン
ノベルズ / カクヨム）を 1 つのアプリで扱う Flutter 製クロスプラットフォーム・マルチメディア
プレイヤー。最終的に AI 高画質化機能を載せる。

## 2. 確定済みの主要決定

`/grill-with-docs` セッションで詰めた 6 つの決定:

| # | テーマ | 決定 |
|---|---|---|
| Q1 | scaffold を OpenSpec change にするか | しない（通常コミットで実施済み） |
| Q2 | MVP の境界 | **thin + 小説のみリッチ寄り最小**。動画/音楽は「開く→再生 + resume + 最近開いた」のみ |
| Q3 | v0.1 対象プラットフォーム | **macOS + Windows + Android**。Linux / iOS / iPadOS は v0.2 |
| Q4 | メディア再生エンジン | **ハイブリッド**: 動画 = `media_kit` (libmpv) / 音楽 = `just_audio` + `audio_service` ([ADR-0002](adr/0002-hybrid-media-engine.md)) |
| Q5 | カクヨム本文取得 | **HTML パース + 注意書き 4 箇所** ([ADR-0001](adr/0001-online-novel-fetch-policy.md)) |
| Q6 | キャッシュ & スクレイピング行儀 | 能動キャッシュ、TTL なし、レート制限、UA 識別、`robots.txt` 尊重、同意拒否時カクヨムのみ無効化 |

その他の固定:
- 言語/フレームワーク: **Flutter 3.44 (Dart 3.12)**
- 配布: **OSS / 個人利用、App Store / Play Store には出さない**（GitHub Releases 直配布）
- ライセンス: **Apache-2.0**（libmpv は LGPL 動的リンク）
- UI 言語: ja-first（v0.1 は ja のみ、`intl` 骨組みは入れる）
- 状態管理: **Riverpod v3 (codegen `@Riverpod` API)** — `riverpod_generator` で `*.g.dart` を生成
- ストレージ: 単一 **drift** SQLite DB
- AI 高画質化: ロードマップ項目（MVP 外）

## 3. リポジトリの現状

```
GeekPlayer/
├── app/                              # Flutter project (`flutter create` 済み)
│   ├── lib/                          # core/{di,storage,network,media,theme,consent}
│   │                                   features/{video,audio,novel,library,book,manga,settings}
│   ├── pubspec.yaml                  # 主要依存追加済み
│   └── ...                           # android/, ios/, linux/, macos/, windows/
├── docs/
│   ├── adr/
│   │   ├── 0001-online-novel-fetch-policy.md
│   │   ├── 0002-hybrid-media-engine.md
│   │   ├── 0003-narou-content-fetch-policy.md
│   │   ├── 0004-home-screen-section-registry.md
│   │   ├── 0006-ios-media-engine-distribution-policy.md  # accepted
│   │   └── 0007-ai-upscaling-runtime-strategy.md         # accepted
│   ├── roadmap.md                    # v0.1 / v0.2 / v1.0
│   └── HANDOFF.md                    # このファイル
├── openspec/
│   ├── config.yaml                   # context + rules 設定済み
│   ├── changes/                      # active なし / archive/ に v0.1+v0.2 (詳細は §5)
│   └── specs/                        # 31 capability 確定済み
├── .github/workflows/ci.yaml         # 5 jobs: analyze-test / android / windows / macos / linux
├── CLAUDE.md / AGENTS.md             # 各 AI ハーネス向け project instructions
├── CONTEXT.md                        # ドメイン用語集
├── LICENSE                           # Apache-2.0
├── README.md
└── THIRD_PARTY_NOTICES.md
```

GitHub: **https://github.com/geekjapan/GeekPlayer** (PRIVATE)

v0.1 は `v0.1.0` タグでリリース済み。最新のコミット履歴は `git log` で確認してください
（本ハンドオフはコミット SHA を直書きせず、タグとアクティブ change を権威とします）。

## 4. 開発環境のセットアップ

### 必要なツール

- **Flutter 3.44 stable** — `~/flutter` に git clone 済み。`~/.bashrc` に PATH 追加済み:
  ```bash
  export PATH="$HOME/flutter/bin:$HOME/.local/bin:$PATH"
  ```
- **`unzip` shim** — システムに `unzip` がなかったため、Python の `zipfile` を使う shim を
  `~/.local/bin/unzip` に置いてある。Flutter SDK の Dart bootstrap で使用される。
  システムに本物の `unzip` を `sudo apt install unzip` で入れた場合は削除可。
- **`gh` CLI** — 認証済み（アカウント: `geekjapan`）
- **Android SDK / Android Studio** — まだ未セットアップ。Android ビルドが必要になったら
  ユーザーが自前で入れる必要あり

### よく使うコマンド

```bash
# 開発
cd app
flutter pub get
flutter analyze
flutter test
flutter run -d <device>

# OpenSpec ワークフロー
openspec list --json
openspec status --change "<name>"
openspec instructions <artifact-id> --change "<name>" --json
openspec instructions apply --change "<name>" --json   # 実装中に参照
```

### スラッシュコマンド（Claude Code / Codex / π 共通）

| コマンド | 用途 |
|---|---|
| `/opsx:explore [topic]` | 思考パートナーモード |
| `/opsx:propose <name>` | 新規 change の足場 + 4 artifact 一括生成 |
| `/opsx:apply [name]` | tasks.md のチェックボックスを順に実装 |
| `/opsx:archive [name]` | 完了 change を `openspec/changes/archive/` に移動 + `openspec/specs/` 更新 |

## 5. changes 一覧

### v0.1 MVP（すべて archived・実装済み — 履歴）

`openspec/changes/archive/2026-05-27-*` に保管。これらは **完了済みで、新規実装の対象ではありません**。
仕様は `openspec/specs/` の capability（全 31、v0.2 ぶんを含む）に確定しています。

| Change | 主な Capabilities |
|---|---|
| `add-local-video-playback` | local-video-playback, media-session |
| `add-local-audio-playback` | local-audio-playback, media-session (audio variant) |
| `add-online-novel-library` | online-novel-library, site-consent, responsible-fetching, media-session |
| `add-error-ux-infra` | error-domain, error-ux-widgets, retry-strategy |
| `add-narou-novel-reader` | narou-novel-source, narou-novel-reader-ui, r18-age-gate |
| `add-kakuyomu-novel-reader` | kakuyomu-novel-source, kakuyomu-novel-reader-ui, kakuyomu-resilience |
| `add-app-settings` | app-settings, settings-persistence |
| `add-about-and-licenses` | about-screen, oss-license-notices, lgpl-compliance |

drift スキーマの確定済みマイグレーション順序（現行 **v6**）:
- v1 = `playback_positions` / `recent_items`（video）
- v2 = `novel_*` / `site_consents`（novel-library）
- v3 = `app_settings`（app-settings）
- v4 = `book_metadata` / `book_bookmarks`（pdf-epub）
- v5 = `manga_metadata` / `manga_bookmarks`（manga）
- v6 = `media_index` / `watch_history` / `favorites` / `playlists` / `playlist_items`（media-library）

### v0.2 changes（すべて archived・実装済み — 履歴）

`openspec/changes/archive/2026-06-03-*` に保管。proposal / design / specs / tasks が揃い、実装・テスト・CI 検証まで完了。

| Change | 役割 | drift |
|---|---|---|
| `prepare-v0-2-foundation` | ドキュメント整合性・ADR-0006・v0.2 sequencing の整備（コードなし） | — |
| `add-english-localization` | en ロケール基盤・ARB parity test。後続 UI の前提 | — |
| `add-pdf-epub-reader` | PDF/EPUB リーダー。`BookDocument`/`PageSession` を確立 | v4 |
| `add-manga-zip-viewer` | 漫画 ZIP/CBZ ビューア | v5 |
| `add-media-library` | フォルダスキャン・視聴履歴・お気に入り・プレイリスト。`MediaLibraryHomeSection`(order 700) | v6 |
| `expand-ci-and-platforms` | CI ビルドマトリクス（macOS/Linux 追加）+ `app/linux/` CMake scaffolding | — |
| `add-auto-update` | GitHub Releases チェック + Settings About の更新バナー | — |

## 6. v0.2 以降の未起案候補 changes

`docs/roadmap.md` 参照。v0.2 の全スコープは §5 で完了済み。残る候補（主に v1.0）:

- **v1.0 AI 高画質化の具体バックエンド** — `add-ml-runtime-abstraction` の seam（`ImageUpscaler`）と `add-ai-image-upscaler` の CPU bicubic 実装の上に、CoreML/NNAPI/ONNX/TensorRT の GPU バックエンドと Real-ESRGAN/waifu2x モデルを載せる（`add-ai-image-upscaler-gpu` 等）。
- **動画 AI**（Anime4K リアルタイム / Real-ESRGAN オフライン書き出し / RIFE フレーム補間）— roadmap §v1.0。
- **iOS 配布の本番化** — 署名証明書/プロビジョニング、Ad Hoc/直配布の導線整備（`add-platform-ios` はビルド + CI smoke まで完了）。

完了済みで候補から外れた項目（履歴）: `add-video-library`/`add-audio-library`（→ `add-media-library`）、`add-platform-linux`（→ `expand-ci-and-platforms`）、`add-auto-update` + `expand-auto-update-delivery`、`setup-ci-macos-windows`（→ `expand-ci-and-platforms`）、`add-ml-runtime-abstraction`、`add-platform-ios`（iOS/iPadOS ビルド + build-ios CI）、`add-ai-image-upscaler`（CPU bicubic + manga viewer 高画質化）。

### v1.0 AI 高画質化

- `add-ml-runtime-abstraction` — `core/ml/`（CoreML / NNAPI / ONNX Runtime / TensorRT）
- `add-ai-image-upscaler` — Real-ESRGAN / waifu2x（漫画/書籍）
- `add-ai-video-upscaler-realtime` — Anime4K リアルタイム
- `add-ai-video-upscaler-offline` — Real-ESRGAN 動画書き出し
- `add-ai-frame-interpolation` — RIFE

## 7. 既知の宿題 / 注意点

### コード/設定の宿題

- **Android `AndroidManifest.xml`** — 音楽再生通知用の `<service>` 宣言は
  `add-local-audio-playback` の tasks にあり、apply 時に追加する
- **macOS `entitlements`** — `com.apple.security.files.user-selected.read-only` は
  `add-local-video-playback` で、`LSBackgroundModes (audio)` は `add-local-audio-playback`
  で追加する
- **Android 13+ `POST_NOTIFICATIONS` / `READ_MEDIA_VIDEO`** — 各 change の tasks 参照
- **drift code-gen** — `flutter pub run build_runner build --delete-conflicting-outputs`
  を tasks.md の各所で実行する必要あり
- ~~**auto-update の Android install handoff**~~ — **解決済み**（`add-android-apk-install-handoff`）。
  `LaunchUrlUpdateInstaller` をプラットフォーム分岐にし、Android は `open_filex`（BSD-3）で
  `FileProvider` content URI + パッケージインストーラ intent を起動（同梱 provider 利用、
  `REQUEST_INSTALL_PACKAGES` + `<queries>` を AndroidManifest に追加）。macOS/Windows/Linux は
  従来の `launchUrl(Uri.file(path))` を維持、iOS は install 経路なし（対象外）。
  **実機検証 (manual)**: Android 端末/エミュレータで DL→install intent 起動を一度確認すること
  （CI 非依存。routing はホストで注入 fake により単体テスト済み）。

### 法務・運用

- **libmpv (LGPL) 動的リンク** — `add-about-and-licenses` の `lgpl-compliance` capability
  で書面通知を実装する。**iOS App Store 配布は LGPL 動的リンクと相性が悪い** ため、
  v0.2 で iOS 追加する際は (a) 配布方針変更（OSS 配布のみ維持） / (b) media_kit を別エンジン
  に切り替え のいずれかを ADR で決める必要あり
- **カクヨム HTML パース** — ADR-0001 の運用規範を厳守。HTML 構造変更でパース失敗時の
  挙動は `add-kakuyomu-novel-reader` の `kakuyomu-resilience` capability で仕様化済み

### CI / インフラ

- 現在の CI は `ubuntu-latest` のみで `flutter analyze` + `flutter test` + `dart format`
- **macOS / Windows runner の追加** は v0.2 の `setup-ci-macos-windows` で予定
- iOS ビルドは macOS runner + 署名証明書が必要

## 8. このリポジトリで触ってはいけないもの

- `.claude/`, `.codex/`, `.pi/` の `skills/` 配下 — OpenSpec ワークフローのスキル定義。
  変更が必要な場合は 3 ハーネス同時に揃えること（`CLAUDE.md` の指示参照）
- `openspec/specs/` — `/opsx:archive` 経由でのみ更新される。手動編集禁止
- 既存 ADR (`docs/adr/0001`, `docs/adr/0002`) — 方針変更時は **superseded** な新 ADR を
  立て、古い ADR を直接書き換えない

## 9. 次に何をすべきか（後続の人/エージェントへ）

v0.1 はリリース済み、**v0.2 の主要スコープ（§5 の 7 changes）も実装・archive 完了** しています。
次に着手する候補は次のいずれか:

### 次の候補

1. **v1.0 AI 高画質化（[ADR-0007](adr/0007-ai-upscaling-runtime-strategy.md) のシーケンス）** — ランタイム戦略は ADR-0007 で **accepted**（ONNX Runtime + Execution Provider 一本化、preferred/effective backend 分離、bicubic CPU を floor、**画像のみ・当面 Experimental 既定 OFF**、モデルは opt-in 初回 DL）。後続 change:
   1. ✅ `refactor-ml-runtime-effective-backend` — `MlRuntime` を preferred/effective + 非同期 `probe()` + フォールバック（preferred EP → ortCpu → bicubicCpu）へ再構成済み。`MlBackend` は EP 志向（coremlEp/nnapiEp/directmlEp/ortCpu/bicubicCpu）。実験フラグ OFF / モデル未取得時は bicubicCpu。
   2. ✅ `add-onnx-upscaler-runtime` — ORT 統合 + CPU EP の `OnnxImageUpscaler`（軽量モデルで CI 検証）。
   3. ✅ `add-upscale-model-distribution` — `ModelRepository`（初回 DL/SHA-256 検証/原子的キャッシュ/削除、`crypto`+`dio`+`path_provider`）+ Experimental 設定 UI（有効化トグル既定 OFF・2x/4x スケール・モデル管理）+ async `imageUpscalerProvider` 配線 + manga viewer 移行。**フィクスチャモデル（2x/4x nearest ONNX）で配線完成・実モデル選定/URL/SHA は follow-up**（grill Q1=A）。drift schema 据え置き（設定は既存 key/value）。
   4. ✅ `enable-gpu-execution-providers` — **CoreML EP（iOS/macOS）・NNAPI EP（Android）** を `OnnxImageUpscaler` で有効化（target backend に応じ GPU EP を先に append→失敗時 catch して CPU-only へ degrade、CPU EP は常時 append）。CPU+GPU 統合 probe を production `mlRuntimeProvider` に配線。上級 backend 上書き UI（Auto/強制 CPU/強制 GPU、`preferred` のみに作用し probe 縮退は優先）+ 設定永続化（`AiUpscaleBackendOverride` enum、key `experimental.ai_upscale_backend_override`、既定 auto）。**DirectML（Windows GPU）は `onnxruntime` 1.4.1 が高レベル API で非公開 → Windows は ORT CPU EP に縮退**（[ADR-0007 amendment 2026-06-06](adr/0007-ai-upscaling-runtime-strategy.md) で明文化、grill Q3=B）。drift schema 据え置き。
2. **動画 AI**（Anime4K リアルタイム / Real-ESRGAN オフライン / RIFE 補間）— `ImageUpscaler` 対象外の別トラック・別 ADR。
3. **iOS 配布の本番化** — 署名証明書/プロビジョニング整備（ビルド + CI smoke は `add-platform-ios` で完了）。
4. **auto-update の Android file-provider 対応** — Android で `file://` install handoff に AndroidManifest の file-provider 宣言が必要（既知の残課題、§7 参照）。

新しい proposal を起こす際は roadmap の **v0.2 proposal readiness checklist** に通すこと。drift schema を
触る場合は latest+1（現行 v6 → v7）を取り、migration テストを追加する。

実装中は **[CONVENTIONS.md](CONVENTIONS.md)**（HomeScreen レジストリ / pubspec 冪等 /
AndroidManifest append-only / drift versioning 等）を遵守する。設計上の疑問が出たら
`design.md` の **Open Questions** を更新するか、新しい ADR を起こす。

> v0.1 実装時の Wave/worktree/sub-agent 手順は [`docs/IMPLEMENTATION-PLAN.md`](IMPLEMENTATION-PLAN.md)
> に履歴として残っています（v0.2 では参考情報）。

---

質問があれば、まず以下のファイルから読むと早い:
- `CLAUDE.md` — プロジェクト全体ルール
- `docs/roadmap.md` — 機能スコープ
- `docs/adr/` — 過去の判断
- `CONTEXT.md` — ドメイン用語

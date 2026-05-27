# GeekPlayer — ハンドオフ資料

このドキュメントは、ここまでの設計・足場作りを引き継ぐ後続の人 / 後続のエージェントが、
**読まなくて済む対話履歴をスキップして** すぐに作業に入れることを目的にしています。
最終更新: 2026-05-27。

---

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
- 状態管理: **Riverpod v2 (Notifier API)**
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
│   │   └── 0002-hybrid-media-engine.md
│   ├── roadmap.md                    # v0.1 / v0.2 / v1.0
│   └── HANDOFF.md                    # このファイル
├── openspec/
│   ├── config.yaml                   # context + rules 設定済み
│   ├── changes/                      # 7 changes (詳細は §5)
│   └── specs/                        # archive 先 (まだ空)
├── .github/workflows/ci.yaml         # ubuntu-latest CI (green を確認済み)
├── CLAUDE.md / AGENTS.md             # 各 AI ハーネス向け project instructions
├── CONTEXT.md                        # ドメイン用語集
├── LICENSE                           # Apache-2.0
├── README.md
└── THIRD_PARTY_NOTICES.md
```

GitHub: **https://github.com/geekjapan/GeekPlayer** (PRIVATE)

直近のコミット履歴（push 済み）:
```
78fb575 feat: scaffold Flutter monorepo for GeekPlayer
61e4949 Initial commit
```

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

## 5. 全 7 changes 一覧

すべて proposal / design / specs / tasks の 4 artifact が揃った状態。**apply は未着手**。

### v0.1 MVP コア（順に apply 推奨）

| # | Change | Capabilities | Tasks |
|---|---|---|---|
| 1 | `add-local-video-playback` | local-video-playback, media-session | 41 |
| 2 | `add-local-audio-playback` | local-audio-playback, media-session (audio variant) | 51 |
| 3 | `add-online-novel-library` | online-novel-library, site-consent, responsible-fetching, media-session | 64 |
| 4 | `add-narou-novel-reader` | narou-novel-source, narou-novel-reader-ui, r18-age-gate | 64 |
| 5 | `add-kakuyomu-novel-reader` | kakuyomu-novel-source, kakuyomu-novel-reader-ui, kakuyomu-resilience | 65 |

### v0.1 配布前に必要な締めの作業

| # | Change | Capabilities | Tasks |
|---|---|---|---|
| 6 | `add-app-settings` | app-settings, settings-persistence | 54 |
| 7 | `add-about-and-licenses` | about-screen, oss-license-notices, lgpl-compliance | 37 |

**合計タスク数: 376**

### 推奨 apply 順序

1. `add-local-video-playback` — `MediaSession` 抽象と drift スキーマ v1 の起点。後続が依存
2. `add-local-audio-playback` — `MediaSession` の audio variant を追加。OS 統合実装
3. `add-online-novel-library` — `NovelRepository` interface、`SiteConsent`、`RateLimiter`、drift v2
4. `add-narou-novel-reader` — 公式 API 実装。R18 ゲート
5. `add-kakuyomu-novel-reader` — RSS + HTML パース。ADR-0001 準拠の運用規範
6. `add-app-settings` — 設定 UI と永続化（drift v3）
7. `add-about-and-licenses` — LGPL 書面通知 + Apache NOTICE

drift スキーマのマイグレーション順序前提:
- v1 = `playback_positions` / `recent_items`（video change）
- v2 = `novel_*` / `site_consents`（novel-library change）
- v3 = `app_settings`（app-settings change）

## 6. v0.2 以降の候補 changes（未起案）

`docs/roadmap.md` 参照。次の候補:

- `add-pdf-epub-reader` — 書籍リーダー
- `add-manga-zip-viewer` — 漫画 CBZ/ZIP ビューア
- `add-video-library` — フォルダスキャン + 視聴履歴
- `add-audio-library` — 音楽ライブラリ + 永続プレイリスト
- `add-platform-linux` — Linux ビルド
- `add-platform-ios` — iOS/iPadOS ビルド + 署名（**libmpv LGPL 動的リンクを App Store に
  載せられないため、配布方針の再評価が必要**）
- `add-auto-update` — GitHub Releases ベースの in-app update
- `add-english-localization` — en ARB
- `setup-ci-macos-windows` — CI ランナー追加

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

1. **`add-local-video-playback` を apply 開始** — `/opsx:apply add-local-video-playback`
2. tasks.md のチェックボックスを 1 つずつ消化、完了即 `- [x]` に
3. 全 task 完了で `flutter analyze` / `flutter test` / `dart format` がクリーンを確認
4. **実機検証** — macOS / Windows / Android 3 OS で動作確認（tasks のセクション 7 参照）
5. `/opsx:archive add-local-video-playback` で `openspec/specs/` に確定
6. 次の change（audio）に進む

途中で設計上の疑問が出たら、`design.md` の **Open Questions** セクションを更新するか、
新しい ADR を起こす。

---

質問があれば、まず以下のファイルから読むと早い:
- `CLAUDE.md` — プロジェクト全体ルール
- `docs/roadmap.md` — 機能スコープ
- `docs/adr/` — 過去の判断
- `CONTEXT.md` — ドメイン用語

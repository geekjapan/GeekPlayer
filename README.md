# GeekPlayer

> あらゆるオフライン/オンラインコンテンツを 1 アプリで楽しむ、クロスプラットフォーム
> マルチメディアプレイヤー。

GeekPlayer は **動画・音楽・書籍・漫画ZIP・オンライン小説（小説家になろう、ノクターン
ノベルズ、カクヨム）** を統合的に再生・閲覧できる Flutter 製プレイヤーです。

## 対応プラットフォーム

| OS | v0.1 | v0.2 (予定) |
|---|---|---|
| Windows | ✅ | |
| macOS | ✅ | |
| Android | ✅ | |
| Linux | | ✅ |
| iOS / iPadOS | | ✅ |

## 機能

### v0.1 (MVP)

- **動画再生**: mp4 / mkv / HEVC / HLS / DASH、ASS-SSA-SRT 字幕、HW デコード（`media_kit` / libmpv ベース）
- **音楽再生**: mp3 / flac / m4a / ogg、背景再生、ロック画面コントロール、ヘッドホンボタン対応（`just_audio` + `audio_service`）
- **再生位置の保存**: 動画・音楽・小説それぞれで前回位置から再開
- **「最近開いた」リスト**
- **オンライン小説ライブラリ（インフラ層）**: `NovelRepository` 抽象 / drift v2 スキーマ / レート制限 / `robots.txt` / 同意ダイアログ / `NovelHomeSection` を整備済み。具体的なサイト対応はサイト別 change (`add-narou-novel-reader` / `add-kakuyomu-novel-reader`) で順次有効化されます。
  - 小説家になろう / ノクターンノベルズ等 (公式 API)
  - カクヨム (公式 RSS + 本文 HTML パース — 後述の注意事項あり)
- **オフライン読書**: ライブラリに追加した作品の本文を端末内に保存

### v0.2 ロードマップ

- Linux / iOS / iPadOS 対応
- 書籍 (PDF / EPUB) リーダー
- 漫画 ZIP / CBZ ビューア
- ライブラリ（フォルダスキャン、視聴履歴、しおり、プレイリスト）
- 自動アップデート機構

### v1.0 ロードマップ

- AI 高画質化（画像 / 動画）
- フレーム補間

詳細は [`docs/roadmap.md`](docs/roadmap.md) を参照してください。

## 小説家になろう / ノクターン系統の注意事項

本アプリは **小説家になろう / ノクターン系統 (ノクターン・ミッドナイト・ムーンライト)**
の作品検索 / ランキング / 詳細メタデータを公式 API で取得し、**本文 (各話)** は
HTML ページのパースで取得します。これは
[ADR-0003](docs/adr/0003-narou-content-fetch-policy.md) で確定した方針であり、
以下の行儀規範を遵守しています:

- **個人利用に限定** / **能動キャッシュ** (Library 追加分のみ保存)
- **レート制限**: `*.syosetu.com` 共通バケットで 1 req/sec、並列度 1〜2
- **`robots.txt` の尊重**、429/503 で指数バックオフ (最大 5 分 × 6 回)
- **R18 同意**: ノクターン系統にアクセスする前に「あなたは18歳以上ですか?」の
  確認ダイアログ (`AgeGateDialog`) を表示します。同意は `Settings > オンライン小説`
  からいつでも取り消せます。
- **将来の方針変更**: なろう側が利用規約上で自動収集を明示的に禁じた、または
  公式の本文取得 API を提供した場合、本アプリは速やかに対応方針を更新します。

## カクヨム機能の注意事項

カクヨムには公式 API がないため、本アプリは **公式 RSS（一覧/通知用）** に加えて
作品ページの **HTML パース** で本文を取得しています。これは
[ADR-0001](docs/adr/0001-online-novel-fetch-policy.md) で記録された設計判断であり、
以下の行儀規範を遵守しています:

- **個人利用に限定**: 本機能は個人の読書用途のみを想定しています。商用利用・再配布・大規模クロールは行わないでください。
- **能動キャッシュ**: ユーザーが「ライブラリに追加」した作品の本文だけがローカルに保存されます。受動的なクロール/ミラーリングは行いません。
- **レート制限**: カクヨムへのリクエストは 2 秒に最大 1 回、並列度 1 で実行されます。
- **`robots.txt` の尊重**、429/503 レスポンス時の指数バックオフ。
- **同意ダイアログ**: 初回起動時にカクヨム機能を利用するための同意が必要です。拒否してもなろう/ノクターン系の機能は利用できます。
- **将来の方針変更**: カクヨムが利用規約上で自動収集を明示的に禁じた、あるいは公式 API を提供した場合、本アプリは速やかに対応方針を更新します。

## ビルド方法（v0.1）

```bash
# 前提: Flutter 3.44+ stable がインストールされていること
cd app
flutter pub get
flutter run -d <macos|windows|<android-device-id>>
```

Flutter のセットアップは [Flutter 公式インストールガイド](https://docs.flutter.dev/get-started/install) を参照してください。

## 開発ワークフロー

このプロジェクトは [OpenSpec](https://github.com/openspec) の spec-driven workflow を
採用しています。非自明な変更は `proposal → design → tasks → implementation → archive`
のフローを経ます。

計画管理は **GitHub Milestone / Issue を正本**とし、ローカルリポジトリでは対応する
OpenSpec change、実装、テスト、設計ドキュメントを管理します。チャット運用上は GitHub
管理とローカルリポジトリ管理を分離し、Codex が実装、このリポジトリ管理チャットが介入・
レビュー・指示を担当します。詳細は [`docs/WORKFLOW.md`](docs/WORKFLOW.md)、
[`CLAUDE.md`](CLAUDE.md)、[`AGENTS.md`](AGENTS.md) を参照してください。

主なスラッシュコマンド（Claude Code / Codex / π 互換）:

- `/opsx:explore [topic]` — 思考パートナーモード
- `/opsx:propose <name>` — 変更提案の足場作成
- `/opsx:apply [name]` — 提案された tasks の実装
- `/opsx:archive [name]` — 完了した変更のアーカイブ

## ライセンス

[Apache License 2.0](LICENSE) © GeekPlayer Contributors

依存ライブラリのライセンスは [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
に集約しています。libmpv (LGPL) を動的リンクで利用しており、本リポジトリは App Store
非配布の OSS 配布のみを想定しています。

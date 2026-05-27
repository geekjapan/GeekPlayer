## Why

GeekPlayer は `media_kit` を介して **libmpv (LGPL-2.1+)** を動的リンクで利用しており
([`docs/adr/0002-hybrid-media-engine.md:39`](../../../docs/adr/0002-hybrid-media-engine.md))、
LGPL の配布要件（差し替え権利・上流ソース URL・ライセンス本文同梱）をアプリ内で
書面通知することが OSS 配布として法務的必須事項である。同時に GeekPlayer 本体は
Apache-2.0 ([`LICENSE:189`](../../../LICENSE)) で配布されており、NOTICE 表示も
必要となる。現状この通知は [`THIRD_PARTY_NOTICES.md:1`](../../../THIRD_PARTY_NOTICES.md)
にしか存在せず、エンドユーザーがアプリを実行した状態では目視できない。本 change
はこれをアプリ内 UI として満たすと同時に、依存パッケージ全体のライセンス本文を
ビルド時に自動収集して表示する基盤を導入する。

## What Changes

- **新規**: 設定画面から飛べる "About" 画面（アプリ名 / バージョン / ビルド番号 /
  コミット SHA / GitHub リポジトリ・Roadmap・ライセンスへのリンク）
- **新規**: "OSS Licenses" 画面 — 依存パッケージごとのライセンス本文一覧
- **新規**: 依存パッケージライセンスの自動収集を `flutter_oss_licenses` で行い、
  ビルド時に `app/pubspec.yaml` から OSS 情報を生成する
- **新規**: **libmpv (LGPL) 専用通知セクション** — 動的リンク利用の明示、上流
  ソース URL (`https://github.com/mpv-player/mpv`)、利用者が libmpv 部分のみを
  差し替えて再構築する権利と、その差し替え手順の概要
- **新規**: GeekPlayer 本体の Apache-2.0 NOTICE 表示
  ([`LICENSE:189`](../../../LICENSE) の "Copyright 2026 GeekPlayer Contributors")
- **新規**: バージョン情報を `package_info_plus` 経由で取得し、コミット SHA は
  ビルド時に Dart の `--dart-define=GIT_SHA=...` で渡す
- **新規**: ja-first の文言で各画面を実装（en は v0.2 で `intl` ARB 化）

## Capabilities

### New Capabilities

- `about-screen`: アプリ情報表示、外部リンク、バージョン取得
  (`package_info_plus`)、`GIT_SHA` のビルド時埋め込み
- `oss-license-notices`: 依存ライセンスの自動収集と一覧表示、Apache-2.0 NOTICE
  の表示
- `lgpl-compliance`: libmpv に関する書面通知、上流ソース URL、差し替え手順、
  利用者の権利説明（LGPL-2.1+ 配布要件）

### Modified Capabilities

（なし — 既存 spec への変更はない。`add-app-settings` で導入予定の設定画面から
本 change の About 画面への導線を張る前提だが、設定画面側の spec は別 change
の責務とする）

## Impact

**新規ディレクトリ / ファイル:**

- `app/lib/features/about/presentation/about_screen.dart` — About 画面
- `app/lib/features/about/presentation/license_screen.dart` — OSS ライセンス一覧
- `app/lib/features/about/presentation/license_detail_screen.dart` — 各パッケージ
  詳細
- `app/lib/features/about/presentation/lgpl_notice_section.dart` — libmpv 通知
  ウィジェット
- `app/lib/features/about/data/app_info_provider.dart` — `package_info_plus` 経由
- `app/lib/features/about/data/build_info.dart` — `GIT_SHA` の dart-define 読み出し
- `app/lib/features/about/data/oss_license_repository.dart` — `flutter_oss_licenses`
  生成データへのアクセス層
- `app/lib/features/about/domain/license_entry.dart` — `LicenseEntry` 値オブジェクト

**変更:**

- `app/pubspec.yaml` — `package_info_plus`, `flutter_oss_licenses`,
  `url_launcher` を依存追加
- `app/lib/main.dart:1` — 設定画面（`add-app-settings`）導入前の暫定として、
  既存 HomeScreen から About 画面へ飛べるエントリポイントを 1 つ追加
- ビルドスクリプト（CI / リリース手順）— `--dart-define=GIT_SHA=$(git rev-parse --short HEAD)`
  を必須引数として明文化

**プラットフォーム影響:**

- v0.1 対象の macOS / Windows / Android すべてで外部リンク (`url_launcher`) が
  動作することを確認
- libmpv バイナリは `media_kit_libs_video` がプラットフォームバンドルに同梱する
  ため、差し替え手順は OS 別（macOS は `.app` 内 `Frameworks/`、Windows は同梱
  DLL、Android は `arm64-v8a` 等の `.so`）に説明する

**Non-goals:**

- 設定画面のグローバル UI / ナビゲーション構造 — `add-app-settings` change の責務
- About 画面からのアプリ更新確認 — v0.2 の `add-auto-update`
- プライバシーポリシー画面 — OSS 個人利用方針のため作らない（将来必要になれば
  別 change）
- 英語ローカライズ — v0.2 で `intl` ARB 化
- ライセンス本文の差分検出 / 通知（依存更新で MIT → BSD に切り替わった等の検知）
  — v0.2 以降の `dependency-audit` 案件

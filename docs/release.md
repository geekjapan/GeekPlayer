# GeekPlayer リリース手順

このドキュメントは v0.1 以降のリリースで使う必須コマンドを集約したものです。
About 画面 (`features/about/`) はビルド時に埋め込まれた `GIT_SHA` を表示するため、
**リリースビルドは必ず `--dart-define=GIT_SHA=...` を付けて作成すること**。

## 必須ビルドコマンド

```bash
# 共通: 最新のコミット SHA を環境変数に取り込む
GIT_SHA=$(git rev-parse --short HEAD)

# macOS
flutter build macos --release --dart-define=GIT_SHA="$GIT_SHA"

# Windows
flutter build windows --release --dart-define=GIT_SHA="$GIT_SHA"

# Android (APK / App Bundle)
flutter build apk --release --dart-define=GIT_SHA="$GIT_SHA"
flutter build appbundle --release --dart-define=GIT_SHA="$GIT_SHA"
```

`--dart-define=GIT_SHA=...` を忘れると About 画面のコミット欄が `(dev build)` と
表示されます。リリース版でこの表示が出ている場合はビルドコマンドの確認・再ビルドが
必要です。

## OSS ライセンスデータの再生成

依存パッケージを増減した場合は **必ず** ライセンスデータを再生成してコミットする
こと。CI でも差分検出が行われ、差分があればビルドは fail します。

```bash
cd app
dart run flutter_oss_licenses:generate -o lib/oss_licenses.dart --project-root .
```

## ライセンスアセット整合性

`assets/legal/LGPL-2.1.txt` は FSF 公式の本文と byte-for-byte 一致している必要が
あります。CI では `assets/legal/checksums.txt` の SHA-256 と照合しています。
本文を差し替える場合は同じディレクトリの `checksums.txt` も更新してください。

```bash
cd app
sha256sum assets/legal/LGPL-2.1.txt   # checksums.txt と照合
```

## 配布

ビルド成果物は GitHub Releases に手動アップロードします (v0.1 時点)。
App Store / Play Store には配布しません (libmpv LGPL 動的リンクのため、
`docs/adr/0002-hybrid-media-engine.md` 参照)。

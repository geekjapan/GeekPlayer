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

## GitHub Actions での配布ビルド

`.github/workflows/release-artifacts.yaml` は Windows / macOS の配布用 artifact を作成します。

- `workflow_dispatch`: 手動実行。Actions の artifact として 14 日間保存されます。
- `v*` tag push: Windows zip と unsigned macOS dmg をビルドし、GitHub Release asset に添付します。

生成される成果物:

- `GeekPlayer-windows-<tag-or-run>.zip`
  - `geekplayer.exe` 単体ではなく、DLL / data を含む `Release/` 配下を zip 化します。
- `GeekPlayer-macos-<tag-or-run>-unsigned.dmg`
  - 未署名・未 notarize の dmg です。自分用 / 身内検証用としては利用できますが、初回起動時に
    macOS の Gatekeeper 警告が出ます。右クリック → 開く、またはシステム設定から許可してください。

tag release の例:

```bash
git tag v0.1.1
git push origin v0.1.1
```

GitHub Actions が成功すると、`v0.1.1` の GitHub Release が作成または更新され、
Windows zip と macOS dmg が添付されます。

## 配布

Windows / macOS の配布用 artifact は GitHub Actions で作成できます。Android release
APK / AAB は上記コマンドで作成し、必要に応じて GitHub Releases に追加してください。

App Store / Play Store には配布しません (libmpv LGPL 動的リンクのため、
`docs/adr/0002-hybrid-media-engine.md` 参照)。

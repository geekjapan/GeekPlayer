## Why

`release-artifacts.yaml` は spec の裏付けなしで ad-hoc に作られ、現状 **Windows (.zip) と macOS (.dmg unsigned) のみ**を `workflow_dispatch` 手動実行でビルドし、タグ参照時のみ GitHub Release に添付する。アーカイブ済み change `expand-ci-and-platforms` は「artifact packaging / distribution は別 change に先送り」と明記しており（design.md:42）、本 change がその配布レイヤーを確立する。対応プラットフォーム全体（v0.1: macOS/Windows/Android、v0.2: Linux）のインストーラを GitHub Release に揃え、`auto-update` spec が前提とする「Release に各プラットフォーム資産が並ぶ」状態を満たす。

## What Changes

- `.github/workflows/release-artifacts.yaml` に **`push: tags: ['v*']` トリガー**を追加（既存 `workflow_dispatch` は残す）。タグを打つと全プラットフォームをビルドして Release に自動添付。
- **Android リリース APK** ジョブを追加: `flutter build apk --release`（既存の debug 署名設定 `signingConfig = signingConfigs.getByName("debug")` によりキーストア不要で installable）→ `GeekPlayer-android-<suffix>.apk` をアップロード。
- **Linux AppImage** ジョブを追加: `flutter build linux --release` 後に AppImage 化（`flutter_distributor` もしくは `appimagetool`）→ `GeekPlayer-linux-<suffix>.AppImage` をアップロード。
- 既存の **Windows (.zip)** / **macOS (.dmg unsigned)** ジョブは維持。
- `publish-github-release` ジョブの `needs:` に Android / Linux ジョブを追加し、`if: github.ref_type == 'tag'` で全 4 プラットフォーム資産を 1 つの Release に集約。
- **iOS / iPadOS は対象外**（Apple Developer 証明書が OSS リポジトリに無く installable な .ipa を作れないため。証明書が用意でき次第の follow-up）。

## Capabilities

### New Capabilities

- `release-artifacts`: タグ push を契機に、対応する全プラットフォーム（Windows / macOS / Android / Linux）のインストーラ/配布物をビルドし、GitHub Release に添付する CI 配布パイプラインの要件を定義する。

### Modified Capabilities

（なし — `ci-build-matrix` は PR ごとのビルド smoke を扱う別 capability で、本 change の配布パイプラインとは分離する）

## Non-goals

- iOS / iPadOS のインストーラ配布（証明書ブロック、別 follow-up）。
- 本番キーストアによる Android 署名（当面は debug 署名 release APK で sideload 可能にする。正式リリース時に移行）。
- macOS の Apple 公証（notarization）/ 正式署名（現状 unsigned dmg を維持）。
- アプリのバージョン採番・タグ運用ルールの策定（タグ形式は `auto-update` spec の `vX.Y.Z` 前提に従うのみ）。
- CI 本体（`ci.yaml`）の PR ビルド smoke の変更。

## Impact

- 変更ファイル: `.github/workflows/release-artifacts.yaml`（トリガー追加、Android/Linux ジョブ追加、publish の needs 拡張）。
- 新規 spec: `openspec/specs/release-artifacts/spec.md`。
- 依存: `softprops/action-gh-release@v2`（既存利用）、`actions/upload-artifact@v4`/`download-artifact@v4`（既存）。Linux AppImage 化に `flutter_distributor` もしくは `appimagetool` + FUSE 回避（`--appimage-extract-and-run`）を新規利用。
- Android build.gradle は変更不要（debug 署名が release に既設定）。
- リスク: AppImage 化ツールの CI 環境依存（FUSE 不在）→ design で回避策を決める。tag push 自動公開のため、誤タグで Release が作られうる → タグ命名規約の周知で緩和。

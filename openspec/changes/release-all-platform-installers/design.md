## Context

`release-artifacts.yaml`（現状）:
- トリガーは `workflow_dispatch` のみ。`permissions: contents: write`。
- `build-windows-release`（zip）と `build-macos-release`（unsigned dmg, `hdiutil`）の 2 ジョブ。
- `publish-github-release` が `if: github.ref_type == 'tag'` かつ両ビルドを `needs:` して `softprops/action-gh-release@v2` で添付、`generate_release_notes: true`。
- 各ジョブに「Set artifact metadata」ステップがあり、タグ時は `ARTIFACT_SUFFIX=<tag>`、それ以外は `run-<run_number>`。

不足: Android / Linux ジョブ、タグ push 自動トリガー。`auto-update` spec は Release に各プラットフォーム資産が並ぶことを前提にしている。

確定事項（ユーザー決定）: iOS/iPadOS スキップ、Android=debug 署名 release APK、Linux=AppImage、タグ push で自動公開。

前提確認済み: `android/app/build.gradle.kts` は release に `signingConfig = signingConfigs.getByName("debug")` を設定済み → キーストア無しで installable APK が出る。`linux/` scaffold あり。`ci.yaml` の `build-linux` は apt で `libmpv-dev ninja-build libgtk-3-dev` を入れている。

## Goals / Non-Goals

**Goals:**
- 対応全プラットフォーム（Windows/macOS/Android/Linux）のインストーラを 1 タグ = 1 Release に揃える。
- タグ push で全自動。手動 dispatch も残す。
- 既存 Windows/macOS ジョブの挙動を壊さない。

**Non-Goals:**
- iOS/iPadOS 配布、本番キーストア署名、macOS 公証、バージョン採番ルール、`ci.yaml` の変更。

## Decisions

### D1: トリガーに `push: tags: ['v*']` を追加
```yaml
on:
  push:
    tags: ['v*']
  workflow_dispatch:
```
タグ push で `github.ref_type == 'tag'` となり、既存 publish ジョブの条件がそのまま発火する。`workflow_dispatch` は維持。
- 代替: `release: types: [created]` イベント → 先に空 Release を作る運用が必要で手間。不採用。

### D2: Android = debug 署名 release APK
`flutter build apk --release` をネイティブ資産リトライループ（`harden-ci-native-downloads` と同型の bash `until`）で包む。出力 `build/app/outputs/flutter-apk/app-release.apk` を `GeekPlayer-android-<suffix>.apk` にリネームしてアップロード。build.gradle 変更不要。
- ubuntu-latest。`flutter pub get` → `build_runner` → build の順は他ジョブと統一。

### D3: Linux = AppImage 化（libmpv 同梱の要否で 2 案 — ユーザー確認待ち）
**重要な事実**: media_kit を使う Flutter アプリは AppImage/Flatpak で `libmpv.so.2` 欠落が既知問題（[media-kit#1055](https://github.com/media-kit/media-kit/issues/1055), [mpv#12027](https://github.com/mpv-player/mpv/issues/12027)）。Flutter の linux release バンドルにはアプリ/エンジン/プラグイン .so は入るが、**システムライブラリ libmpv は入らない**。`flutter_distributor` の appimage maker はこのバンドルを AppImage 化するだけで libmpv を自動同梱しない。可搬性確保には `linuxdeploy -l <libmpv>`（明示同梱）か `appimage-builder`（apt 依存 `libmpv2` をレシピで取り込み）が必要。

共通: ubuntu-latest、apt で `libmpv-dev ninja-build libgtk-3-dev` ＋ AppImage 用 `libfuse2`、`flutter build linux --release`、FUSE 不在対策に **`APPIMAGE_EXTRACT_AND_RUN=1`**。

**採用 = 案B（堅牢, libmpv 同梱）**（ユーザー確認済み 20260608）:
1. apt で `libmpv-dev ninja-build libgtk-3-dev libfuse2` を入れ `flutter build linux --release`。
2. AppDir を作り、Flutter linux バンドル（`build/linux/x64/release/bundle/*`）を `AppDir/usr/` に配置。`.desktop` と PNG アイコンを `AppDir` に用意（アイコンが無ければ Flutter 既定アイコンを流用）。
3. `linuxdeploy`（+ `linuxdeploy-plugin-gtk`）を取得し、メインバイナリ・`libapp.so`・`libflutter_linux_gtk.so` を `-e/-l`、`ldconfig -p | grep libmpv` で解決した `libmpv.so.2` を `-l` で明示同梱、`--output appimage` で AppImage 生成。
4. FUSE 不在対策に `APPIMAGE_EXTRACT_AND_RUN=1` を export。
- 代替（案A 軽量 flutter_distributor / tar.gz）は不採用。理由: media_kit のため libmpv 未同梱だと clean 環境で再生クラッシュし「動くインストーラ」要件を満たさない。

### D4: publish の集約
`publish-github-release` の `needs:` に `build-android-release` と `build-linux-release` を追加。`if: github.ref_type == 'tag'` を維持し、`download-artifact@v4`（`merge-multiple: true`）→ `softprops/action-gh-release@v2` で 4 資産を 1 Release に添付。

### D5: 共通メタデータと命名
各新ジョブにも既存と同じ「Set artifact metadata」ステップ（タグ→`<tag>` / 他→`run-<run_number>`）を置き、`GeekPlayer-<platform>-<suffix>.<ext>` 命名を統一する。

### D6: 全 build ジョブをネイティブ資産リトライで包む
release-artifacts.yaml は harden-ci-native-downloads 以前の作りで Windows/macOS の build にリトライが無く、media_kit libmpv 7z の integrity 失敗で flaky に落ちる。Windows/macOS/Android/Linux の全 `flutter build` を ci.yaml と同型の bash `until`（max 3, 20s backoff, 第三者 action 非依存）で包む。Windows は windows-latest 既定 pwsh を `shell: bash` に統一。

## Risks / Trade-offs

- [AppImage に libmpv が同梱されず実行時に欠落] → media_kit はシステム libmpv 前提（既知問題）。案B を採れば `linuxdeploy -l` で libmpv.so.2 を明示同梱して緩和。案A の場合はホスト libmpv 依存が残り、bundling は follow-up。いずれも CI（ヘッドレス）では GUI 起動確認できないため **同梱の網羅性は初回タグ Release 後に実機検証**（tasks 5.4）。
- [FUSE 不在で appimagetool が失敗] → `APPIMAGE_EXTRACT_AND_RUN=1` ＋ apt `libfuse2` で二重に回避。
- [ネイティブ資産 DL の flaky] → Android/Linux build を既存リトライ idiom で包む。
- [誤タグで Release 自動生成] → `v*` に限定。命名規約（`vX.Y.Z`）を周知。最悪時は Release/タグ手動削除で可逆。
- [Android release APK が debug 署名] → sideload は可能だが Play 配布不可・署名鍵が公開 debug 鍵。Non-Goal として明示済み、正式リリース時に本番鍵へ移行。

## Migration Plan

1. `release-artifacts.yaml` にトリガー＋Android/Linux ジョブ＋publish needs を追加、`app/distribute_options.yaml` を追加。
2. feature ブランチで PR → `workflow_dispatch`（非タグ）で全ビルドジョブが green になることを確認（Release は作られない）。
3. main マージ後、`v0.1.0-rc` 等のプレリリースタグで実起動を検証 → 4 資産添付と AppImage 実機起動を確認。
4. ロールバック: 追加ジョブ/トリガーを削除すれば従来（Windows/macOS 手動のみ）へ復帰。

## Open Questions

- AppImage への libmpv（及び依存共有ライブラリ）同梱の網羅性は、ヘッドレス CI では完全検証できない。初回タグ Release 後に Linux 実機で起動確認し、欠落があれば `distribute_options.yaml` の bundle 指定を追補する（follow-up タスクとして tasks に明記）。

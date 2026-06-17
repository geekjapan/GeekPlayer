## 1. トリガー追加

- [x] 1.1 `release-artifacts.yaml` の `on:` に `push: tags: ['v*']` を追加（`workflow_dispatch` は維持）

## 2. Android リリース APK ジョブ

- [x] 2.1 `build-android-release` ジョブ（ubuntu-latest, working-directory: app）を追加: checkout → flutter-action → Set artifact metadata → `flutter pub get` → `build_runner` → `flutter build apk --release`（ネイティブ資産リトライ idiom で包む）
- [x] 2.2 出力 `build/app/outputs/flutter-apk/app-release.apk` を `GeekPlayer-android-<suffix>.apk` にリネームし `actions/upload-artifact@v4`（name: `geekplayer-android`）でアップロード

## 3. Linux AppImage ジョブ（案B: libmpv 同梱）

- [x] 3.1 AppImage 用の `.desktop` と PNG アイコンを用意（`app/packaging/linux/` 等。既存アイコンが無ければ Flutter 既定アイコンを流用）
- [x] 3.2 `build-linux-release` ジョブを追加: apt で `libmpv-dev ninja-build libgtk-3-dev libfuse2` → flutter-action → Set artifact metadata → `flutter pub get` → `build_runner` → `flutter build linux --release`（ネイティブ資産リトライ idiom で包む）
- [x] 3.3 AppDir を構築（`build/linux/x64/release/bundle/*` を `AppDir/usr/` に配置、`.desktop`/アイコンを設置）
- [x] 3.4 `linuxdeploy` + `linuxdeploy-plugin-gtk` を取得し、`ldconfig -p | grep libmpv` で解決した `libmpv.so.2` を `-l` で明示同梱、`APPIMAGE_EXTRACT_AND_RUN=1 ... --output appimage` で AppImage 生成 → `GeekPlayer-linux-<suffix>.AppImage` を `actions/upload-artifact@v4`（name: `geekplayer-linux`）でアップロード
- [x] 3.5 ビルドログで `libmpv.so.2` が AppImage に取り込まれた旨（linuxdeploy の bundle ログ）を確認

## 4. Release への集約

- [x] 4.1 `publish-github-release` の `needs:` に `build-android-release` と `build-linux-release` を追加（`if: github.ref_type == 'tag'` 維持）
- [x] 4.2 既存の download-artifact（merge-multiple）＋ `softprops/action-gh-release@v2` で 4 資産が 1 Release に添付されることを確認

## 5. 検証

- [x] 5.1 `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release-artifacts.yaml'))"` で YAML 構文を確認
- [x] 5.2 PR を作成し `workflow_dispatch`（非タグ）で Windows/macOS/Android/Linux の 4 ビルドジョブが green（Release 未作成）を確認
- [x] 5.3 （main マージ後）`vX.Y.Z` タグで実起動 → 4 資産添付とリリースノート自動生成を確認 — `v0.1.1` タグの run 27664504896（全 5 ジョブ success）が公開 Release `v0.1.1`（非ドラフト）を生成。4 資産添付確認: `GeekPlayer-windows-v0.1.1.zip` / `GeekPlayer-macos-v0.1.1-unsigned.dmg` / `GeekPlayer-android-v0.1.1.apk` / `GeekPlayer-linux-v0.1.1.AppImage`。`generate_release_notes: true` でリリースノート自動生成（4862 字）も確認
- [ ] 5.4 （follow-up）Linux 実機で AppImage を起動し libmpv 等の同梱欠落がないか確認、欠落あれば linuxdeploy の `--library` 指定を追補 — CI 側で AppImage への libmpv 同梱は確認済み（run 27664504896: `Bundling libmpv: /lib/x86_64-linux-gnu/libmpv.so.2` → `libmpv bundled OK`）。残るは実機起動での動作確認のみ（物理 Linux 環境が必要なため未実施）

## 1. pub-cache キャッシュ（全ジョブ共通）

- [x] 1.1 `analyze-and-test` に `flutter pub get` の前段で `actions/cache@v4` を追加し `~/.pub-cache` を `hashFiles('app/pubspec.lock')` + restore-keys でキャッシュ（キー先頭に OS 識別子）
- [x] 1.2 `build-linux` に同様の pub-cache キャッシュステップを追加（Linux native deps インストールと flutter-action の後、`flutter pub get` の前）
- [x] 1.3 `build-android-debug` に pub-cache キャッシュステップを追加
- [x] 1.4 `build-windows-release` に pub-cache キャッシュステップを追加。**Windows パス `~\AppData\Local\Pub\Cache`** を対象にし、キー先頭を `windows-` にする

## 2. Android Gradle キャッシュ

- [x] 2.1 `build-android-debug` に `~/.gradle/caches` と `~/.gradle/wrapper` のキャッシュを追加。キーは `hashFiles('app/android/gradle/wrapper/gradle-wrapper.properties', 'app/android/**/*.gradle*')`、restore-keys フォールバック付き
- [x] 2.2 キャッシュ復元が build ステップ（`flutter build apk`）より前に配置されていることを確認

## 3. macOS / iOS の CocoaPods + pub-cache キャッシュ

- [x] 3.1 `build-macos` に `~/.pub-cache` と `~/Library/Caches/CocoaPods` のキャッシュを追加（キー基準は `hashFiles('app/pubspec.lock')`、restore-keys 付き）。`flutter config --no-enable-swift-package-manager` の後、`flutter pub get` の前に配置
- [x] 3.2 `build-ios` に同様の CocoaPods + pub-cache キャッシュステップを追加

## 4. spec 同期と検証

- [x] 4.1 既存リトライループ（全 `until ...` ステップ）が変更されず残っていることを確認
- [x] 4.2 `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yaml'))"` 等で YAML 構文の妥当性を確認
- [x] 4.3 PR を作成し CI 自動 run でキャッシュ save（初回 miss）が完走することを確認 — PR #31 run（`refs/pull/31/merge`, 2026-06-08 09:14–09:18Z）で 4 キャッシュキー（Linux-pub / Windows-pub / macOS-pub-pods / Linux-gradle）が新規作成（`created==last_accessed`）＝miss→save 完走を Actions Cache API で確認
- [ ] 4.4 同一 `pubspec.lock` での 2 回目 run（再 push もしくは rerun）でキャッシュ hit（"Cache restored from key"）をログで確認
- [x] 4.5 `openspec/specs/ci-build-matrix/spec.md` へキャッシュ要件を sync（delta の ADDED「CI ジョブは外部ネイティブ資産の取得をキャッシュする」+4 シナリオを本体 spec 末尾に追記、`openspec validate --strict` 通過）

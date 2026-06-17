## Why

CI のネイティブ資産ダウンロードは flaky で、push/PR ごとに 1 ジョブが transient 失敗（Gradle distribution の HTTP 504、media_kit/pdfium の integrity/hash 不一致、sqlite3 の `libsqlite3` ハッシュ不一致）することがある。`harden-ci-native-downloads`（#29/#30）でリトライループを入れたことで多くは自動吸収されるようになったが、根本原因である「毎回ゼロから外部 CDN を叩く」構造は残っており、依然として `gh run rerun --failed` の手動介入が必要なケースがある。ダウンロードをキャッシュして外部取得の回数そのものを減らせば、flaky の発生確率と CI の所要時間を同時に下げられる。

## What Changes

- `analyze-and-test` / `build-android-debug` / `build-linux` の各 `ubuntu-latest` ジョブで pub-cache（`~/.pub-cache`）を `actions/cache` でキャッシュし、sqlite3・media_kit・pdfium 等の prebuilt ネイティブ資産を再ダウンロードしない。
- `build-windows-release` の `windows-latest` ジョブでも pub-cache（Windows パス `~\AppData\Local\Pub\Cache`）をキャッシュし、media_kit の libmpv 取得を減らす。
- `build-android-debug` で Gradle distribution と Gradle caches（`~/.gradle/caches`, `~/.gradle/wrapper`）をキャッシュし、Gradle wrapper の distribution DL 504 を回避する。
- `build-macos` / `build-ios` の `macos-latest` ジョブで CocoaPods のダウンロードキャッシュ（`~/Library/Caches/CocoaPods`）と pub-cache をキャッシュし、libmpv / PDFium tarball の再取得を減らす。
- 既存のネイティブ資産リトライループ（`harden-ci-native-downloads`）は**安全網として残す**。キャッシュは flaky の発生確率を下げる「予防」、リトライは取りこぼしを吸収する「対症」で、両者は併用する。
- キャッシュキーは `pubspec.lock` / Gradle wrapper version / `Podfile.lock` 等のロックファイルハッシュに紐づけ、依存変更時に自然に更新されるようにする。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `ci-build-matrix`: CI ジョブが外部ネイティブ資産の取得をキャッシュして transient ダウンロード失敗への露出を減らす、という新しい要件を追加する。既存のリトライ要件（`ネイティブ資産取得を含むステップは transient 失敗をリトライする`）は変更せず、キャッシュ要件をその補完として併置する。

## Non-goals

- リトライループの削除・置き換えはしない（キャッシュはリトライの代替ではなく補完）。
- リトライ上限回数の変更（バックログに残る別案）はこの change の対象外。
- Flutter SDK 自体のキャッシュ追加はしない（`subosito/flutter-action@v2` の `cache: true` で既に対応済み）。
- 上流（pub/CDN）の恒久障害や、16 KB page support（外部ブロック中）は対象外。
- 自前のミラー/プロキシ・第三者キャッシュ action の導入はしない（公式 `actions/cache` のみ使用）。

## Impact

- 変更ファイル: `.github/workflows/ci.yaml`（全ジョブにキャッシュステップを追加 — `app/.github/workflows/ci.yaml` ではなくリポジトリルートの `ci.yaml:14-277`）。
- spec: `openspec/specs/ci-build-matrix/spec.md`（キャッシュ要件を追加）。
- 依存・API: コード変更なし。CI のみ。`actions/cache@v4` を新規利用。
- リスク: キャッシュ汚染で偽の成功/失敗が出る可能性 → キーをロックファイルハッシュに紐づけ、ネイティブ資産の integrity 検証（既存）とリトライ安全網で緩和。初回 run はキャッシュ miss で従来どおりの所要時間。

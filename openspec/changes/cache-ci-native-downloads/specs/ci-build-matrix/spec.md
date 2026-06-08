## ADDED Requirements

### Requirement: CI ジョブは外部ネイティブ資産の取得をキャッシュする

外部からネイティブ資産（pub-cache 配下の prebuilt 共有ライブラリ、Gradle distribution、CocoaPods tarball 等）を取得する CI ジョブは、それらの取得物を公式 `actions/cache` でキャッシュし、後続 run での再ダウンロードを避けなければならない (MUST)。これは既存のリトライ要件（`ネイティブ資産取得を含むステップは transient 失敗をリトライする`）を置き換えるものではなく、transient ダウンロード失敗への露出を減らす補完として併用しなければならない (MUST)。

キャッシュキーは依存ロックファイル（`pubspec.lock`、Gradle wrapper 定義、`Podfile.lock` 等）のハッシュに紐づけ、依存が変わったときにキャッシュが自然に無効化されるようにしなければならない (MUST)。第三者のキャッシュ用 action や自前ミラーは導入してはならない (MUST NOT)。キャッシュ miss（初回 run やキー変更時）はジョブを失敗させてはならず、フォールバックとして従来どおり外部取得を行わなければならない (MUST)。

#### Scenario: pub-cache のキャッシュ hit で再ダウンロードが省かれる

- **WHEN** `pubspec.lock` を変更しないコミットで CI が再実行される
- **THEN** `~/.pub-cache` のキャッシュが復元され、sqlite3 / media_kit / pdfium 等のネイティブ資産が再ダウンロードされない

#### Scenario: Gradle distribution / caches のキャッシュ hit で 504 を回避する

- **WHEN** `build-android-debug` ジョブが Gradle wrapper 定義を変えずに再実行される
- **THEN** `~/.gradle/caches` と `~/.gradle/wrapper` のキャッシュが復元され、Gradle distribution の再ダウンロードが省かれる

#### Scenario: 依存変更でキャッシュキーが更新される

- **WHEN** `pubspec.lock` または `Podfile.lock` が変更されたコミットで CI が実行される
- **THEN** キャッシュキーが変わり、新しい依存に対して外部取得とキャッシュ再作成が行われる

#### Scenario: キャッシュ miss でもジョブが失敗しない

- **WHEN** 該当キーのキャッシュが存在しない（初回 run またはキー変更直後）状態で CI が実行される
- **THEN** ジョブはキャッシュ miss を許容し、従来どおり外部取得（必要に応じてリトライ）を経てビルド/テストを完了する

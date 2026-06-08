## Context

`harden-ci-native-downloads`（#29/#30）でネイティブ資産取得ステップにリトライループ（max 3, 20s backoff, 第三者 action 非依存）を導入し、flaky の多くは自動吸収されるようになった。しかし「毎 run ゼロから外部 CDN を叩く」構造は残り、Gradle distribution の 504、media_kit/pdfium の integrity 不一致、sqlite3 の hash 不一致が依然として発生し、`gh run rerun --failed` の手動介入が必要なケースが残る。

現状（`.github/workflows/ci.yaml`）:
- 全ジョブが `subosito/flutter-action@v2` の `cache: true` で **Flutter SDK のみ** キャッシュ。pub-cache・Gradle・CocoaPods はキャッシュされていない。
- `pubspec.lock` は tracked（`app/pubspec.lock`）。`gradle-wrapper.properties` は `app/android/gradle/wrapper/`。`Podfile.lock` は **未コミット**（`flutter build` 内の pod install が生成）。

制約: 公式 `actions/cache` のみ使用（第三者 action 禁止）。ネイティブ資産は integrity 検証付きで取得されるため、キャッシュ汚染は検証・リトライで二重に緩和できる。

## Goals / Non-Goals

**Goals:**
- 外部ネイティブ資産取得の回数を減らし、transient ダウンロード失敗の発生確率と CI 所要時間を下げる。
- キャッシュキーをロックファイルに紐づけ、依存変更時に自然に無効化する。
- 既存リトライループを安全網として温存する（キャッシュは予防、リトライは対症）。

**Non-Goals:**
- リトライループの削除・置換、リトライ回数の調整。
- Flutter SDK のキャッシュ追加（`cache: true` で対応済み）。
- 自前ミラー／第三者キャッシュ action の導入。
- 16 KB page support（外部ブロック中）や上流 CDN の恒久障害対応。

## Decisions

### D1: 公式 `actions/cache@v4` のみを使用
第三者 action 禁止のリポジトリ方針（リトライ実装と同じ）に合わせる。`actions/cache` はキャッシュ miss でジョブを失敗させないため、フォールバック（従来の外部取得）が自動で成立する。
- 代替: `gradle/actions/setup-gradle`（Gradle 専用キャッシュ）→ 第三者依存になり方針外。`actions/setup-java` の Gradle cache → Java セットアップ前提が増える。いずれも不採用。

### D2: OS ファミリ別にキャッシュ scope を分ける

| ジョブ | runner | キャッシュ対象 path | キー基準 |
|--------|--------|---------------------|----------|
| `analyze-and-test` / `build-linux` | ubuntu | `~/.pub-cache` | `app/pubspec.lock` |
| `build-android-debug` | ubuntu | `~/.pub-cache` ＋ `~/.gradle/caches`, `~/.gradle/wrapper` | pub: `app/pubspec.lock` / gradle: `app/android/gradle/wrapper/gradle-wrapper.properties` + `app/android/**/*.gradle*` |
| `build-windows-release` | windows | `~\AppData\Local\Pub\Cache` | `app/pubspec.lock` |
| `build-macos` / `build-ios` | macos | `~/.pub-cache` ＋ `~/Library/Caches/CocoaPods` | `app/pubspec.lock` |

- pub-cache に sqlite3・media_kit（libmpv/mimalloc）・pdfium 等の pub 配布ネイティブ資産が落ちるため、**全 6 ジョブで共通してキャッシュする**。pub-cache の path は OS で異なる: Unix（ubuntu/macos）は `~/.pub-cache`、Windows は `~\AppData\Local\Pub\Cache`（= `%LOCALAPPDATA%\Pub\Cache`）。`subosito/flutter-action@v2` は既定で `PUB_CACHE` を再配置せず、この既定 path に解決される。
- Gradle は distribution（`~/.gradle/wrapper`）と依存 caches（`~/.gradle/caches`）の双方をキャッシュし、504 を回避。
- macOS/iOS は CocoaPods のグローバルダウンロードキャッシュ（`~/Library/Caches/CocoaPods`）をキャッシュ。libmpv/PDFium の XCFramework はここ経由で取得される。

### D3: キャッシュキーはロックファイルハッシュ + `restore-keys` フォールバック
`key: <os>-<scope>-${{ hashFiles('<lockfile>') }}`、`restore-keys: <os>-<scope>-` を併用。完全一致 miss でも prefix 一致で部分復元でき、差分だけ再取得する。キーの先頭に OS 識別子（`runner.os` もしくは `ubuntu-`/`windows-`/`macos-` リテラル）を入れ、OS 跨ぎの汚染を防ぐ。

- **`hashFiles()` の path は GITHUB_WORKSPACE（リポジトリルート）基準**で、ジョブの `defaults.run.working-directory: app` の影響を受けない。よってキーは `hashFiles('app/pubspec.lock')` のように **`app/` プレフィックス付き**で書く（`hashFiles('pubspec.lock')` は空ハッシュになり全 run でキー衝突するバグになる）。

- CocoaPods は `Podfile.lock` が build 前に存在しないため、`pubspec.lock` をキー基準にする（Flutter プラグイン解決が pod 依存を駆動するため妥当な代理）。

### D4: 既存リトライループは温存
キャッシュ hit してもネイティブ資産の一部が build 時に再取得される場合があり、その transient 失敗をリトライが吸収する。spec 上もリトライ要件は変更せず、キャッシュ要件を ADDED で併置。

### D5: キャッシュステップの配置
各ジョブで `flutter pub get` の**前**に pub-cache restore を置く。Gradle/CocoaPods キャッシュは build ステップの前。`actions/cache` は post-job で自動 save するため明示 save は不要。

## Risks / Trade-offs

- [キャッシュ汚染で壊れた資産が固定化] → キーをロックファイルに紐づけ依存変更で無効化。ネイティブ資産の integrity 検証（既存）＋リトライ安全網で二重緩和。最悪時はキャッシュ手動 purge。
- [pub-cache に巨大バイナリが入りキャッシュサイズが膨らむ／10GB リポジトリ上限を圧迫] → scope を絞り（SDK は別管理）、restore-keys で世代を 1 つに収束させる。問題化すれば対象 path を更に限定。
- [初回 run / キー更新直後はキャッシュ miss] → 従来どおりの所要時間で完走（失敗しない）。期待どおりの挙動。
- [CocoaPods キャッシュキーが `pubspec.lock` 代理のため pod 専用変更を取りこぼす] → restore-keys 部分復元 ＋ pod install の差分解決でカバー。pod 取得失敗はリトライが吸収。

## Migration Plan

1. `.github/workflows/ci.yaml` の各ジョブにキャッシュステップを追加（コード変更なし）。
2. feature ブランチで PR を作成 → CI 自動 run でキャッシュ save が走る（初回は miss）。
3. PR を再 push もしくは main マージ後の run でキャッシュ hit を確認（ログの "Cache restored from key"）。
4. ロールバック: キャッシュステップは独立しており、削除すれば即座に従来挙動へ戻る。リトライ安全網は常に有効なので機能退行リスクは低い。

## Open Questions

- CocoaPods について `~/Library/Caches/CocoaPods` に加え `app/macos/Pods`・`app/ios/Pods` 自体もキャッシュすべきか（hit 率向上 vs 汚染リスク増）。初版はグローバルキャッシュのみとし、効果が薄ければ apply 時に追加検討。

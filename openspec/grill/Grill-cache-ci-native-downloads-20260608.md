# Grill — cache-ci-native-downloads (20260608)

## cache-ci-native-downloads — 残課題なし (20260608)

Phase 1（自己グリル）/ Phase 2（cross-cutting: 唯一の active change のため自明、依存・所有権の衝突なし）を実施。genuine な論点は複数見つかり**全てインラインで自己解決**。ユーザー確認が必須の残課題は無し。

### 自己解決した論点（インライン修正済み）
- **build-windows-release の欠落**: 初版 design の OS 別表は ubuntu/macos のみで Windows を欠落。Windows も media_kit libmpv を DL する flaky ジョブ（既存リトライコメント "transient media_kit native download/integrity failures" 該当）。→ proposal/design D2 表/tasks 1.4 に Windows pub-cache キャッシュを追加。
- **Windows の pub-cache パス差**: Unix は `~/.pub-cache` だが Windows は `~\AppData\Local\Pub\Cache`（`%LOCALAPPDATA%\Pub\Cache`）。→ design D2 に OS 別 path を明記、tasks 1.4 に Windows path を指定。
- **`hashFiles()` の基準ディレクトリ**: `hashFiles()` は GITHUB_WORKSPACE（リポジトリルート）基準で、ジョブの `working-directory: app` の影響を受けない。`hashFiles('pubspec.lock')` だと空ハッシュ→全 run キー衝突のバグになる。→ design D3 と全 tasks のキー基準を `app/pubspec.lock` / `app/android/gradle/wrapper/gradle-wrapper.properties` 等の **`app/` プレフィックス付き**に統一。

### 検討して問題なし／自己判断で確定した点
- **CocoaPods キーの `pubspec.lock` 代理**: `Podfile.lock` は未コミット（build 内 pod install が生成）で restore 時に不在。Flutter プラグイン解決が pod 依存を駆動するため `pubspec.lock` を代理キーにし、restore-keys 部分復元 ＋ pod install 差分解決で補完。design D3／Open Question。
- **`app/macos/Pods`・`app/ios/Pods` 自体のキャッシュ**: 初版はグローバル `~/Library/Caches/CocoaPods` のみ（汚染リスク低）。hit 率が不足なら後続検討。design Open Question に deferred として記録。
- **第三者 action 不使用**: 公式 `actions/cache@v4` のみ。`gradle/actions/setup-gradle` 等は方針外。design D1。
- **リトライ安全網の温存**: spec はリトライ要件を変更せず、キャッシュ要件を ADDED で併置（予防＋対症の二層）。design D4・tasks 4.1。
- **キャッシュ miss 時の挙動**: `actions/cache` は miss でジョブを失敗させず従来取得へフォールバック。spec シナリオ「キャッシュ miss でもジョブが失敗しない」で担保。
- **キャッシュサイズ/10GB 上限**: restore-keys で世代を 1 つに収束。LRU eviction で過剰分は自動退避。design Risks。
- **可逆性**: キャッシュステップ削除のみで従来挙動へ復帰。リトライ常時有効のため機能退行リスク低。

`openspec validate cache-ci-native-downloads --type change --strict` → valid（インライン修正後 再パス）。

**Status**: Resolved — 残課題なし（Windows 欠落・path 差・hashFiles 基準を inline 修正済み）。grill ゲートをクリアし opsx:apply 可。

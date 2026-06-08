# Grill — harden-ci-native-downloads (20260608)

## harden-ci-native-downloads — 残課題なし (20260608)

Phase 1（自己グリル）/ Phase 2（cross-cutting、唯一の active change のため自明）を実施。genuine な論点は 1 件見つかり**インラインで自己解決**。ユーザー確認が必須の残課題は無し。

### 自己解決した論点
- **Windows の既定 shell は pwsh**（bash ではない）: `windows-latest` の `flutter build windows` ステップは `shell:` 未指定で pwsh 実行されており、design D1 の bash `until` リトライループはそのままでは動かない。→ design D2・tasks 1.3/3.3 を更新し、**Windows のリトライ build ステップに `shell: bash` を明示**（Git Bash 同梱）することで全ジョブ単一 bash idiom に統一。`openspec validate --strict` 再パス。

### 検討して問題なしと判断した点
- **第三者 action 不使用**: bash `until ... do; ... exit 1` で transient 吸収しつつ最終失敗を伝播（`&& break` 方式の exit 0 バグを回避）。design D1。
- **リトライ対象の限定**: ネイティブ資産取得を含む重いステップ（`flutter test` / `flutter build *`）のみ。`pub get`/`build_runner`/analyze/format/OSS/16KB ゲートはラップせず、恒久障害の検知能力を維持。design D2/D4・spec の「永続的失敗は上限後 fail」シナリオ。
- **sqlite3 ハッシュ不一致**: rerun（run 27120760110 再実行）で analyze-and-test が success → transient と実証済み。リトライで吸収可。恒久差し替えなら依存更新（Non-Goal/別 follow-up）。
- **build-macos の SPM 無効化**: build-ios と同形（`flutter config --no-enable-swift-package-manager`）。SPM PDFium artifact 破損（`already exists in file system`）を回避し CocoaPods 経路へ統一、リトライ対象に揃う。MODIFIED 要件で header 完全一致を確認。
- **可逆性**: 各 `run:` をラップ前に戻すだけ。

**Status**: Resolved — 残課題なし（Windows shell は inline 修正済み）。grill ゲートをクリアし opsx:apply 可。

## Context

CI (`.github/workflows/ci.yaml`) は 6 ジョブ。自動実行初日、全ジョブが外部 CDN からのネイティブ資産取得で flaky に失敗した（詳細は proposal）。失敗の本質は取得層の transient エラー（HTTP 5xx / integrity 不一致 / partial download）と、macOS だけ SPM 経由で PDFium xcframework artifact が破損する点。コードロジックは健全（analyze/format/test-local green、rerun で analyze-and-test green）。

## Goals / Non-Goals

**Goals:**
- transient なネイティブ資産取得失敗を自動リトライで吸収し、CI の偽陽性を減らす。
- 恒久障害（コード回帰・上流の永続バイナリ差し替え）の検知能力は維持する（リトライ上限後は fail）。
- build-macos の SPM PDFium 破損を解消する。
- 第三者 GitHub Action 依存を増やさない（監査性・サプライチェーン）。

**Non-Goals:**
- ネイティブ資産の actions/cache 化（別途検討可。今回はリトライ + SPM 修正に集中）。
- ジョブのビルドコマンド本体・runner・成果物・Flutter pin・16KB ゲートの変更。
- sqlite3 / media_kit の依存バージョン更新やセルフホスト。
- build smoke を required から外す等の branch protection 設定（YAML 外）。

## Decisions

### D1: 第三者 action ではなく bash リトライループ
`nick-fields/retry` 等の marketplace action は使わず、各ステップに `run:` の bash リトライを直書きする。理由: サプライチェーン/監査性、ピン留め管理の回避、挙動の透明性。共通パターン:
```bash
n=0; max=3
until <command>; do
  n=$((n+1))
  if [ "$n" -ge "$max" ]; then echo "::error::failed after $max attempts"; exit 1; fi
  echo "::warning::attempt $n failed; retrying in 20s"; sleep 20
done
```
- `until ... do` 形式: 成功で即抜け、上限超過で `exit 1`。最終失敗を確実に伝播（`&& break` 方式の「全失敗でも exit 0」バグを回避）。
- 固定 20s バックオフ。CDN の一時 5xx / 反映遅延に十分。

### D2: リトライ対象ステップ
ネイティブ資産を取得する重いステップのみラップ:
- `analyze-and-test`: `flutter test`（sqlite3 native asset build）
- `build-android-debug`: `flutter build apk --debug`
- `build-windows-release`: `flutter build windows --release`
- `build-macos`: `flutter build macos --release ...`
- `build-linux`: `flutter build linux --release ...`
- `build-ios`: `flutter build ios --release --no-codesign ...`

`flutter pub get` / `dart run build_runner build` はラップしない（観測された flaky の主因ではなく、pub は内部リトライを持つ）。スコープを最小化し、失敗の所在を明確に保つ。

**注意（Windows / PowerShell）— 重要**: GitHub Actions の `windows-latest` の既定 shell は **pwsh（PowerShell）** であり bash ではない（現状の `flutter build windows` ステップは `shell:` 未指定なので pwsh で動いている）。D1 の bash `until` ループは pwsh では動かないため、**`build-windows-release` のリトライ build ステップには明示的に `shell: bash` を付与する**（`windows-latest` には Git Bash が同梱されており `flutter` も bash から実行可能）。これで全 6 ジョブのリトライ idiom を単一の bash 実装に統一できる。パッケージングの `shell: pwsh` ステップは別ステップで不変。

### D3: build-macos の SPM 無効化
`build-ios` と同じく `flutter config --no-enable-swift-package-manager` を `flutter pub get` の前に追加。SPM の PDFium xcframework artifact 破損（`already exists in file system`）を回避し、CocoaPods 経路に統一。これでリトライ（D1）が CocoaPods ダウンロードにも効く。

### D4: 16KB ゲート等の付随ステップは据え置き
`build-android-debug` の `flutter build apk` のみリトライ。後続の `check_so_alignment.py` / artifact upload は決定的なのでラップしない。

## Risks / Trade-offs

- **恒久障害でも 3 回試行する分の時間増**: 失敗時に最大 +40s/ジョブ。許容範囲（public repo・無料）。
- **リトライが本物のビルド不安定を隠蔽する懸念**: 対象を「取得層 transient」想定の重いステップに限定し、analyze/format/OSS など決定的ゲートはラップしない。恒久障害は上限後 fail するため検知は維持。
- **sqlite3 ハッシュ不一致が恒久（上流差し替え）だった場合**: リトライでは解決しない。今回は rerun で成功＝transient を確認済み。恒久化したら別途依存更新で対応（Non-Goal、follow-up）。
- **可逆性**: 各ステップの `run:` をラップ前に戻すだけで原状復帰可能。

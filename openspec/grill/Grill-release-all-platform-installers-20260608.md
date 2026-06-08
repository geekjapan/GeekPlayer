# Grill — release-all-platform-installers (20260608)

## release-all-platform-installers — Grill残課題 (20260608)

Phase 1（自己グリル）/ Phase 2（cross-cutting）実施。技術前提を docs/web で検証し、誤前提 1 件を発見・design をインライン修正。ユーザー確認が必須の残課題 1 件（Q1）。

### Q1. Linux AppImage に libmpv を最初から同梱するか（案A 軽量 / 案B 堅牢）
- **対象**: design D3、specs/release-artifacts（Linux AppImage 要件）、tasks §3
- **なぜ重要**: media_kit を使う Flutter アプリは AppImage で `libmpv.so.2` 欠落が既知問題。`flutter_distributor` だけでは libmpv を同梱せず、clean な Linux 環境で **media 再生時にクラッシュ**しうる。同梱するか否かで CI 構成の重さと「動くインストーラかどうか」が変わる。
- **検討した選択肢**:
  - A) 軽量: `flutter_distributor ... --targets appimage` をそのまま使用。実装軽い。ホストに libmpv がある環境でのみ再生可。可搬性は follow-up。
  - B) 堅牢: `linuxdeploy` + `linuxdeploy-plugin-gtk` で AppDir を組み、`libmpv.so.2` を `-l` で明示同梱（.desktop/アイコン整備込み）。CI 設定は増えるが self-contained。
- **推奨案**: **B（堅牢）**。「インストーラを Release に乗せる」目的に対し、再生でクラッシュする AppImage は実質未達。media_kit#1055 / mpv#12027 が libmpv 同梱の必要性を示す。「一旦」でも“動く”ことを優先したい。
- **不足インプット**: ユーザーが「一旦＝とにかく軽く出す（案A、可搬性は後回し）」を望むか、「一旦でも動くものを（案B）」を望むか。
- **Status**: Resolved — 案B（堅牢, libmpv 同梱）を採用（ユーザー確認 20260608）。design D3 確定版、specs に「AppImage に libmpv が同梱される」シナリオ追加、tasks §3 を linuxdeploy アプローチへ書き換え。

### 自己解決した論点（インライン修正済み）
- **誤前提の訂正**: 初版 design は「flutter_distributor + distribute_options.yaml で libmpv を bundle」としていたが、flutter_distributor は libmpv を自動同梱しない（web 検証）。design D3 を 2 案併記＋事実説明に修正、Risks も更新。

### 検討して問題なし／自己判断で確定した点
- **iOS/iPadOS スキップ**: ユーザー決定。証明書なしで installable ipa 不可。spec で対象外を明示。
- **Android debug 署名 release APK**: `android/app/build.gradle.kts` は release に `signingConfig = signingConfigs.getByName("debug")` 設定済み → キーストア不要で `app-release.apk` が installable。build.gradle 変更不要を確認。
- **タグ push 自動公開**: `on: push: tags: ['v*']` で `github.ref_type=='tag'` となり既存 publish 条件がそのまま発火。`auto-update` spec の `vX.Y.Z` 前提と整合。
- **ネイティブ資産 flaky**: Android/Linux build を既存リトライ idiom（harden-ci-native-downloads）で包む。
- **cross-cutting**: 他 active change は `cache-ci-native-downloads`（ci.yaml のみ編集、PR #31）。本 change は `release-artifacts.yaml` のみ編集で **ファイル所有権の衝突なし**。capability も `release-artifacts`（新規）で `ci-build-matrix` と分離。依存 DAG 単純（独立）。
- **FUSE 不在**: `APPIMAGE_EXTRACT_AND_RUN=1` + apt `libfuse2` で回避。
- **可逆性**: 追加ジョブ/トリガー削除で従来（Windows/macOS 手動のみ）へ復帰。

`openspec validate release-all-platform-installers --type change --strict` → valid（インライン修正後 再パス）。

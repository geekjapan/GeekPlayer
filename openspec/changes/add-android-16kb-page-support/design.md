## Context

Android 15+ は 16 KB メモリページサイズへ移行中で、同梱 `.so` の LOAD セグメントが 16 KB（`p_align >= 0x4000`）でアラインメントされていないと、16 KB ページデバイスで起動時に互換性警告が出る（将来は動作不能リスク）。

実測（`add-android-apk-install-handoff` 実機検証時にビルドした `app-debug.apk`、`llvm-readelf -l`）:

| `.so` | LOAD `p_align` | 判定 |
|---|---|---|
| libflutter.so | 0x10000 | ✅ |
| libdartjni.so | 0x4000 | ✅ |
| libmpv.so（media_kit） | 0x4000 | ✅ |
| libmediakitandroidhelper.so | 0x4000 | ✅ |
| libpdfium.so | 0x4000 | ✅ |
| libsqlite3.so | 0x4000 | ✅ |
| **libonnxruntime.so** | **0x1000** | ❌ |
| libVkLayer_khronos_validation.so | 0x10000 | ✅（debug 専用・release 非同梱） |

**唯一の非対応は `libonnxruntime.so`**（`onnxruntime: ^1.4.1`、`app/pubspec.yaml:67`）。

**致命的な制約**: `onnxruntime` pub パッケージの**最新版は 1.4.1（現用と同一）**で、これより新しい版は存在しない（pub.dev API で確認）。よって「依存バージョンを上げれば直る」という単純経路は**現時点では使えない**。

## Goals / Non-Goals

**Goals:**
- 配布 APK の `lib/arm64-v8a/*.so` をすべて 16 KB アラインメントにし、16 KB エミュレータで警告ゼロ起動を達成する。
- CI（`build-android-debug`）に 16 KB アラインメント回帰検査を追加する。
- onnxruntime（AI upscale 専用・Experimental・default-OFF）の挙動を変えずに remediation する。

**Non-Goals:**
- Android 以外のプラットフォーム、arm64-v8a 以外の ABI。
- onnxruntime の EP 構成・実行ロジック（ADR-0007）の変更。
- Play ストア要件対応（GitHub Releases 配布で対象外）。

## Decisions

### D1. remediation 方針: 4 つの選択肢と推奨

`onnxruntime` pub の新版が無い以上、取りうるのは次の 4 択。

- **A. 上流対応待ち（deferral）**: 何もせず、`onnxruntime` pub が 16 KB 対応 ORT を同梱する版を出すまで待つ。残存リスクを readiness に明記。
  - 利点: コストゼロ・回帰リスクなし。AI upscale は opt-in 実験機能・ストア非経由なので実害は警告のみ。
  - 欠点: いつ解消するか上流依存。16 KB 必須デバイス登場で実験機能が壊れる。
- **B. AAR 差し替え（vendor a 16 KB-aligned ORT AAR）**: Microsoft 公式 `onnxruntime-android` AAR（v1.20+ は 16 KB 対応）を、pub パッケージが同梱する古い AAR に上書き/差し替える（Gradle の resolutionStrategy / 自前 plugin patch / dependency_overrides 相当）。
  - 利点: 今すぐ 16 KB 化できる。Dart API はそのまま。
  - 欠点: 上流 pub の内部実装に侵食。ORT ネイティブ ABI と Dart binding の整合検証が必要。保守コスト高。
- **C. 別 binding へ移行**: 16 KB 対応 ORT を同梱する別の Flutter パッケージ（例 `flutter_onnxruntime` 等）へ乗り換え。
  - 利点: 上流保守された 16 KB 対応を得られる可能性。
  - 欠点: Dart API 差異で ml-runtime（ADR-0007 step1–4）の OrtSession/OrtValue 周りを書き換え。回帰リスク大。
- **D. arm64 で onnxruntime を同梱しない条件付きビルド**: 不可。`.so` はビルド時同梱で、runtime トグルでは除去できない。AI upscale を Android で機能削除する選択になり non-goal。

**推奨**: 第一候補 **A（deferral）+ 監査/CI 整備**。根拠: (1) AI upscale は Experimental・default-OFF・opt-in で実害は警告のみ、(2) 配布は GitHub Releases でストア必須要件に非該当、(3) B/C は侵襲・回帰コストが現在のリスク（警告のみ）に見合わない。ただし **CI の 16 KB 検査と監査手順は今すぐ整備**し、上流対応版が出た瞬間に検証・適用できる状態にする。B は 16 KB 必須デバイスが現実化したら昇格。

> これは本 change の**核心的なユーザー決定事項**。A で「検査基盤＋待機」に倒すか、B で「今すぐ侵襲的に 16 KB 化」するかは apply 前に確定する（Open Questions Q1）。

### D2. CI 16 KB 検査の実装方式

`build-android-debug`（`.github/workflows/ci.yaml:57-84`、`ubuntu-latest`）の APK ビルド後に検査ステップを追加。

- 方式: **NDK 非依存の自己完結スクリプト**で APK を unzip し、各 `lib/arm64-v8a/*.so` の ELF program header を読み、全 LOAD セグメントの `p_align >= 0x4000` を検査（`libVkLayer_*.so` は除外）。非対応があれば非ゼロ終了。
  - 実装手段の候補: (a) Python の純正 ELF パーサ（外部依存なし、リポジトリにスクリプト追加）、(b) Flutter の Android セットアップで入る NDK の `llvm-readelf`、(c) Google 配布の `check_elf_alignment.sh`。
  - **推奨 (a)**: CI 環境差に強く、NDK 取得を待たず、ローカル監査にも流用可能。`tool/` 配下にスクリプトを置く。
- **方針 A 採用時の扱い**: 現状 `libonnxruntime.so` が非対応のため、検査をそのまま fail にすると CI が赤になる。→ 検査スクリプトに **既知の例外リスト（`libonnxruntime.so`）を warning 扱いで許容**し、それ以外の `.so` が 16 KB を割ったら fail、とする二段構え。onnxruntime が解消したら例外を外して厳格 fail に切替（Q2）。

### D3. 検証環境

- 16 KB エミュレータ: `sdk_gphone16k`（API 35+、arm64）。ローカル/手動で起動→警告ダイアログ非表示とホーム描画を確認。
- CI ではエミュレータ起動はしない（静的アラインメント検査のみ）。

## Risks / Trade-offs

- [方針 A だと 16 KB 化が先送り] → CI 検査と監査基盤を先に整え、上流更新を検知でき次第すぐ適用。readiness に残存リスクを明記し「暗黙に放置」を防ぐ。
- [方針 B（AAR 差し替え）は ORT ネイティブと Dart binding の不整合で実行時クラッシュの恐れ] → 採用時は 16 KB 実機で AI upscale を実走（モデル DL→推論）して回帰確認。binding バージョンと ORT バージョンの対応表を design に追記。
- [CI 検査の例外リストが恒久化して形骸化] → 例外は `libonnxruntime.so` のみ・コメントで撤去条件を明記し、撤去を別タスク化。
- [`onnxruntime` pub が今後も更新されない] → B/C の昇格判断を readiness のレビュー項目に組み込む。

## Migration Plan

1. 監査スクリプト（`tool/`）と CI 検査ステップを追加（onnxruntime を既知例外として warning 許容）。
2. 16 KB エミュレータでの手動検証手順を記録。
3. （方針 A）readiness に残存リスクを明記してクローズ。上流更新を watch。
4. （将来 / 方針 B 昇格時）16 KB 対応 ORT AAR を差し替え→例外撤去→CI 厳格化→16 KB 実機で AI upscale 実走回帰。
- ロールバック: 依存・AAR 変更を伴わない方針 A は実質ロールバック不要。B 採用時は pubspec / Gradle 変更の revert で戻す。

## Open Questions

- **Q1**: remediation 方針は A（検査基盤＋待機、推奨）か、B（今すぐ AAR 差し替えで 16 KB 化）か。AI upscale を 16 KB 必須デバイスで動かす必要性の見込みで決まる。**ユーザー確定事項**。
- **Q2**: CI 検査は当初から `libonnxruntime.so` を warning 例外にするか（方針 A 前提）、それとも例外なし厳格 fail にして B を即実施するか。Q1 に従属。
- **Q3**: 監査スクリプトの実装は純正 Python ELF パーサ（推奨）か、NDK `llvm-readelf` 依存か。
- **Q4**: 方針 B 採用時、Microsoft `onnxruntime-android` のどのバージョン（16 KB 対応の最小）を pin するか、pub binding(1.4.1) の期待 ORT ABI と互換か。

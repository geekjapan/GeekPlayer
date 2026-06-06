## Why

Android は 15 以降、16 KB メモリページサイズのデバイス（Pixel 8 以降の一部、`sdk_gphone16k` エミュレータなど）への移行を進めており、同梱するネイティブ共有ライブラリ（`.so`）の LOAD セグメントが 16 KB アラインメント（`p_align >= 0x4000`）でないと、起動時に「Android App Compatibility」互換性警告が出る。現状は警告のみで起動は継続できるが、将来 16 KB 必須のデバイスでは動作不能になるリスクがある。

`add-android-apk-install-handoff` の実機検証中（`sdk_gphone16k` エミュレータ）にこの警告が顕在化した。ビルド済み APK の `lib/arm64-v8a/*.so` を `llvm-readelf -l` で監査した結果、**16 KB 非対応は `libonnxruntime.so`（LOAD `p_align=0x1000`=4 KB）の 1 つだけ**で、`libflutter.so`/`libmpv.so`（media_kit）/`libmediakitandroidhelper.so`/`libpdfium.so`/`libsqlite3.so`/`libdartjni.so` はすべて `0x4000` 以上で対応済みと判明した（`libVkLayer_khronos_validation.so` は debug 専用・release 非同梱）。`libonnxruntime.so` は `onnxruntime: ^1.4.1`（`app/pubspec.yaml:67`）が同梱するものである。

## What Changes

- **監査手順の定義**: ビルド済み APK の `lib/arm64-v8a/*.so` について、各 `.so` の LOAD セグメント `p_align` が 16 KB（`0x4000`）以上かを `llvm-readelf -l`（NDK 同梱）で検査する手順を確立する。
- **`onnxruntime` の 16 KB アラインメント解消**: 16 KB 対応の `libonnxruntime.so` を同梱する `onnxruntime` pub パッケージのバージョンへ更新する。上流（pub パッケージ / Microsoft ONNX Runtime AAR）が 16 KB 対応版を提供していない場合の代替（ABI フィルタ・依存の opt-in 隔離・対応待ち判断）は design で決定する。
- **CI 継続検査の追加**: `build-android-debug` ジョブ（`.github/workflows/ci.yaml:57-84`）にビルド後の 16 KB アラインメント検査ステップを追加し、非対応 `.so` の混入を回帰検出する。
- **16 KB エミュレータでの検証手順**: `sdk_gphone16k` 系イメージで起動し互換性警告が出ないことを確認する手順を記録する。
- **影響範囲の確認**: 修正対象は AI upscale（onnxruntime）のみ。onnxruntime は **Experimental・default-OFF・opt-in**（ADR-0007）であり、16 KB 互換性リスクは実験的機能に限定される点を仕様として明確化する。

## Capabilities

### New Capabilities

- `android-16kb-compatibility`: Android 16 KB ページサイズデバイスにおける同梱ネイティブライブラリの ELF アラインメント要件、APK 監査手順、`libonnxruntime.so` の remediation、16 KB エミュレータ検証手順を規定する。

### Modified Capabilities

- `ci-build-matrix`: `build-android-debug` ジョブに、ビルド済み APK 内 `lib/arm64-v8a/*.so` の 16 KB ELF アラインメント検査ステップを追加する（非対応 `.so` で fail）。

## Non-goals

- **iOS / Linux / Windows / macOS への対応**: 16 KB ページ問題は Android 固有。他プラットフォームのビルドや `.so` には一切変更を加えない。
- **arm64-v8a 以外の ABI**: 16 KB ページは 64-bit（arm64）デバイスの話。`armeabi-v7a`（32-bit）や x86 系は対象外。
- **onnxruntime のメジャー機能変更**: EP 構成・モデル実行ロジック（ADR-0007 step1–4）の挙動は変えない。本変更はライブラリのアラインメント（同梱バイナリの差し替え）に限定する。
- **AI upscale をデフォルト有効化すること**: Experimental・default-OFF の方針は維持する。
- **Play ストア要件への適合作業**: GeekPlayer は GitHub Releases 配布（ストア非経由）で Play の 16 KB 必須要件には直接かからない。本変更は実機互換性の先行対応であり、ストア審査対応ではない。

## Impact

- **依存**: `app/pubspec.yaml:67` の `onnxruntime: ^1.4.1` を 16 KB 対応版へ更新（バージョンは design で確定）。`pubspec.lock` 更新。
- **CI**: `.github/workflows/ci.yaml`（`build-android-debug` ジョブ）に検査ステップ追加。
- **関連 capability（挙動非変更）**: `onnx-upscaler-runtime` / `gpu-execution-providers` / `ai-image-upscaler` — 同梱 `libonnxruntime.so` の供給元が変わるが、API・EP 構成・実行挙動は不変。バージョン更新で API 互換性が崩れないことを検証する（onnxruntime Dart API の breaking change 有無）。
- **検証環境**: 16 KB ページのエミュレータ（`sdk_gphone16k`、API 35+）。CI（`ubuntu-latest`）では静的アラインメント検査のみ（エミュレータ起動は対象外）。
- **ドキュメント**: `v0-2-foundation-readiness` の roadmap readiness checklist に 16 KB 互換性項目を追記する余地（design で判断）。

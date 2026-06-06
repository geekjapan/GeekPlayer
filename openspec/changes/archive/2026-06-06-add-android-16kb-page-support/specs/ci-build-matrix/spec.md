## ADDED Requirements

### Requirement: build-android-debug job verifies 16 KB ELF alignment

`build-android-debug` ジョブ（`.github/workflows/ci.yaml`）は、APK ビルド後に同梱 `lib/arm64-v8a/*.so` の 16 KB ELF アラインメントを検査するステップを MUST 実行する。`libVkLayer_*.so` を除くいずれかの `.so` の LOAD セグメント最大 `p_align` が `0x4000` 未満の場合、ジョブは fail する。これにより 16 KB 非対応ライブラリの混入を継続的に回帰検出する。

#### Scenario: 全ライブラリが 16 KB アラインメントなら CI は通過する

- **WHEN** `build-android-debug` ジョブがビルド済み APK の `lib/arm64-v8a/*.so` を検査する
- **AND** `libVkLayer_*.so` を除く全 `.so` の LOAD `p_align` が `0x4000` 以上である
- **THEN** 検査ステップは成功し、ジョブは APK アーティファクトをアップロードする

#### Scenario: 16 KB 非対応ライブラリが混入すると CI が fail する

- **WHEN** `lib/arm64-v8a/` のいずれかの `.so`（`libVkLayer_*.so` を除く）の LOAD `p_align` が `0x4000` 未満である
- **THEN** 検査ステップは非ゼロ終了し、`build-android-debug` ジョブは fail する

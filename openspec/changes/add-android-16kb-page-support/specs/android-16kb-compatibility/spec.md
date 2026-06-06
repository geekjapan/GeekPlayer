## ADDED Requirements

### Requirement: 配布 APK の arm64-v8a ネイティブライブラリは 16 KB ページアラインメントを満たす

配布対象の Android APK に同梱される `lib/arm64-v8a/*.so`（debug 専用の Vulkan validation layer `libVkLayer_*.so` を除く）は、すべての LOAD セグメントが 16 KB（`p_align >= 0x4000`）でアラインメントされていなければならない（MUST）。これにより 16 KB ページサイズのデバイスで「Android App Compatibility」互換性警告が出ず、将来 16 KB 必須デバイスでも動作する。

#### Scenario: ビルド済み APK の全 arm64 ライブラリが 16 KB アラインメント

- **WHEN** ビルド済み APK の `lib/arm64-v8a/*.so` を `llvm-readelf -l`（NDK 同梱）で監査する
- **THEN** `libVkLayer_*.so` を除く各 `.so` の LOAD セグメント最大 `p_align` が `0x4000`（16 KB）以上である

#### Scenario: 16 KB エミュレータで互換性警告が出ない

- **WHEN** 16 KB ページのエミュレータ（`sdk_gphone16k` 系、API 35+）にインストールして起動する
- **THEN** 「Android App Compatibility」互換性警告ダイアログが表示されず、ホーム画面まで正常に描画される

### Requirement: onnxruntime ネイティブライブラリを 16 KB 対応ビルドへ更新する

16 KB 非対応の唯一の同梱ライブラリは `libonnxruntime.so`（`onnxruntime: ^1.4.1` 同梱、LOAD `p_align=0x1000`）である。これを 16 KB アラインメント済みの `libonnxruntime.so` を提供する `onnxruntime` pub パッケージのバージョンへ更新しなければならない（MUST）。更新後も ml-runtime（ADR-0007）が利用する onnxruntime Dart API はソース互換を保ち、EP 選択・モデル実行の挙動は変えてはならない。

#### Scenario: 更新後の libonnxruntime.so が 16 KB アラインメント

- **WHEN** `onnxruntime` 依存を 16 KB 対応版へ更新して APK をビルドし、`libonnxruntime.so` を `llvm-readelf -l` で検査する
- **THEN** LOAD セグメント最大 `p_align` が `0x4000` 以上である

#### Scenario: onnxruntime 更新が ml-runtime の挙動を変えない

- **WHEN** 依存更新後に既存の ml-runtime / upscaler のユニットテストを実行する
- **THEN** すべて成功し、EP 選択・effective backend・upscale 結果に回帰がない

#### Scenario: 上流が 16 KB 対応版を提供していない場合の判断を記録する

- **WHEN** 16 KB 対応の `onnxruntime` pub パッケージ版が存在しない、または API 非互換で採用できない
- **THEN** 代替方針（対応待ち / 依存隔離 / 別供給）の決定と残存リスクを design および readiness ドキュメントに明記し、16 KB 非対応のまま暗黙に配布しない

### Requirement: 16 KB 互換性リスクは Experimental の AI upscale に限定されることを明確化する

`libonnxruntime.so` は Experimental・default-OFF・opt-in の AI upscale 機能（ADR-0007）専用であり、他のネイティブ依存（media_kit / pdfium / sqlite / flutter）はすでに 16 KB 対応済みである。本機能の 16 KB 互換性リスクは実験的機能に閉じることを仕様として記録しなければならない（MUST）。

#### Scenario: 監査が onnxruntime 以外を 16 KB 対応と確認する

- **WHEN** APK の `lib/arm64-v8a/*.so` を監査する
- **THEN** `libonnxruntime.so` 以外（`libflutter.so`/`libmpv.so`/`libmediakitandroidhelper.so`/`libpdfium.so`/`libsqlite3.so`/`libdartjni.so`）はすべて `p_align >= 0x4000` であり、remediation 対象が onnxruntime のみであることが確認できる

## 1. 方針確定（apply 前ゲート）

- [ ] 1.1 grill-changes-before-apply で D1/Q1 を確定: remediation 方針を A（検査基盤＋上流待機）か B（AAR 差し替えで即 16 KB 化）かユーザーと決定
- [ ] 1.2 Q2（CI を warning 例外で開始するか厳格 fail か）と Q3（監査スクリプトは純正 Python ELF パーサか NDK `llvm-readelf` か）を確定
- [ ] 1.3 方針 B を選ぶ場合のみ Q4（Microsoft `onnxruntime-android` の 16 KB 対応最小バージョンと pub binding 1.4.1 との ABI 整合）を調査・確定

## 2. 監査手順とツール

- [ ] 2.1 `tool/check_so_alignment.py`（確定方式）を追加: APK を unzip し `lib/arm64-v8a/*.so` の全 LOAD セグメント `p_align` を読み、`libVkLayer_*.so` を除き `0x4000` 未満があれば非ゼロ終了
- [ ] 2.2 既知例外（`libonnxruntime.so`）を warning 許容するモードを実装し、撤去条件をコメント明記（方針 A 前提。方針 B なら例外なし）
- [ ] 2.3 ローカルで現行 `app-debug.apk` に対し実行し、期待出力（onnxruntime のみ warning、他は pass）を確認

## 3. CI 検査の追加

- [ ] 3.1 `.github/workflows/ci.yaml` の `build-android-debug` ジョブに、APK ビルド後の `tool/check_so_alignment.py` 実行ステップを追加
- [ ] 3.2 16 KB 非対応 `.so`（例外を除く）混入時にジョブが fail することを、意図的な非対応ダミーまたはドライランで確認

## 4. remediation 実装（方針依存）

- [ ] 4.1 [方針 B のみ] Microsoft `onnxruntime-android`（確定バージョン）の 16 KB 対応 AAR を Gradle で差し替え（resolutionStrategy / plugin patch）。`app/pubspec.yaml` / Android Gradle を更新
- [ ] 4.2 [方針 B のみ] 差し替え後 APK の `libonnxruntime.so` が `p_align >= 0x4000` であることを `tool/check_so_alignment.py` で確認し、CI 検査から例外を撤去
- [ ] 4.3 [方針 A のみ] `onnxruntime` pub に 16 KB 対応版が無いことを記録し、上流 watch とリスクを readiness ドキュメントへ反映

## 5. 検証

- [ ] 5.1 `flutter build apk --debug` 成功を確認
- [ ] 5.2 既存 ml-runtime / upscaler ユニットテスト（`flutter test`）が全緑で、onnxruntime 周りに回帰がないこと
- [ ] 5.3 [manual] 16 KB エミュレータ（`sdk_gphone16k`、API 35+）で起動し「Android App Compatibility」警告が出ずホーム描画されることを確認。方針 B の場合は AI upscale を opt-in 有効化→モデル DL→推論まで実走して回帰確認
- [ ] 5.4 `openspec validate add-android-16kb-page-support --strict` が通る

## 6. ドキュメント

- [ ] 6.1 `docs/`（readiness / ADR-0007 補足など該当箇所）に 16 KB 互換性の現状（onnxruntime のみ非対応・採用方針・残存リスク）を追記
- [ ] 6.2 `v0-2-foundation-readiness` の roadmap readiness checklist に 16 KB 互換性項目を追記（必要時）

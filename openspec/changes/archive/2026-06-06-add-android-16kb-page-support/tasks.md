## 1. 方針確定（apply 前ゲート）

- [x] 1.1 grill-changes-before-apply で D1/Q1 を確定: **方針 A（検査基盤＋上流待機）** を採用（`openspec/grill/Grill-add-android-16kb-page-support-20260607.md`、GATE CLEAN）
- [x] 1.2 Q2（CI は `libonnxruntime.so` を warning 例外で開始）と Q3（監査スクリプトは純正 Python ELF パーサ）を確定
- [N/A] 1.3 Q4（Microsoft `onnxruntime-android` の 16 KB 対応最小バージョン調査）— 方針 B 専用のため対象外（B 昇格時に再オープン）

## 2. 監査手順とツール

- [x] 2.1 `app/tool/check_so_alignment.py` を追加: APK を unzip し `lib/arm64-v8a/*.so` の全 LOAD `p_align` を読み、`libVkLayer_*.so` を除き `0x4000` 未満で非ゼロ終了（純正 Python・NDK 非依存）
- [x] 2.2 既知例外（`libonnxruntime.so`）を warning 許容するモードを実装（撤去条件をコメント明記）。`--strict` で厳格 fail に切替可能
- [x] 2.3 現行 `app-debug.apk` で実行確認: non-strict は onnxruntime のみ warn で exit 0、`--strict` は onnxruntime FAIL で exit 1

## 3. CI 検査の追加

- [x] 3.1 `.github/workflows/ci.yaml` の `build-android-debug` ジョブに、APK ビルド後の `tool/check_so_alignment.py` 実行ステップを追加
- [x] 3.2 fail 経路を確認: `--strict` 実行で非対応ライブラリ検出時に exit 1（例外を除く非対応 `.so` 混入時の fail と同一コードパス）

## 4. remediation 実装（方針依存）

- [N/A] 4.1 [方針 B のみ] Microsoft `onnxruntime-android` 16 KB 対応 AAR の Gradle 差し替え — 方針 A 採用のため未実施
- [N/A] 4.2 [方針 B のみ] 差し替え後の `libonnxruntime.so` 16 KB 化確認・CI 例外撤去 — 同上
- [x] 4.3 [方針 A] `onnxruntime` pub に 16 KB 対応版が無い（最新 1.4.1=現用）ことを記録し、上流 watch と残存リスクを `docs/roadmap.md` に反映

## 5. 検証

- [x] 5.1 `flutter build apk --debug` 成功（監査対象 APK を生成）
- [x] 5.2 `flutter test test/core/ml/` 全緑（71 件）。方針 A は Dart 非変更のため onnxruntime 周りに回帰なし
- [x] 5.3 [manual] 16 KB エミュレータ（`sdk_gphone16k`）で起動・ホーム描画を確認済み（本セッション）。方針 A では `libonnxruntime.so` 由来の互換性警告は**既知の残存事項として継続表示**（起動・動作は継続）。警告ゼロは onnxruntime 16 KB 化後（方針 B 昇格時）に達成予定
- [x] 5.4 `openspec validate add-android-16kb-page-support --strict` が通る

## 6. ドキュメント

- [x] 6.1 `docs/roadmap.md` の v1.0 AI upscale 節に 16 KB 互換性の現状（onnxruntime のみ非対応・方針 A・残存リスク・撤去/昇格条件）を追記
- [x] 6.2 `docs/roadmap.md` の v0.2 readiness checklist に「Android 16 KB ページ互換」監査項目を追加

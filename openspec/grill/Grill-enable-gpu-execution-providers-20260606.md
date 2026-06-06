# Grill残課題 — enable-gpu-execution-providers (20260606)

Phase 1 自己グリルで確認・inline 解決した点:
- `onnxruntime` 1.4.1 API（`appendCoreMLProvider`/`appendNnapiProvider`/`OrtSessionOptions()`+`release()`）を実コードで確認 → probe try-append パターン・upscaler EP append が成立。
- `MlRuntime.preferredBackend()` はメソッド（`ml_runtime.dart:48`）→ D4 の `preferredOverride` resolver 追加が feasible。
- `imageUpscalerProvider` の `caps.effective != ortCpu → Cpu` early-return（`providers.dart:70`）を GPU EP 包含へ広げる必要を確認（floor 分岐は DB 非依存のまま維持）。`MlBackend` enum は coreml/nnapi/directml/ortCpu/bicubic 完備。
- cross-cutting: active change は step4 単一。依存先（step1–3）は archive 済み・main spec 同期済みでヘッダ一致（validate --strict 通過）。stacked branch に step3 コード在り。

以下はユーザー確認が必要な残課題（design Open Questions）。

## enable-gpu-execution-providers — Grill残課題 (20260606)

### Q1. backend 上書きの粒度
- **対象**: spec ai-upscaler-settings「上級 backend 上書き UI」/ design D4・D6 / tasks 4.1, 5.1
- **なぜ重要**: enum 値と UI 選択肢、設定キーの取りうる値が決まる。個別 EP を出すと iOS で NNAPI など「そのプラットフォームに無い EP」を出さない分岐が要る。
- **検討した選択肢**: A) `auto`/`forceCpu`/`force<platform-gpu>`（プラットフォームの GPU EP を 1 つだけ自動提示。iOS/macOS=CoreML, Android=NNAPI, Win/Linux=GPU 項目なし）/ B) `auto`/`forceCpu`/`forceCoreml`/`forceNnapi`（全 EP を列挙、非該当はグレーアウト/非表示）
- **推奨案**: **A**。ユーザーが選べるのは実質「自動 / CPU 強制 / GPU 強制」で十分。プラットフォーム別に GPU EP は 1 つなので個別列挙は冗長。設定キーは `auto`/`forceCpu`/`forceGpu` の 3 値に簡約し、`forceGpu` 時の具体 EP は `preferredBackend()` がプラットフォームから決める。
- **不足インプット**: 上級ユーザーに EP 名（CoreML/NNAPI）まで見せたいか、抽象的な「GPU 強制」で十分か（UX 判断）。
- **Status**: Resolved — A) auto/forceCpu/forceGpu の3択。forceGpu の具体 EP はプラットフォーム自動決定（spec ai-upscaler-settings / design D4・D6 / proposal / tasks 4.1・5.1 に反映）

### Q2. GPU EP 実推論テストを CI で実走させるか
- **対象**: spec gpu-execution-providers「probe は実 GPU 無しの CI で安全に評価できる」/ onnx-upscaler-runtime「Unavailable GPU EP degrades」/ tasks 2.4
- **なぜ重要**: macOS CI runner では CoreML EP が available と判定され、EP 実推論テストが実走する可能性がある。数値差・安定性で flaky リスク。always-skip なら GPU 経路の実推論は CI 非検証（probe＋縮退のみ検証）。
- **検討した選択肢**: A) available なら実走・不在なら skip（既存 `onnx_image_upscaler_test` の skip パターン）/ B) GPU 実推論テストは常に skip（CI では probe＋CPU 縮退のみ検証、実 GPU 推論は実機手動検証）
- **推奨案**: **A**。nearest-neighbor フィクスチャは整数倍 Resize で EP 間差が最小、CoreML CPU 実行でも決定的。万一 flaky なら B に切替。
- **不足インプット**: CI の安定性を最優先（B）か、可能な範囲で GPU 経路も自動検証（A）か（CI 運用方針）。
- **Status**: Resolved — A) available なら実走・不在なら skip（既存 onnx fixture テストの skip パターン、spec/tasks 2.4 のまま）

### Q3. Windows DirectML ギャップの記録先
- **対象**: proposal Non-goals / design D3 / tasks 7.6 / ADR-0007
- **なぜ重要**: ADR-0007 のマトリクスは Windows=DirectML EP と記載。実際はパッケージ非対応で ortCpu 縮退。記録先（ADR amend か docs のみか）で監査性が変わる。
- **検討した選択肢**: A) docs/HANDOFF + roadmap に「Windows GPU は将来課題（パッケージ非対応）」と記録、ADR-0007 は変更なし（フォールバック設計内）/ B) ADR-0007 に amendment 節を追記（Windows EP の現実を明文化）
- **推奨案**: **A**。DirectML 非対応は ADR-0007 のフォールバック連鎖（preferred 不可→ortCpu）で吸収され、決定（ONNX Runtime + EP 一本化）自体は不変。docs 記録で十分。
- **不足インプット**: ADR を「現実に追従して更新」したいか、docs 記録で足りるか（ドキュメント運用方針）。
- **Status**: Resolved — B) ADR-0007 に amendment 節を追記（proposal Non-goals / design Open Questions / tasks 7.6 に反映）

# Grill残課題 — add-upscale-model-distribution (20260606)

Phase 1 自己グリルで inline 解決した項目:
- `imageUpscalerProvider` の async 性の二重所有 → `ml-runtime` delta は provider 配線に限定、選択セマンティクスは `ai-image-upscaler` 所有へ整理（specs/ml-runtime/spec.md）。
- `app_settings` が EAV(key/value, schema v3) であることをコードで確認 → schema 据え置きの主張が成立。
- 設定キーを dotted-namespace 規約 `^[a-z][a-z_]*(\.[a-z][a-z_]*)+$` に修正（tasks 3.1: `experimental.ai_upscale_*`）。

以下はユーザー確認が必要な残課題。

## add-upscale-model-distribution — Grill残課題 (20260606)

### Q1. 初期モデルの選定とホスティング（実モデルを今選ぶ / フィクスチャで配線だけ完成）
- **対象**: proposal「モデルカタログ」/ design Decision D1・D3・Open Questions / tasks 1.3, 2.x
- **なぜ重要**: カタログの実 URL/SHA-256 が無いと「ダウンロード」操作が実機能にならない。実モデルを今コミットするか、配線+テストをフィクスチャで完成させ実モデルは follow-up にするかで、本 change の "完成" の定義とタスク 1.3 の中身が割れる。さらに配布元（GeekPlayer 自身の GitHub Releases に再配布 / 上流 repo の Releases を直リンク）はライセンス表記・可用性に影響。
- **検討した選択肢**: A) フィクスチャで配線・検証を完成させ、実モデル選定+URL/SHA は follow-up change（実験 OFF 既定なのでユーザー影響なし）/ B) 本 change で実モデル（例: Real-ESRGAN x2 ONNX, BSD-3）を 1 つ選定し、GeekPlayer 自身の Releases に再配布して URL/SHA を確定
- **推奨案**: **A**。ADR-0007 は「実験的機能・既定 OFF・段階投入」を明示（Decision 0）。配線・検証・UI をフィクスチャで完成させれば step3 の構造的価値（DL/検証/キャッシュ/配線）は満たせ、実モデル選定はライセンス精査込みで独立に進められる。
- **不足インプット**: 実モデルを今のリリースに載せたいか（プロダクト判断）。載せる場合の配布元方針。
- **Status**: Resolved — A) フィクスチャ(2x/4x)で配線・検証・UI を完成、実モデル選定+URL/SHA は follow-up change（proposal Non-goals / design Open Questions / tasks 1.3 に反映）

### Q2. 既定スケール倍率（2x 固定 / 2x・4x 選択可）
- **対象**: spec ai-upscaler-settings「実験的機能セクション」/ ai-image-upscaler「Manga viewer upscale action」(既存は 2× 固定) / tasks 5.2, 6.1
- **なぜ重要**: 既存 manga viewer は 2× 固定（ai-image-upscaler 既存 spec）。本 change で「設定の既定倍率」を導入したが、選択肢を 2x のみにするか 2x/4x も出すかで、設定 UI とモデルカタログ（4x モデルが要る）に波及する。
- **検討した選択肢**: A) 2x のみ（設定値は前方互換で保持するが UI 選択肢は 2x 固定）/ B) 2x・4x を選択可能にし、各倍率のモデルをカタログに用意
- **推奨案**: **A（2x のみ）**。現行挙動に一致し、モデルも 1 つで済む。4x は実モデル選定（Q1）と合わせて follow-up が自然。
- **不足インプット**: 4x をこの段階で出したいか（プロダクト判断）。
- **Status**: Resolved — B) 2x / 4x 選択可・既定 2x（spec ai-upscaler-settings「既定スケール倍率の選択」追加、proposal/design/tasks 5.2・1.3 に反映。倍率ごとにフィクスチャエントリを用意）

### Q3. 上級 backend 上書き UI を本 change に含めるか step4 送りか
- **対象**: spec ai-upscaler-settings「上級 backend 上書き」(MAY) / tasks 5.4 / 次 change `enable-gpu-execution-providers`(step4, 未起案)
- **なぜ重要**: GPU EP は step4 まで利用不可。本 change の実効上限は ortCpu。よって上書きで選べる意味のある backend は実質 ortCpu/bicubic のみで、UI を作っても step4 まで価値が薄い。spec は MAY なので含めても省いてもよいが、tasks 5.4 の有無が決まる。
- **検討した選択肢**: A) 本 change では省略（spec MAY のまま未実装、floor 劣化保証だけ probe 経路で担保）→ step4 で実装 / B) 表示のみの最小 UI を本 change に置く
- **推奨案**: **A（step4 送り）**。GPU EP が無い段階で上書き UI は実用価値が無く、step4 でまとめて入れる方が一貫。tasks 5.4 は削除。
- **不足インプット**: 上書き UI を早めに見たいか（プロダクト判断）。
- **Status**: Resolved — A) step4 送り。本 change では未実装。spec ai-upscaler-settings の該当要件を「実効 backend は probe に従い floor へ劣化する」(invariant 主体) へ reword、tasks 5.4 削除（proposal Non-goals / design Open Questions に反映）

## Why

v1.0 の画像アップスケーリング経路（`OnnxImageUpscaler` + Real-ESRGAN x4plus_anime_6B、`app/lib/core/ml/onnx_image_upscaler.dart`, `app/lib/core/ml/upscale_model_catalog.dart:103-140`）は、公開リリースからの実 DL → 検証 → 2x/4x 推論の E2E 確認まで完了している（`docs/roadmap.md` の画像アップスケーリング検証項目）。しかし実機の manga viewer（`app/lib/features/manga/presentation/manga_viewer_screen.dart`）で **目視による画質確認**は未実施であり、タイルサイズは 256px が「暫定既定（実測で確定）」のまま据え置かれている（`openspec/changes/archive/2026-06-08-add-upscale-model-selection/design.md` D3: 「128 は継ぎ目/オーバーヘッド過多、512 は 4x 出力〔2048px〕でモバイルメモリ負荷大。256px を暫定既定とし…実測で確定する」）。実測なしに Experimental フラグを卒業させる判断はできず、継ぎ目・アーティファクト・メモリ圧迫・レイテンシが許容範囲かも未検証のため、今のタイミングで検証する。

GitHub Issue: #46
Milestone: #3 (v1.0: image upscaling validation)

## What Changes

- 実機（少なくとも 1 台、可能なら複数 OS/デバイス）でアプリを起動し、設定の Experimental ゲートを有効化して AI 画像アップスケーラを ON にする（`app/lib/core/ml/providers.dart`, `ai-upscaler-settings` capability）。
- manga viewer で任意のページに対して 2x・4x 双方の「高画質化」アクション（`app/lib/features/manga/presentation/manga_viewer_screen.dart` の `_upscaleCurrentPage` と `Icons.auto_fix_high` ボタン）を実行し、Real-ESRGAN x4plus_anime_6B（`OnnxImageUpscaler` 経由、固定 256px タイル）の出力を目視で確認する。
- 現行の固定 256px タイル（`app/lib/core/ml/upscale_model_catalog.dart:122,134`、タイル分割・再合成は `app/lib/core/ml/upscale_tiling.dart`）が実機で許容できる品質・性能・メモリかを実測する: タイル継ぎ目の有無、推論所要時間、メモリ使用量の体感、バッテリー/発熱の粗い所感。
- 使用したデバイス・OS・ランタイム（effective backend: CPU EP / CoreML EP / NNAPI EP のいずれか、`ADR-0007`）、代表ページの before/after 所見を本 change 内に記録として残す（新規ドキュメント成果物、コード変更なし）。
- 結果に応じて次のいずれかを判断する: (a) 現行既定（256px タイル、Experimental 既定 OFF）を維持して良いと記録する、または (b) アーティファクト・メモリ圧迫・レイテンシが許容できない場合、defaults 変更や再 export を扱う **別の OpenSpec change / GitHub Issue** を起票する（本 change ではそれらの変更自体は実施しない）。

このタスクはコード変更を伴わない**検証作業**であり、Issue #46 の Notes（「Keep this as validation unless the result clearly requires a separate OpenSpec change」）に従う。

## Capabilities

### New Capabilities

(なし — 本 change は既存機能の実機検証であり、新規ケイパビリティを導入しない)

### Modified Capabilities

- `upscale-model-distribution`: 恒久エントリの `tileSize`（現行 256px）が「実機検証記録を伴わない限り暫定既定として扱い、Experimental 既定 ON 化の判断根拠に用いてはならない」という要件を追加する（ADDED Requirement）。この要件は検証記録の有無というプロセス上の制約であり、`tileSize` の値そのものや `UpscaleModelCatalog` の実装は本 change では変更しない。検証の結果、他の capability（`ai-image-upscaler` / `upscale-image-tiling` / `ai-upscaler-settings`）の要件変更が必要と判明した場合は、その変更内容を扱う別の OpenSpec change を新規に起票する。

## Non-goals

- タイルサイズ（256px）や Experimental 既定 OFF などの既定値・実装を本 change 内で変更すること（実測の結果、変更が必要と判明した場合は別 change に切り出す）。
- 新しいモデルの選定・再 export・`app/tool/export_real_realesrgan_x4.py` の変更。
- GPU EP（CoreML/NNAPI）自体の新規実装や、Windows DirectML 対応（`ADR-0007` amendment で既知の制約、別トラック）。
- 動画系（Anime4K リアルタイム／Real-ESRGAN 動画変換／RIFE 補間）の検証。これらは `docs/roadmap.md` v1.0 の別項目。
- 自動化されたベンチマークツール・CI 計測基盤の新規構築（本 change は手動実測の記録に留める。自動計測が必要になった場合は別途検討）。

## Impact

- **コード変更**: なし（検証作業）。実測により追加の GitHub Issue / OpenSpec change が必要と判明した場合、その change 側で `app/lib/core/ml/upscale_model_catalog.dart`, `app/lib/core/ml/onnx_image_upscaler.dart`, `app/lib/core/ml/upscale_tiling.dart` 等に触れる可能性がある。
- **成果物**: 本 change の `design.md` に実測手順・環境・所見を記録する。必要なら `docs/roadmap.md` の画像アップスケーリング検証項目を検証済みに更新する archive 時のフォローアップとする。
- **影響を受ける既存 capability（参照のみ、変更なし）**: `ai-image-upscaler`, `upscale-image-tiling`, `upscale-model-distribution`, `ai-upscaler-settings`, `ml-runtime`, `gpu-execution-providers`, `local-manga-zip-viewer`。

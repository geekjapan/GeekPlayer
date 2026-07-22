## Context

`ai-image-upscaler` / `onnx-upscaler-runtime` / `upscale-model-distribution` / `gpu-execution-providers` / `upscale-image-tiling` の各 capability により、Real-ESRGAN x4plus_anime_6B（BSD-3-Clause、opset 17 / IR 9、固定 256px タイル）を用いた 2x/4x on-device 推論の配線は完了している（`docs/roadmap.md` の画像アップスケーリング検証項目）。`ADR-0007` は AI 画像アップスケーリングを **Experimental・既定 OFF・opt-in** として位置付け、卒業判断（既定 ON 化・品質保証）は「品質・性能の実測後に別途行う」としている。

タイルサイズ 256px は `openspec/changes/archive/2026-06-08-add-upscale-model-selection/design.md` の D3 で「暫定既定、実測で確定」と明記されており、export 時にタイルサイズが固定化されるため変更には再 export を伴う（`app/tool/export_real_realesrgan_x4.py`）。現時点で実機での目視確認・タイルサイズ実測は未実施（`docs/HANDOFF.md` 「実モデルの視覚確認」候補項目、GitHub Issue #46）。

manga viewer 側の呼び出し経路は `app/lib/features/manga/presentation/manga_viewer_screen.dart:140-189`（`_upscaleCurrentPage`）で、`AppSettings.aiUpscaleScale`（2 または 4）を読み、`imageUpscalerProvider` を非同期解決し、`ImageUpscaler.upscale` の結果を `_upscaledBytes` として表示する。effective backend は `MlRuntime.probe()` に依存し、実験フラグ ON かつ検証済みモデル present のときのみ `OnnxImageUpscaler`、それ以外は `CpuImageUpscaler`（bicubic floor）に解決される（`openspec/specs/ai-image-upscaler/spec.md` Requirement「CpuImageUpscaler is the default provider」）。

## Goals / Non-Goals

**Goals:**

- 実機（1 台以上）で Experimental フラグを ON にし、manga viewer から 2x/4x の Real-ESRGAN 出力を目視確認する。
- 固定 256px タイルの継ぎ目・アーティファクトの有無を実際の漫画ページで確認する。
- 推論所要時間・メモリ使用感・発熱/バッテリー所感を粗く記録する。
- デバイス・OS・effective backend（CPU EP / CoreML EP / NNAPI EP）ごとの所見を残す。
- 「256px 既定を維持してよいか」「別 change（defaults 変更・再 export）を起票すべきか」を判断し記録する。

**Non-Goals:**

- タイルサイズや既定値の実装変更（結果次第で別 change に切り出す）。
- 新モデルの選定・再 export。
- 自動ベンチマーク基盤やパフォーマンス CI ゲートの新規構築。
- GPU EP 自体の新規実装（既存の CoreML/NNAPI EP 配線を使うのみ）。

## Decisions

### D1: 本 change はコード変更を伴わない「検証記録」として扱い、スペックデルタは "検証プロセス上の制約" 1件に限定する

- **選択**: proposal.md の Non-goals どおり、本 change では `app/lib/core/ml/**` のコードを変更しない。実測結果・所見・判断（維持 or 別 change 起票）を `design.md`（本ファイル）の追記、または archive 時に `docs/roadmap.md` の画像アップスケーリング検証項目を更新する形で記録する。OpenSpec スキーマは「change には最低 1 件の delta が必要」という制約があるため（`openspec validate --all --strict` が deltas なしを ERROR にする）、`upscale-model-distribution` に **プロセス上の制約**（tileSize は実機検証記録を伴わない限り暫定既定として扱う、Experimental 既定 ON 化の根拠に使わない）を ADDED Requirement として 1 件追加する。この要件は `tileSize` の値や実装を変えるものではなく、「検証記録の有無」という運用上の縛りを明文化するものである。
- **代替案 1**: 本 change 内でタイルサイズ変更まで一気に実施する。→ 却下。Issue #46 の Notes が「Keep this as validation unless the result clearly requires a separate OpenSpec change」と明記しており、実測前に defaults 変更を決め打ちするのは spec-driven ワークフローの proposal→design→tasks の順序と矛盾する。
- **代替案 2**: 本 change でスペックデルタ（`ai-image-upscaler` 等の既存 Requirements の MODIFIED）を先に書いておく。→ 却下。実測結果が出るまで、既存要件（256px 既定、Experimental 既定 OFF）が変わるかどうか未定であり、確定していない挙動をスペックに先出しすると archive 時に整合しない。
- **代替案 3**: spec デルタを一切書かず `openspec validate --all --strict` のエラーを無視する。→ 却下。プロジェクト規約でこのコマンドをローカル検証の必須項目としており、エラーを残したままコミットしない。

### D2: 検証環境は「利用可能な実機・エミュレータの範囲」で行い、全 OS 網羅は必須としない

- **選択**: ローカル環境で起動可能なプラットフォーム（例: macOS デスクトップ、Android 実機/エミュレータ）を優先して検証する。iOS/Windows/Linux 実機が用意できない場合はその旨を記録し、「検証できなかった環境」として明示する（全 OS 実機がなくても、代表的な CPU EP パスと 1 つ以上の GPU EP パスで所見が取れれば判断材料として十分）。
- **代替案**: 全 4 OS（macOS/Windows/Android/iOS + v0.2 の Linux/iPadOS）で実機検証を必須とする。→ 却下。実機調達コストが高く、Issue #46 は「実機 manga viewer での視覚確認」を主眼としており、全環境網羅は求めていない。不足環境は tasks.md 内で明示的に「実施できず」を記録する。

### D3: タイルサイズ実測は「主観的な目視 + 簡易計測」の粒度で行い、精密プロファイリングは求めない

- **選択**: `flutter run --profile` や DevTools での簡易メモリ/時間観測、または手動ストップウォッチ計測で十分とする。継ぎ目の有無はスクリーンショットの目視比較で判定する。
- **代替案**: Flutter DevTools Timeline / Android Studio Profiler でのマイクロベンチマークを必須にする。→ 却下。Non-Goals の「自動ベンチマーク基盤の新規構築」を避けつつ、Issue のスコープ（「Measure whether the current 256px tile default is acceptable」）は定量的な学術的精度ではなく実用上の可否判断で足りる。より精密な計測が必要と判明した場合は、その計測基盤自体を別 change として提案する。

## Risks / Trade-offs

- [リスク] 実機・エミュレータ環境が限られ、GPU EP（CoreML/NNAPI）経路を検証できない可能性 → **軽減**: CPU EP のみでも「Experimental 既定 OFF・opt-in」という現行運用方針の下では許容範囲内の所見として記録し、検証できなかった経路を明示して follow-up Issue の要否を判断する。
- [リスク] 目視確認は主観的でばらつきがあり、定量的な品質指標（PSNR/SSIM 等）がない → **軽減**: 本 change では定性評価に留め、定量評価が必要と判明した場合は別途 Issue 化する（Non-Goals に明記済み）。
- [リスク] タイルサイズ変更が必要と判明した場合、再 export（`tool/export_real_realesrgan_x4.py`）とモデル再配布（GitHub Release 更新・SHA-256 更新）を伴い、後続 change のコストが高い → **軽減**: 本 change では変更の要否と根拠のみを記録し、実施コストの見積もりは後続 change の proposal 側で扱う。
- [トレードオフ] 本 change 単体では「ユーザーに見える変化」がゼロ（ドキュメント記録のみ）だが、v1.0 の Experimental 卒業判断に必要な前提情報を揃えるという価値がある。

## Validation

コード変更を伴わないため、通常の実装差分としての `flutter test` 等は最小限だが、リポジトリ規約に従い以下を実行し結果を記録する:

- `cd app && dart format --output=none --set-exit-if-changed .`
- `cd app && flutter analyze --fatal-infos`
- `cd app && flutter test`
- `openspec validate --all --strict`
- `git diff --check`

ローカルに Flutter/Dart ツールチェーン（fvm 経由）が利用可能な場合は上記をローカルで実行する。利用できない環境では GitHub Actions の CI ジョブ（format/analyze/test）の結果を PR に記録する。本 change はコード変更を含まないため、これらのコマンドは「回帰がないこと」の確認（既存コードに影響していないこと）を目的とする。

## Open Questions

- 実機検証に使えるデバイス／OS の具体的な組み合わせ（macOS のみか、Android 実機も含むか）は実施時に確定する。
- 検証の結果、256px 既定を変更すべきと判断した場合、follow-up の GitHub Issue 番号は本 change 内では未確定（`GitHub Issue: TBD` として起票し、archive 時にリンクする）。

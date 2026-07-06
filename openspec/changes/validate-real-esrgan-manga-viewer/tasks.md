## 1. 準備

- [ ] 1.1 検証に使える実機・エミュレータ・OS の一覧を洗い出す（macOS / Windows / Android / iOS / Linux のうち利用可能なもの）。利用不可の環境は「検証できず」として記録する。
- [ ] 1.2 検証用の漫画 ZIP サンプル（線画中心・グラデーション中心・テキスト吹き出し中心など、継ぎ目やアーティファクトが見えやすいページを含む）を用意する。
- [ ] 1.3 `cd app && flutter run`（または対象プラットフォームのビルド）でアプリを起動し、設定画面の Experimental ゲートを有効化して AI 画像アップスケーラを ON にする（`ai-upscaler-settings` capability）。

## 2. 実機での目視確認（2x/4x）

- [ ] 2.1 manga viewer で対象ページを開き、2x 設定で「高画質化」アクション（`Icons.auto_fix_high`）を実行し、初回モデル DL（`ModelRepository`）→ 検証 → 推論が完了することを確認する。
- [ ] 2.2 同ページで 4x 設定に切り替えて同様に実行し、2x/4x の出力を比較する。
- [ ] 2.3 各ページのタイル継ぎ目（256px 境界）が視認できるかをスクリーンショットで記録する（`app/lib/core/ml/upscale_tiling.dart` の内側パディング/再合成が機能しているか）。
- [ ] 2.4 線画・グラデーション・テキスト吹き出しなど異なる絵柄のページで代表的な before/after スクリーンショットを最低 3 組取得する。

## 3. タイルサイズ・性能実測

- [ ] 3.1 2x/4x それぞれの推論所要時間を計測する（手動ストップウォッチ or `flutter run --profile` の簡易計測で可）。
- [ ] 3.2 推論中・推論後のメモリ使用量の体感（OS のタスクマネージャ/アクティビティモニタ等での粗い確認）を記録する。
- [ ] 3.3 発熱・バッテリー消費について、明らかな異常（スロットリング、極端な発熱）がないかを確認する。
- [ ] 3.4 256px タイルが品質・性能・メモリの観点で許容範囲かを判断し、根拠を記録する。

## 4. 環境・所見の記録

- [ ] 4.1 検証したデバイス機種・OS バージョン・effective backend（CPU EP / CoreML EP / NNAPI EP のいずれか、設定画面の上級 backend 表示で確認）を記録する。
- [ ] 4.2 各環境ごとの before/after 所見（画質・継ぎ目・速度・メモリ）を本 change 内（`design.md` の追記または別ファイル）にまとめる。
- [ ] 4.3 検証できなかった環境・観点があれば明示的に記録する。

## 5. 判断と後続アクション

- [ ] 5.1 実測結果に基づき、現行既定（256px タイル・Experimental 既定 OFF）を維持してよいかを判断する。
- [ ] 5.2 維持できない場合、defaults 変更・再 export を扱う follow-up の GitHub Issue（milestone #3 配下）を起票し、本 change の記録からリンクする。
- [ ] 5.3 `docs/roadmap.md:111`（「残: 実機 manga viewer での視覚確認・タイルサイズ実測」の記述）を検証結果に応じて更新する下書きを用意する（実際の反映は本 change の archive 時、または別 docs change として実施）。

## 6. 検証コマンド

- [ ] 6.1 `cd app && dart format --output=none --set-exit-if-changed .` を実行する。
- [ ] 6.2 `cd app && flutter analyze --fatal-infos` を実行する。
- [ ] 6.3 `cd app && flutter test` を実行する。
- [ ] 6.4 `openspec validate --all --strict` を実行する。
- [ ] 6.5 `git diff --check` を実行する。
- [ ] 6.6 ローカルで Flutter/Dart が利用できない場合は、上記の代わりに GitHub Actions の format/analyze/test ジョブの結果を PR に記録する。

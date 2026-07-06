## ADDED Requirements

### Requirement: 恒久エントリのタイルサイズは実機検証記録を伴う

配布カタログの恒久エントリが指定する `tileSize`（現行 256px、`UpscaleModelCatalog.x2`/`x4`）は、少なくとも 1 台の実機（またはエミュレータ）における Real-ESRGAN 2x/4x 出力の目視確認、および所要時間・メモリ使用感の実測記録を伴わなければならない (MUST)。当該検証記録が存在しない間、このタイルサイズは**暫定既定**として扱い、AI アップスケーリングの Experimental フラグ既定 ON 化（`ai-upscaler-settings`）の判断根拠に用いてはならない (MUST NOT)。検証の結果、現行タイルサイズが品質・性能・メモリの観点で許容できないと判明した場合、システムは defaults 変更や再 export を扱う別の変更を通じてのみタイルサイズを更新しなければならない (MUST) — 本要件を満たすための検証行為自体が `tileSize` の値を直接変更することはない。

#### Scenario: 検証記録がある場合のみ既定卒業の判断材料にできる

- **GIVEN** 恒久エントリの `tileSize` について、実機での目視確認・所要時間・メモリ使用感を記した検証記録が存在する
- **WHEN** AI アップスケーリングの Experimental フラグを既定 ON へ卒業させるかを検討する
- **THEN** その検証記録を判断根拠の一つとして参照できる

#### Scenario: 検証記録がない場合は暫定既定のまま扱う

- **GIVEN** 恒久エントリの `tileSize` について実機検証記録が存在しない
- **WHEN** Experimental フラグの既定を判断する
- **THEN** 既定 OFF を維持し、当該タイルサイズが暫定既定である旨をドキュメント（`docs/roadmap.md` 等）に明記する

#### Scenario: 検証の結果タイルサイズが不適格と判明した場合は別変更で対応する

- **GIVEN** 実機検証の結果、現行 `tileSize` が継ぎ目・メモリ圧迫・レイテンシの観点で許容できないと判明する
- **WHEN** defaults を更新する
- **THEN** その更新は再 export や `UpscaleModelCatalog` の変更を伴う別の OpenSpec change を通じて行われ、検証記録を残すだけの変更では `tileSize` の値そのものは変わらない

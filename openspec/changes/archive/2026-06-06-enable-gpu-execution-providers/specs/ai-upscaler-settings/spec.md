## ADDED Requirements

### Requirement: 上級 backend 上書き UI

実験的機能セクションは、上級者向けに実行 backend を上書きする手段を提供しなければならない (SHALL): **Auto（既定）/ 強制 CPU / 強制 GPU** の 3 択。`強制 GPU` の具体 EP はプラットフォームから自動決定する（iOS/macOS=CoreML、Android=NNAPI、その他は GPU EP なし）。上書き値は永続化される。上書きしても、実効 backend は `MlRuntime.probe()` のフォールバック連鎖に従い、選んだ backend が利用不可なら bicubic CPU floor へ縮退しなければならない (MUST)。すべての文言はローカライズ済みでなければならない (MUST)。

#### Scenario: 既定は Auto

- **WHEN** 永続化された設定がない初期状態で backend 上書きを参照する
- **THEN** 既定値は Auto である

#### Scenario: 上書きが永続化される

- **GIVEN** ユーザーが backend 上書きを「強制 CPU」に変更する
- **WHEN** アプリを再起動して設定を読み込む
- **THEN** 上書きは「強制 CPU」のまま復元される

#### Scenario: 強制 GPU が利用不可なら floor へ縮退する

- **GIVEN** 上書きが「強制 GPU」だが、当該プラットフォームの GPU EP が利用不可
- **WHEN** 実効 backend が `MlRuntime.probe()` で解決される
- **THEN** probe により ORT CPU もしくは bicubic CPU floor に縮退し、クラッシュしない

## MODIFIED Requirements

### Requirement: 実効 backend は probe に従い floor へ劣化する

実効 backend は、ADR-0007 のフォールバック連鎖と `MlRuntime.probe()` の結果に従わなければならない (MUST)。設定で要求された backend（上級 backend 上書きを含む）が利用不可な場合でも、bicubic CPU floor に劣化し、クラッシュしてはならない (MUST NOT)。

#### Scenario: 利用不可な preferred backend は floor に劣化する

- **GIVEN** preferred backend が GPU EP だが、その EP が当該プラットフォームで利用不可
- **WHEN** 実効 backend が `MlRuntime.probe()` で解決される
- **THEN** probe により ORT CPU もしくは bicubic CPU floor に劣化し、クラッシュしない

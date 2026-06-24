## ADDED Requirements

### Requirement: タッチターゲットと section spacing は共有トークンを参照する

後続の UI 実装で最小タッチターゲットまたは設定 section の余白を明示する場合、`app/lib/core/theme/tokens.dart` の `AppSizes.minTouchTarget` と `AppSpacing` を参照しなければならない (MUST)。48dp の a11y タッチターゲットを手書き数値として重複定義してはならない (MUST NOT)。

#### Scenario: notice link button が minTouchTarget token を使う

- **WHEN** Apache NOTICE または LGPL notice のリンクボタンを構築する
- **THEN** ボタンの最小高さは `AppSizes.minTouchTarget` から決まり、48 logical pixels 以上になる

#### Scenario: SettingsSection が spacing token を使う

- **WHEN** 設定 screen の `SettingsSection` を構築する
- **THEN** section 外側余白と見出し周辺の余白は `AppSpacing` token 由来の値で定義される

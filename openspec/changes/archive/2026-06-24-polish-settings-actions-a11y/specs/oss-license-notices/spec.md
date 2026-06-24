## ADDED Requirements

### Requirement: Apache NOTICE のライセンスリンクは 48dp のアイコン付きボタンで表示される

Apache-2.0 NOTICE section から bundled `LICENSE` を開くリンクは、Material 3 の `TextButton.icon` または同等の semantics / focus / hover を持つアイコン付きボタンとして表示されなければならない (MUST)。このボタンのタッチターゲット高は 48 logical pixels 以上でなければならず (MUST)、`AppSizes.minTouchTarget` を参照しなければならない (MUST)。

#### Scenario: Apache NOTICE の全文リンクが 48dp 以上でタップできる

- **WHEN** License list screen を表示する
- **THEN** Apache-2.0 NOTICE section の「ライセンス全文」リンクはアイコン付き Material ボタンとして表示され、その render box の高さは 48 logical pixels 以上である

#### Scenario: Apache NOTICE の全文リンクは既存の遷移先を維持する

- **WHEN** ユーザーが Apache-2.0 NOTICE section の「ライセンス全文」ボタンをタップする
- **THEN** `assets/legal/LICENSE` を表示する license-detail-style screen が開き、既存の bundled LICENSE 表示動作は変わらない

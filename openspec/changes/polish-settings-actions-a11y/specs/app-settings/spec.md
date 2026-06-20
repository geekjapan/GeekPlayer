## ADDED Requirements

### Requirement: 設定の破壊的操作はエラー色で表示される

設定画面で履歴削除、本文キャッシュ削除、同意取り消し後の本文キャッシュ削除、R18 年齢確認リセットのような破壊的または取り消し困難な操作を表示する場合、確認ダイアログの確定ボタンは現在の `ThemeData.colorScheme.error` を使用しなければならない (MUST)。破壊的操作を表す行アイコンがある場合、その行アイコンも `ThemeData.colorScheme.error` を使用しなければならない (MUST)。確定ボタンが塗りつぶしボタンである場合、ラベル/アイコンの前景色は `ThemeData.colorScheme.onError` を使用しなければならない (MUST)。キャンセル、残す、閉じるなどの非破壊的な選択肢は error 色を使ってはならない (MUST NOT)。

#### Scenario: 履歴削除の確認ボタンがエラー色になる

- **WHEN** ユーザーが設定画面のライブラリ section で「履歴をすべてクリア」を開く
- **THEN** 削除行のアイコンと確認ダイアログの「削除する」ボタンは現在 theme の `colorScheme.error` を使い、「キャンセル」ボタンは error 色を使わない

#### Scenario: キャッシュ削除の確認ボタンがエラー色になる

- **WHEN** ユーザーがキャッシュ section でサイト別削除または「すべてクリア」の確認ダイアログを開く
- **THEN** 対象行の削除アイコンと確認ダイアログの「削除する」ボタンは現在 theme の `colorScheme.error` を使う

#### Scenario: 同意取り消し後の本文キャッシュ削除だけがエラー色になる

- **WHEN** ユーザーがオンラインサービス section でサイト同意を OFF にし、本文キャッシュ削除確認ダイアログが表示される
- **THEN** 「削除する」ボタンは現在 theme の `colorScheme.error` を使い、「残す」ボタンは error 色を使わない

#### Scenario: R18 リセットの確認ボタンがエラー色になる

- **WHEN** ユーザーが R18 section で年齢確認リセットの確認ダイアログを開く
- **THEN** リセット行のアイコンと確認ダイアログの「リセットする」ボタンは現在 theme の `colorScheme.error` を使う

### Requirement: 設定 section 見出しは Material 3 の section label として表示される

設定画面の各 section 見出しは、子 `ListTile` の主ラベルより控えめな Material 3 section-label 相当のスタイルで表示されなければならない (MUST)。見出しの外側/内側余白は `AppSpacing` token を参照しなければならず (MUST)、新しいマジックナンバーで section 間隔を定義してはならない (MUST NOT)。

#### Scenario: 描画される全 section 見出しが同じ label スタイルを使う

- **WHEN** 設定画面を表示する
- **THEN** その時点で描画されるすべての `SettingsSection` 見出しは同一の section-label スタイルと token 由来の余白で描画される

#### Scenario: section 見出しは設定 row と視覚階層が異なる

- **WHEN** 設定画面の任意 section を表示する
- **THEN** section 見出しは子 `ListTile` の primary text と同じ強さの `titleMedium` 見出しとしてではなく、group label として読める控えめなテキストスタイルで描画される

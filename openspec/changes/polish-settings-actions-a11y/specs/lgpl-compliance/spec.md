## ADDED Requirements

### Requirement: LGPL notice のリンクは 48dp のアイコン付きボタンで表示される

LGPL notice section に表示される上流ソース、`THIRD_PARTY_NOTICES`、LGPL-2.1 全文へのリンクは、Material 3 の `TextButton.icon` または同等の semantics / focus / hover を持つアイコン付きボタンとして表示されなければならない (MUST)。各ボタンのタッチターゲット高は 48 logical pixels 以上でなければならず (MUST)、`AppSizes.minTouchTarget` を参照しなければならない (MUST)。リンク先 URL と bundled license asset の内容は既存要件から変えてはならない (MUST NOT)。

#### Scenario: LGPL notice の全リンクが 48dp 以上でタップできる

- **WHEN** License list screen を表示する
- **THEN** LGPL notice section の上流ソース、`THIRD_PARTY_NOTICES`、LGPL-2.1 全文リンクはそれぞれアイコン付き Material ボタンとして表示され、各 render box の高さは 48 logical pixels 以上である

#### Scenario: 外部リンクは既存 URL を開く

- **WHEN** ユーザーが LGPL notice section の上流ソースまたは `THIRD_PARTY_NOTICES` ボタンをタップする
- **THEN** OS default browser は既存要件で定義された `https://github.com/mpv-player/mpv` または `https://github.com/geekjapan/GeekPlayer/blob/main/THIRD_PARTY_NOTICES.md` を開く

#### Scenario: LGPL 全文リンクは既存 asset を表示する

- **WHEN** ユーザーが LGPL notice section の LGPL-2.1 全文ボタンをタップする
- **THEN** `assets/legal/LGPL-2.1.txt` を表示する license-detail-style screen が開き、既存の bundled LGPL 表示動作は変わらない

## add-android-apk-install-handoff — Grill残課題 (20260606)

### Q1. Android install intent の発火機構と FileProvider 所有
- **対象**: design.md D2（install-intent mechanism）/ tasks 2.3・3.3・3.4 / proposal「Dependencies」
- **なぜ重要**: ここが未確定だと実装方式（pub パッケージ追加 vs ネイティブ platform channel）と AndroidManifest の provider 宣言（自前 vs パッケージ同梱）が割れる。FileProvider authority が二重宣言になるとマージ済みマニフェストがビルド失敗する。新規依存追加は CLAUDE.md で「ユーザー確認」が要る項目。
- **検討した選択肢**:
  - A) `open_filex`（BSD-3-Clause、メンテ良好）を **Android 限定**で使用。内部で FileProvider content URI を構築し `ACTION_VIEW`（apk mime）で installer を起動。provider はパッケージ同梱（authority `${applicationId}.fileProvider`）を利用 → 自前 `<provider>` は宣言せず、`REQUEST_INSTALL_PACKAGES` と `<queries>` のみ自前追加。desktop は現行 `launchUrl` 維持。
  - B) 自前 platform channel（Kotlin）で `FileProvider.getUriForFile` + install Intent を実装。新規依存ゼロだがネイティブコード + MethodChannel の保守・テストが増える。自前 `<provider>`（authority `${applicationId}.fileprovider`）+ `res/xml/file_paths.xml`（`<cache-path>`）を宣言。
- **推奨案**: **A（`open_filex`、Android 限定、同梱 provider 利用）**。ライセンスは BSD-3（非 GPL/LGPL、roadmap readiness checklist 適合）、メンテ済みで最小コード。desktop/iOS など非 Android ビルドに影響しない。Real-ESRGAN/waifu2x と同じく寛容ライセンス方針に整合。
- **不足インプット**: 新規 pub 依存（`open_filex`）を追加してよいか、それともネイティブ自前実装（依存ゼロ）を選ぶかのユーザー判断。A の場合「同梱 provider に依存」か「明示的に自前 provider を宣言」かの最終確認。
- **Status**: Resolved — A: `open_filex`（BSD-3, Android 限定、同梱 FileProvider 利用、自前 provider/file_paths.xml は宣言しない）。`REQUEST_INSTALL_PACKAGES` と `<queries>` のみ自前追加。(design.md D2/D3, proposal.md Impact, tasks 3.3/3.4)

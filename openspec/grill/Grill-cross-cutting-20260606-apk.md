## cross-cutting — Grill残課題 (20260606)

対象: `add-android-apk-install-handoff`（唯一のアクティブ change）。

- **DAG / 依存**: 単一 change、`Depends on` なし。DAG 不整合なし。
- **所有競合**: 他のアクティブ change なし（`openspec list` = 1 件のみ）。`update_installer.dart` /
  `AndroidManifest.xml` を触る並行 change はない。競合なし。
- **共有契約**: `auto-update` capability の "OS handoff for installation" のみを MODIFIED。
  他 capability・他 change が同 requirement を参照していない。
- **命名/用語**: `UpdateInstaller` / `openForInstall` / `FileProvider` authority
  `${applicationId}.fileprovider` は既存コード・Android 慣習に整合。

### 残課題なし（cross-cutting）
クロスカット観点での未解決事項なし。唯一の確認項目は per-change 残課題 Q1（D2 機構選定）。

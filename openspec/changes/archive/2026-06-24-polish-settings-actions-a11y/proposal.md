## Why

`docs/HANDOFF.md:260` と GitHub Issue #41 が、UI Phase 2 バッチ2として設定画面まわりの低リスクな a11y / 体裁修正を指定している。Phase 2a バッチ1は PR #40 で完了済みのため、次の小さな CI 検証単位として、破壊的操作の視覚セマンティクス、ライセンス/notice リンクのタッチターゲット、設定セクション見出しの M3 整合をまとめて扱う。

## What Changes

- 設定画面の確認ダイアログで、破壊的確定アクションのボタンと、破壊的操作行が持つ削除/リセットアイコンに `Theme.of(context).colorScheme.error` を適用する。対象は履歴削除 `app/lib/features/settings/presentation/sections/library_section.dart:55`、キャッシュ削除 `app/lib/features/settings/presentation/sections/cache_section.dart:154` / `app/lib/features/settings/presentation/sections/cache_section.dart:168`、同意取り消し後の本文キャッシュ削除ダイアログ `app/lib/features/settings/presentation/sections/online_services_section.dart:82`、R18 年齢確認リセット `app/lib/features/settings/presentation/sections/r18_section.dart:44`。
- `LicenseListScreen` と LGPL notice のインラインリンクを、アイコン付きの Material 3 `TextButton.icon` 相当に置き換え、`AppSizes.minTouchTarget` の 48dp タッチターゲットを保証する。対象は Apache NOTICE のライセンス全文リンク `app/lib/features/about/presentation/license_screen.dart:84` と LGPL notice のリンク群 `app/lib/features/about/presentation/lgpl_notice_section.dart:53`。
- `SettingsSection` の見出し余白とテキストスタイルを、既存トークン `AppSpacing` / Material 3 section-label 相当へ寄せる。共有セクション足場は `app/lib/features/settings/presentation/settings_screen.dart:83`、トークンは `app/lib/core/theme/tokens.dart:10`。
- 対象 widget test を追加/更新し、破壊的操作の `ColorScheme.error` 適用、48dp 以上のリンクサイズ、設定セクション見出しの見た目契約を固定する。

## Non-goals

- Phase 2 残項目 ④ の生例外文字列ローカライズ、⑥ の日付整形、⑦ の恒久無効プレースホルダ/`policyVersion` 文言除去は扱わない。
- 新しい設定項目、永続化形式、DB schema、外部 API、ナビゲーション構造は追加しない。
- `openspec/specs/` の accepted spec は手動編集せず、この change の delta specs だけで契約変更を表す。
- `release-all-platform-installers` の Linux 実機 AppImage 確認には触れない。

## Capabilities

### New Capabilities

- なし。

### Modified Capabilities

- `app-settings`: 設定画面の破壊的操作はエラー色を使い、設定セクション見出しは M3 section-label 相当の余白/スタイルに揃える。
- `oss-license-notices`: Apache NOTICE のライセンス全文リンクはアイコン付き Material ボタンとして表示し、48dp 以上のタッチターゲットを持つ。
- `lgpl-compliance`: LGPL notice の上流ソース / THIRD_PARTY_NOTICES / LGPL 全文リンクはアイコン付き Material ボタンとして表示し、48dp 以上のタッチターゲットを持つ。
- `ui-design-system`: 後続 UI 実装がタッチターゲットとセクション見出し余白に既存デザイントークンを使うことを具体化する。

## Impact

- Code: `app/lib/features/settings/presentation/settings_screen.dart`, `app/lib/features/settings/presentation/sections/{library_section,cache_section,online_services_section,r18_section}.dart`, `app/lib/features/about/presentation/{license_screen,lgpl_notice_section}.dart`。
- Tests: `app/test/features/settings/presentation/settings_screen_test.dart` と、必要に応じて `app/test/features/settings/presentation/*_section_test.dart` / `app/test/features/about/license_screen_test.dart` を更新する。
- Localization: 既存ラベルを再利用し、新しいユーザー可視文字列は原則追加しない。追加が必要な場合は ARB 日英両方に反映する。
- Validation: `cd app && dart format --output=none --set-exit-if-changed . && flutter analyze --fatal-infos && flutter test`, `openspec validate --all --strict`, `git diff --check`。ローカル Flutter がない場合は GitHub Actions の run URL を PR に記録する。

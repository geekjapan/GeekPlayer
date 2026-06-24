## 1. テストで期待動作を固定する

- [x] 1.1 `app/test/features/settings/presentation/settings_screen_test.dart` または section 別 test に、履歴削除・キャッシュ削除・同意取り消し後の本文キャッシュ削除・R18 リセットの確定ボタンと、破壊的操作行がある箇所の icon が `colorScheme.error` を使う検査を追加する
- [x] 1.2 `app/test/features/about/license_screen_test.dart` に、Apache NOTICE と LGPL notice のリンクボタンが `AppSizes.minTouchTarget` 以上の高さを持つ検査を追加する
- [x] 1.3 `app/test/features/settings/presentation/settings_screen_test.dart` に、`SettingsSection` 見出しが token 由来の余白と Material 3 section-label 相当の style を使う検査を追加する

## 2. 破壊的操作の色を修正する

- [x] 2.1 `library_section.dart` の履歴削除行 icon と確認ダイアログの「削除する」ボタンに `colorScheme.error` / `onError` を適用する
- [x] 2.2 `cache_section.dart` のサイト別削除・全削除行 icon と確認ダイアログの「削除する」ボタンに `colorScheme.error` / `onError` を適用する
- [x] 2.3 `online_services_section.dart` の本文キャッシュ削除確認ダイアログで「削除する」だけを `colorScheme.error` / `onError` にし、「残す」は通常の TextButton のままにする
- [x] 2.4 `r18_section.dart` のリセット行 icon と確認ダイアログの「リセットする」ボタンに `colorScheme.error` / `onError` を適用する

## 3. ライセンス/notice リンクのタッチターゲットを修正する

- [x] 3.1 `license_screen.dart` の Apache NOTICE ライセンス全文リンクを、既存遷移先を維持した `TextButton.icon` 相当へ置き換え、`AppSizes.minTouchTarget` 以上の高さを保証する
- [x] 3.2 `lgpl_notice_section.dart` の上流ソース・THIRD_PARTY_NOTICES・LGPL 全文リンクを、既存リンク先を維持した `TextButton.icon` 相当へ置き換え、`AppSizes.minTouchTarget` 以上の高さを保証する
- [x] 3.3 置き換え後も外部リンク失敗時の SnackBar と bundled license detail 遷移が既存どおり動くことを確認する

## 4. 設定 section 見出しを M3 / token に寄せる

- [x] 4.1 `settings_screen.dart` の `SettingsSection` で `AppSpacing` token を使い、外側/見出し周辺の余白から直接数値を取り除く
- [x] 4.2 `SettingsSection` 見出しを `titleMedium` より控えめな Material 3 section-label 相当の style に変更し、各 section の表示順と key を維持する

## 5. 検証

- [x] 5.1 `cd app && dart format --output=none --set-exit-if-changed .` を実行する（ローカル Flutter/Dart がない場合は未実行理由を記録する）
- [x] 5.2 `cd app && flutter analyze --fatal-infos` を実行する（ローカル Flutter/Dart がない場合は GitHub Actions で確認する）
- [x] 5.3 `cd app && flutter test` を実行する（ローカル Flutter/Dart がない場合は GitHub Actions で確認する）
- [x] 5.4 `openspec validate --all --strict` を実行する
- [x] 5.5 `git diff --check` を実行する
- [x] 5.6 PR に Issue #41、OpenSpec change `polish-settings-actions-a11y`、validation 結果または CI run URL を記録する

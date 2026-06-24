## 1. 空ライブラリ状態の無効プレースホルダボタン除去

- [x] 1.1 `app/lib/features/novel/presentation/novel_home_section.dart` の `_EmptyPlaceholder` から無効 `OutlinedButton`（key `open-search-disabled`）・直前の `SizedBox(height: 8)`・開発者コメントを削除し、placeholder テキストのみ表示にする
- [x] 1.2 `app/test/features/novel/home_section_test.dart` の空状態テストを placeholder テキストのみの assert に更新し、`open-search-disabled` ボタンの assert を削除する

## 2. consent ダイアログの policyVersion デバッグ文言除去

- [x] 2.1 `app/lib/features/novel/presentation/consent_dialog.dart` から `Text('policyVersion: $kPolicyVersion', ...)` と直前の `SizedBox(height: 4)` を削除する
- [x] 2.2 未使用化する `import '../../../core/novel/policy_version.dart';` を削除し、クラス doc コメントの `[kPolicyVersion]` doc 参照を平文に修正する
- [x] 2.3 `app/test/features/novel/consent_dialog_test.dart` に「ダイアログ本文に `policyVersion` 文言が表示されないこと」の assert を追加する

## 3. spec 更新

- [x] 3.1 `online-novel-library` の「Empty Library shows placeholder」シナリオを、無効ボタン要求を外し placeholder テキストのみとする MODIFIED delta を作成する
- [x] 3.2 `site-consent` に「`ConsentDialog` は内部 `policyVersion` をユーザー向け本文に表示しない」invariant の ADDED requirement を作成する

## 4. 検証

- [x] 4.1 `openspec validate --all --strict` が pass することを確認する
- [ ] 4.2 PR を作成して GitHub Actions の `analyze-and-test` ジョブが green になることを確認する（`dart format`・`flutter analyze --fatal-infos`・`flutter test` の全パス）

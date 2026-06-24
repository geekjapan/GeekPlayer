## Why

UI Phase 2 バッチ4（issue #43）では、バッチ3で意図的にスコープ外とした項目⑦を扱う。プレゼンテーション層に 2 つのユーザー可視デバッグ artifact が残っている。

1. **永久無効プレースホルダボタン**: `novel_home_section.dart` の空ライブラリ状態に、`onPressed: null` で固定された `OutlinedButton` があり、ラベルがハードコードの開発者向けコメント `'検索画面を開く (後続 change で有効化)'` をそのままユーザーに露出している。機能しない dead UI であり、ローカライズもされていない。
2. **policyVersion デバッグ文言**: `consent_dialog.dart` が同意ダイアログ本文に `Text('policyVersion: $kPolicyVersion')`（例: `policyVersion: 2026-05-27`）を表示している。`policyVersion` は `site-consent` 仕様上、ポリシー更新検知・再プロンプトのための内部制御値であり、ユーザー向け開示情報ではない。

いずれも consent / policy-version のセマンティクス（`site_consents` への保存・再プロンプト判定）には関与しない純粋な表示物であり、除去してもふるまいは変わらない。

## What Changes

- **空ライブラリ状態の無効ボタン除去**: `novel_home_section.dart` の `_EmptyPlaceholder` から無効 `OutlinedButton`（と直前の `SizedBox`・開発者コメント）を削除し、placeholder テキストのみを表示する。検索への導線の発見性向上は issue #51（ホーム画面 IA）のスコープであり本 change では扱わない。
- **policyVersion 表示の除去**: `consent_dialog.dart` から `policyVersion` を表示する `Text`（と直前の `SizedBox`）を削除する。表示にのみ使われていた `core/novel/policy_version.dart` の import が未使用化するため除去し、ダイアログ doc コメントの `[kPolicyVersion]` doc 参照を平文へ修正する（`flutter analyze --fatal-infos` 回帰回避）。
- **spec 更新**:
  - `online-novel-library`: 「Empty Library shows placeholder」シナリオから無効ボタン要求を削除（placeholder テキストのみ）。
  - `site-consent`: 同意ダイアログが内部 `policyVersion` 文字列をユーザー向け本文として表示してはならない、という invariant を追加。
- **テスト更新**: `home_section_test.dart` の空状態テストを placeholder テキストのみの assert に更新。`consent_dialog_test.dart` に「`policyVersion` 文言が表示されないこと」の assert を追加。

## Capabilities

### Modified Capabilities

- `online-novel-library`: `NovelHomeSection` の空ライブラリ状態は placeholder テキストのみを表示する（無効プレースホルダボタンを表示しない）。
- `site-consent`: `ConsentDialog` は内部制御値 `policyVersion` をユーザー向け本文に表示しない（保存・再プロンプトのセマンティクスは不変）。

## Non-goals

- 検索画面への新規導線追加・ホーム画面の情報設計改善（issue #51 / #50）。
- `policyVersion` の保存・再プロンプト・しきい値判定ロジックの変更（`consent_repository` / `database` / `site_consents` テーブルは不変）。
- 動画・音楽・書籍・漫画など novel 以外の surface の UI 変更。

## Impact

- **変更ファイル（実装）**:
  - `app/lib/features/novel/presentation/novel_home_section.dart`
  - `app/lib/features/novel/presentation/consent_dialog.dart`
- **変更ファイル（spec delta）**:
  - `openspec/changes/.../specs/online-novel-library/spec.md`
  - `openspec/changes/.../specs/site-consent/spec.md`
- **変更ファイル（テスト）**:
  - `app/test/features/novel/home_section_test.dart`
  - `app/test/features/novel/consent_dialog_test.dart`
- **依存関係追加なし**・**破壊的変更なし**（API シグネチャ不変、DB スキーマ不変）。

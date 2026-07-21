## Context

issue #43 / バッチ3 proposal の Non-goals で「⑦（永久無効プレースホルダボタン・`policyVersion` デバッグ文言除去）はバッチ4」と明記されていた項目。対象は novel feature の 2 ファイルのみで、いずれも表示専用 artifact の除去。

## Decisions

### D1. 無効ボタンは「ローカライズ」ではなく「除去」する

選択肢:
- (A) ハードコード文言を ARB 経由のローカライズ済みラベルに置換し、無効ボタンは残す。
- (B) 無効ボタンを丸ごと除去し、空状態は placeholder テキストのみにする。**← 採用**

理由: issue タイトルは "remove permanent placeholders"。`onPressed: null` で固定された永久無効ボタンは機能しない dead UI であり、ラベルをローカライズしても「押せない導線」が残るだけで価値がない。検索への実導線は per-site 検索画面（narou / kakuyomu）が別途存在し、その発見性改善は issue #51（ホーム IA）の責務。空状態の placeholder テキスト自体は状態を説明できているため、ボタン除去で機能後退は生じない。

### D2. `policyVersion` 表示の除去は spec セマンティクスを変えない

`site-consent` 仕様の `policyVersion` 要求は「`site_consents` の各行に保存」「起動時に古ければ再プロンプト」であり、ダイアログ本文への表示は規定されていない。表示 `Text` の除去は保存・再プロンプトのいずれにも影響しない（`consent_repository.saveDecisions` が stamp、起動時判定は別経路）。

副作用として `consent_dialog.dart` 内で `kPolicyVersion` 参照が表示 `Text` のみだったため、import が未使用化する。これを除去し、クラスの doc コメントの `[kPolicyVersion]` doc 参照を平文（"the current policy version"）に変更して `comment_references` / `unused_import` の analyzer 回帰を防ぐ。

### D3. spec は online-novel-library を MODIFIED、site-consent を ADDED で更新する

- `online-novel-library`「NovelHomeSection on the home screen」requirement の空状態シナリオを、無効ボタン要求を外した形に MODIFIED で再記述する。
- `site-consent` には「内部 policyVersion をユーザー向け本文に表示しない」invariant を ADDED requirement として追加し、デバッグ文言の再混入を仕様で防止する。表示しない invariant は `consent_dialog_test.dart` の widget test で enforce する。

## Risks / Trade-offs

- **空状態がテキストのみになり寂しい**: 機能的には正しい（押せない導線を消すだけ）。発見性は #51 で別途扱う。
- **CI のみで検証**: ローカル Flutter が無いため、`dart format` / `flutter analyze --fatal-infos` / `flutter test` は GitHub Actions で確認する。`comment_references` 回帰は import 除去と doc 平文化で先回り対処済み。

## Validation

```bash
cd app
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
cd ..
openspec validate --all --strict
git diff --check
```

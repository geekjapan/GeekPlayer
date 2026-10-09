## 1. クイックジャンプ chip 列の実装

- [x] 1.1 `app/lib/features/library/home_quick_jump.dart` を新規作成し、登録済みセクション id(`video`/`audio`/`novel`/`book`/`manga`/`media_library`)→ (ローカライズ済みラベル, `IconData`) の静的マップと、chip 列を描画する `HomeQuickJumpBar` widget を実装する
- [x] 1.2 `app/lib/features/library/home_screen.dart` の `ListView` 内の `Column` に並べた各セクションへ `GlobalKey` を割り当て、`AppBar` 直下に `HomeQuickJumpBar` を配置し、chip タップで対応する `GlobalKey` に対し `Scrollable.ensureVisible` を呼ぶ
- [x] 1.3 `HomeSection` インターフェース(`home_section.dart`)・他 5 feature の `*HomeSection` 実装ファイル・`order` 値は変更しないことを確認する

## 2. アクセシビリティ

- [x] 2.1 chip 列全体と各 chip に `Semantics`/tooltip ラベルを付与し、キーボード操作時のフォーカス移動順が視覚的な並び順と一致することを確認する
- [x] 2.2 chip のタップ領域が `AppSizes.minTouchTarget`(48dp)を満たすことを確認する(`ui-design-system` capability のトークンを参照)

## 3. ローカライズ

- [x] 3.1 `app/lib/l10n/app_ja.arb` にクイックジャンプ用の新規キー(例: `homeQuickJumpVideo`/`homeQuickJumpAudio`/`homeQuickJumpNovel`/`homeQuickJumpBook`/`homeQuickJumpManga`/`homeQuickJumpMediaLibrary`/`homeQuickJumpSemanticLabel`)を追加する
- [x] 3.2 `app/lib/l10n/app_en.arb` に対応する英語訳を追加する
- [x] 3.3 `dart run build_runner build --delete-conflicting-outputs` 相当の生成物更新が必要か確認する(ARB からの `AppLocalizations` 生成は `flutter gen-l10n` 経由のため、CI のビルドステップで再生成されることを確認する)

## 4. spec 追加

- [x] 4.1 新規 capability `home-screen-navigation` の ADDED spec(`specs/home-screen-navigation/spec.md`)を作成する。要求: 「登録済み各セクションへのクイックジャンプ導線を提供する」「導線はアクセシブルである(Semantics/tooltip/キーボード操作)」の 2 requirement + scenario を含める

## 5. テスト

- [x] 5.1 `app/test/features/library/home_quick_jump_test.dart` を新規作成し、6 セクション分の chip が表示されること、chip タップで対応セクションが可視領域に入ること(`tester.ensureVisible` 相当のアサーション)を検証する
- [x] 5.2 `app/test/widget_test.dart` に、クイックジャンプ chip 列がホーム画面に存在することを確認するアサーションを追加する(既存アサーションは変更しない)

## 6. 検証

- [x] 6.1 `openspec validate --all --strict` が pass することを確認する
- [ ] 6.2 PR を作成して GitHub Actions の `analyze-and-test` ジョブが green になることを確認する(`dart format`・`flutter analyze --fatal-infos`・`flutter test` の全パス)
- [ ] 6.3 macOS でクイックジャンプ chip の実機動作確認(ポインタ操作 + キーボードフォーカス移動)を行う。Windows 実機確認は2026-10-09のユーザー指示により SKIP

## 検証記録

- 2026-10-09: ローカルの format / analyze / 全636テスト / OpenSpec全49項目 / `git diff --check` が成功。詳細は [verification.md](verification.md)。
- 6.2: 今回の変更のpush・PR作成・CIは未実施。
- 6.3: Xcode本体が未インストールのため変更後アプリのmacOSビルドができず、実機確認は保留。配布版 v0.1.1 のComputer Use確認は今回の変更の合格証拠に含めない。Windows実機確認はユーザー指示によりSKIP。

## Why

初期ホーム画面（`app/lib/features/library/home_screen.dart:11`）は、ADR-0004 のセクションレジストリ方式により動画・音楽・オンライン小説・書籍・漫画・メディアライブラリの 6 セクションを縦一列の `ListView` に積み上げているだけで（`home_screen.dart:25-29`）、セクション間を移動するための導線が一切ない。ユーザーは目的の機能に辿り着くまで前段のセクションを毎回スクロールして通過する必要があり、「どこから何をすればよいか分からない」「動画・音楽・書籍・漫画・オンライン小説のどれをまず開けばよいか分からない」（issue #51 本文）という問題が生じている。加えて各セクションの見出し・CTA の視覚様式がバラバラで（後述）、スキャンによる発見も難しい。

本 change は issue #51（milestone #1 "UI Phase 2: correctness and accessibility"）が要求するホーム画面の発見性改善のうち、小さく閉じた一歩目として「セクション間を直接ジャンプできる導線を追加する」ことに絞って着手する。バッチ4 (`ui-phase-2-batch-4-remove-placeholders-policy-debug`) の proposal.md で issue #51 は明示的に「別 change」として先送りされていた項目であり、本 change がそれを引き継ぐ。

## What Changes

- **ホーム画面クイックジャンプ導線の追加**: `HomeScreen`（`app/lib/features/library/home_screen.dart`）の `AppBar` 直下に、登録済みセクション（動画・音楽・小説・書籍・漫画・メディアライブラリ）へ 1 タップで移動できる横スクロールの chip 列を追加する。タップすると本文の `ListView` が該当セクションまでスクロールする。
- **実装は `library` feature 内に閉じる**: chip のラベル・アイコン・スクロール対象の対応表は `library` feature 内の新規ファイル（例: `home_quick_jump.dart` + 小さな id→(label, icon) マッピング）に持たせ、`HomeSection` インターフェース（`app/lib/features/library/home_section.dart:15-20`）や各 feature の `*HomeSection` 実装ファイル（video/audio/novel/book/manga/media_library の計 6 ファイル）は変更しない。ADR-0004 が定めた「`HomeScreen` は集約コンテナ、各 feature はサブプロバイダ追加のみ」という責務分担を壊さない。
- **アクセシビリティ対応**: 追加する chip 列に `Semantics` ラベル・tooltip・キーボード/フォーカス移動順を付与し、milestone #1 の "correctness and accessibility" 方針に沿わせる。
- **ローカライズ**: 新規 UI 文言はすべて `AppLocalizations` 経由の ARB キー（`app/lib/l10n/app_ja.arb` / `app_en.arb`）として追加する。既存セクション見出し文言（動画・音楽は現状 `Text('動画')` のようにハードコード — `app/lib/features/video/presentation/home_section.dart:31`, `app/lib/features/audio/presentation/home_section.dart:32`）には手を入れず、クイックジャンプ用のラベルは独立した新規キーとして定義する。
- **テスト追加**: クイックジャンプ chip 列のレンダリングとタップ時のスクロール挙動を検証するウィジェットテストを追加する。

## Capabilities

### New Capabilities

- `home-screen-navigation`: ホーム画面に登録された各セクションへ、スクロールに依存せず直接移動できるクイックジャンプ導線を提供する。

### Modified Capabilities

(なし — 既存の `local-video-playback`/`local-audio-playback`/`online-novel-library`/`book-library`/`manga-library`/`media-library` capability の要求は変更しない。追加するのは新しいナビゲーション層のみ。)

## Non-goals

- 各セクション本体（動画・音楽・小説・書籍・漫画・メディアライブラリ）の内部レイアウト再設計・見出しスタイルの統一(Card 有無、`titleLarge`/`titleMedium` 混在、CTA ボタンの様式差など)は本 change では扱わない。将来の別バッチで検討する。
- 既存 `HomeSection.order` 値の並べ替え(例: メディアライブラリの「最近見た項目」サマリをより上位に昇格させる案)は行わない。ADR-0004 の order 予約表は各 feature が所有する値であり、他 feature が既に出荷したセクションの表示順を本 change で変更すると影響範囲が本来の趣旨(クイックジャンプ導線の追加)を超えて広がるため見送る。design.md の Decisions で検討過程を記録する。
- ボトムナビゲーションバー・ナビゲーションレール・ドロワーなど、ADR-0004 が確立した「縦一列 `ListView` + セクションレジストリ」というレイアウト方式自体を置き換えるアーキテクチャ変更は行わない。
- issue #50(コンテンツを開いた後の操作・ナビゲーション問題)は issue #51 の本文で明示的に別スコープとされており、本 change でも扱わない。
- 動画・音楽・小説・書籍・漫画の各 feature のビジネスロジック・データ層・同意(consent)フローの変更は行わない。

## Impact

- **変更予定ファイル(実装、library feature 内に限定)**:
  - `app/lib/features/library/home_screen.dart`(クイックジャンプ chip 列の追加、`ScrollController` 導入)
  - `app/lib/features/library/home_quick_jump.dart`(新規、chip 列 widget + id→(label, icon) マッピング)
  - `app/lib/l10n/app_ja.arb` / `app/lib/l10n/app_en.arb`(新規 ARB キー追加)
- **変更予定ファイル(spec)**:
  - `openspec/changes/improve-home-discoverability/specs/home-screen-navigation/spec.md`(新規 ADDED capability)
- **変更予定ファイル(テスト)**:
  - `app/test/features/library/home_quick_jump_test.dart`(新規)
  - `app/test/widget_test.dart`(クイックジャンプ chip 列の存在を確認するアサーション追加、既存アサーションは変更しない)
- **他 feature への影響なし**: video/audio/novel/book/manga/media_library の各 `*HomeSection` 実装ファイル・`order` 値・ドメイン層・データ層は変更しない。
- **依存関係追加なし**(新規パッケージ不要、既存 `flutter_riverpod`/Material 3 のみで実装可能と想定 — 詳細は design.md)。
- **破壊的変更なし**(`HomeSection` インターフェースのシグネチャ不変、DB スキーマ不変)。

GitHub Issue: #51
Milestone: #1 (UI Phase 2: correctness and accessibility)

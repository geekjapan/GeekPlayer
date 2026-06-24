## Context

UI Phase 2 バッチ2は、既存の設定画面・ライセンス画面を小さく整える change である。対象は Flutter / Material 3 の既存 UI に閉じており、永続化、DB schema、外部通信、配布フローは変更しない。

現状の主要な制約:

- `app/lib/core/theme/tokens.dart` に `AppSpacing` と `AppSizes.minTouchTarget == 48` があるが、対象 UI にはまだ 12/16 などの直接値や小さい `InkWell` リンクが残っている。
- 破壊的操作の確認ダイアログは `FilledButton` と削除/リセット系 icon を使っているが、明示的に `colorScheme.error` を使っていない箇所がある。
- ローカル環境では Flutter/Dart が使えない場合があるため、実装後の完全検証は GitHub Actions の `analyze-and-test` を前提にする。

## Goals / Non-Goals

**Goals:**

- 設定画面の破壊的操作が、確定ボタンと、削除/リセット行が存在する場合の行アイコンで theme の error 色を使う。
- License / notice のリンクが Material 3 のアイコン付きボタンになり、最小 48dp のタッチターゲットを持つ。
- 設定セクション見出しが既存トークンに基づく余白と Material 3 section-label 相当のテキストスタイルを使う。
- 対象 widget test で色・サイズ・見出し契約を固定する。

**Non-Goals:**

- Phase 2 の他項目 ④⑥⑦、レイアウト全面刷新、ナビゲーション変更は行わない。
- 新しい design token や theme extension は追加しない。既存 `AppSpacing` / `AppSizes` を使う。
- ライセンス文面、法務要件、外部 URL、バンドル asset の内容は変更しない。

## Decisions

### D1: 破壊的ダイアログは `FilledButton.styleFrom` で局所的に error 色を指定する

確認ダイアログの確定ボタンは `FilledButton` のままにし、`backgroundColor: colorScheme.error` と `foregroundColor: colorScheme.onError` を指定する。履歴削除・キャッシュ削除・R18 リセットのように破壊的操作を表す `ListTile` icon がある場合、その icon も `colorScheme.error` を使う。オンラインサービスの同意取り消し後キャッシュ削除は dialog 内の選択肢だけで、専用の削除 icon は追加しない。

理由: `FilledButton` の affordance を維持したまま、破壊的操作だけを明示できる。全アプリの `filledButtonTheme` を変えると通常の primary action まで error になり得るため、局所指定にする。

代替案:

- `TextButton` に変える: destructive action として弱く見え、既存 UI の確定ボタン階層を下げるため採用しない。
- グローバルな destructive button theme を作る: 今回はボタン種類が少なく、既存 design token だけで足りるため採用しない。

### D2: License / notice リンクは小さな `_InlineLink` ではなく `TextButton.icon` へ寄せる

Apache NOTICE と LGPL notice のリンクは `TextButton.icon` 形状に統一し、`minimumSize: const Size(0, AppSizes.minTouchTarget)` または同等の `ButtonStyle` を設定する。外部リンクは `Icons.open_in_new`、画面内遷移は `Icons.chevron_right` を維持する。

理由: `TextButton.icon` はキーボード/semantics/focus/hover を Material 側に任せられ、48dp タッチターゲットも明示できる。既存の `InkWell` + `Padding(vertical: 6)` は視覚的にはリンクに見えるが、タッチ領域が不足しやすい。

代替案:

- `ListTile` に置き換える: notice card 内でリンクが強くなりすぎ、文書カードの密度が変わるため採用しない。
- `InkWell` の padding だけ増やす: 最小サイズ契約と semantics が曖昧なまま残るため採用しない。

### D3: `SettingsSection` は既存 token と M3 label style を使う

`SettingsSection` の外側/内側余白を `AppSpacing` に置き換え、見出しは `textTheme.titleSmall` か `labelLarge` に `colorScheme.primary` または `onSurfaceVariant` を組み合わせる。section-label として目立ちすぎない見出しにし、各セクション内の `ListTile` より一段上のグルーピングとして読めるようにする。

理由: 現状の `titleMedium` はカード見出しとしてやや強く、設定リスト内で repeated section label としては重い。トークン参照へ寄せることで Phase 1 design system の方針と整合する。

代替案:

- `ListTile` の `title` を section header に流用する: 子 row と同じ階層に見えるため採用しない。
- 新しい `SettingsHeader` widget を別ファイルに切り出す: 現時点では `SettingsSection` だけで使われ、抽象化の利益が小さいため採用しない。

### D4: テストは色・最小サイズ・共有 section contract に絞る

既存 widget tests に、以下の観点を追加する:

- destructive action の confirm button と、破壊的操作行がある箇所の icon が `colorScheme.error` と `onError` を使う。
- notice link button の `Size.height >= AppSizes.minTouchTarget`。
- `SettingsSection` の見出しが期待する text style / padding token に沿う。

理由: ローカル Flutter がない環境では CI が最終判定になるため、回帰検出は狭く明確な widget test に寄せる。スクリーンショット差分や golden test は今回の変更範囲に対して重い。

## Risks / Trade-offs

- [Risk] ボタン style の指定漏れで一部の破壊的操作だけ primary 色のまま残る。→ 4 種類の dialog を test で開き、confirm button と、破壊的操作行がある箇所の icon 色を検査する。
- [Risk] `TextButton.icon` への変更で notice card 内の縦幅が増える。→ 48dp は a11y 要件として受け入れ、card 内では左寄せ・低密度を保つ。
- [Risk] 見出し style の期待値を厳密にしすぎると theme 微修正で test が壊れやすい。→ 直接 font size を固定せず、`Theme.of(context).textTheme` 由来であることと token padding を中心に検査する。
- [Risk] ローカル Flutter 不在で `dart format` / `flutter test` を実行できない。→ 実行不可の場合は PR で GitHub Actions の `analyze-and-test` run URL を記録し、OpenSpec / diff check はローカルで実施する。

## Migration Plan

1. 既存 UI の widget 実装と widget tests を更新する。
2. `openspec validate --all --strict` と `git diff --check` をローカルで実行する。
3. Flutter が利用できる環境では `cd app && dart format --output=none --set-exit-if-changed . && flutter analyze --fatal-infos && flutter test` を実行する。
4. ローカル Flutter がない場合は PR を作成し、GitHub Actions の `analyze-and-test` を検証結果として記録する。

Rollback は単純な UI 変更の revert で足りる。永続化・schema・asset 内容の migration は不要。

## Open Questions

- なし。Issue #41 と `docs/HANDOFF.md` のバッチ2範囲に従う。

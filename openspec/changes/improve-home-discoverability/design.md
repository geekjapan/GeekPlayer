## Context

`HomeScreen`(`app/lib/features/library/home_screen.dart:11-32`)は ADR-0004「HomeScreen をセクションレジストリ方式で構成する」に従い、`homeSectionsProvider`(`app/lib/features/library/home_section_registry.dart`)が集約する `List<HomeSection>` を `order` 昇順に `ListView` へ並べているだけの薄い集約コンテナである。現在の登録済みセクションと `order`(ADR-0004 の予約表):

| order | セクション | 実装ファイル |
|---|---|---|
| 100 | MiniPlayer(audio) | `app/lib/features/audio/...`(常時表示のトランスポートバー) |
| 200 | 動画 | `app/lib/features/video/presentation/home_section.dart` |
| 300 | 音楽 | `app/lib/features/audio/presentation/home_section.dart` |
| 400 | オンライン小説(なろう検索/ランキング/R18 導線 + サイト別ライブラリグリッドを内包) | `app/lib/features/novel/presentation/novel_home_section.dart` |
| 500 | 書籍 | `app/lib/features/book/presentation/book_home_section.dart` |
| 600 | 漫画 | `app/lib/features/manga/presentation/manga_home_section.dart` |
| 700 | メディアライブラリ(横断的な最近再生/お気に入り件数 + フォルダスキャン) | `app/lib/features/media_library/presentation/media_library_home_section.dart` |

観測された発見性の問題(issue #51):

- 6 セクションが縦一列に積まれているだけで、目的のセクションに行くには前段を毎回スクロールして通過する必要がある。特にオンライン小説セクションはサイトフィルタ chip・なろうショートカット・作品グリッドを内包し縦に長く、それより下の書籍・漫画・メディアライブラリへの到達コストを押し上げている。
- 各セクションの見出し様式が不揃い(動画/音楽は `Card` + `titleLarge`、小説/書籍/漫画/メディアライブラリは `Card` なしの `Padding` + `titleMedium` または `titleLarge` 混在)なため、スクロール中に「今どのセクションにいるか」を素早く判別しづらい。これは本 change の Non-goals(視覚様式の統一)に含めるが、クイックジャンプの chip 自体は独立した見出し的役割を果たすため一定の緩和になる。

## Goals / Non-Goals

**Goals:**

- ホーム画面の任意のセクションへスクロールせずに 1 タップで到達できる導線を提供する。
- 導線の実装を `library` feature 内(集約コンテナを所有する feature)に閉じ、他 5 feature のファイル・`order` 値・仕様を変更しない。
- 新規 UI 文言をローカライズし、キーボード操作・スクリーンリーダーからも導線を利用可能にする(milestone #1 の accessibility 方針)。

**Non-Goals:**

- 各セクション本体の視覚様式統一、`HomeSection.order` の並べ替え、ボトムナビゲーション等へのレイアウト方式変更(proposal.md の Non-goals を参照)。
- issue #50(コンテンツを開いた後のナビゲーション)。

## Decisions

### D1. chip のラベル/アイコン対応表は `library` feature 内の静的マップとして持つ(`HomeSection` インターフェースは拡張しない)

選択肢:

- (A) `HomeSection` インターフェースに `label`/`icon` getter を追加し、video/audio/novel/book/manga/media_library の 6 実装ファイルすべてに実装を追加させる。
- (B) `library` feature 内に `id → (label ResourceKey, IconData)` の静的マップを 1 ファイルで保持し、既存の `HomeSection.id`(`app/lib/features/library/home_section.dart:17`)をキーに引く。**← 採用**

理由: (A) は 6 ファイル・6 feature ディレクトリへの機械的だが横断的な変更を強制し、milestone #1 の「small batch, CI-checked」方針や CONVENTIONS.md §1 の「並列 Wave 実装で merge conflict を最小化する」意図に反して本 change の影響範囲を不必要に広げる。(B) はセクション id が ADR-0004 制定時点から固定の文字列(`'video'`, `'audio'`, `'novel'`, `'book'`, `'manga'`, `'media_library'`)であるため、`library` feature 側だけでマップを持てば十分に安定して機能する。新しいセクションが将来追加された場合はマップにエントリを足すだけでよく、それは「ホーム画面に導線を追加する」という本 capability の責務そのものであるため妥当。

### D2. スクロール実装は `GlobalKey` + `Scrollable.ensureVisible` を使う(オフセット事前計算はしない)

選択肢:

- (A) 各セクションの高さを事前計算し、`ScrollController.animateTo(offset)` で固定オフセットへスクロールする。
- (B) 各セクションのルート widget に `GlobalKey` を割り当て、chip タップ時に対象 key の `BuildContext` に対して `Scrollable.ensureVisible(context, duration: ..., alignment: 0)` を呼ぶ。**← 採用**

理由: オンライン小説セクションはサイトフィルタ・作品数・consent 状態(`FutureBuilder`)によって高さが動的に変わり(`novel_home_section.dart:90-106`)、メディアライブラリセクションも最近再生件数によって高さが変わる。固定オフセット計算は実行時の実高さとずれるため信頼できない。`Scrollable.ensureVisible` は対象ウィジェットの実際のレイアウト位置を使うため、動的な高さ変化に対して頑健。実装コストも `GlobalKey` を `ListView` の各アイテムラッパーに割り当てるだけで小さい。

### D3. MiniPlayer(order 100)にはジャンプ chip を用意しない

MiniPlayer は「機能セクション」ではなく常時表示のトランスポートバーであり、ユーザーが「ジャンプして到達したい先」には該当しない。ジャンプ chip は 動画・音楽・小説・書籍・漫画・メディアライブラリ の 6 個とする。

### D4. `HomeSection.order` の並べ替えは行わない(non-goal として明記)

メディアライブラリの「最近見た項目」サマリを上位(例: order 150)に昇格させ、返り咲きユーザーが各フォーマット別 Card を経由せず直接「最近の続き」に辿り着けるようにする案を検討したが、以下の理由で見送り、別 change に委ねることとした:

- `order` は ADR-0004 が各 feature の所有物として予約する値であり、`media_library` feature が既に出荷済みの `order = 700`(`media_library_home_section.dart:21`)を本 change(library feature 視点のナビゲーション追加)が書き換えるのは責務越境になる。
- 並べ替えは「クイックジャンプ導線の追加」という本 change の一点集中スコープを超え、milestone #1 が求める small batch の趣旨に反する。
- 将来この案を採用する場合は `media-library` capability 側の change として提案し、当該 spec・テストの更新を伴わせるべき。

### D5. capability は ADDED のみとし、既存 spec への MODIFIED delta は作成しない

クイックジャンプ導線は既存 6 capability(`local-video-playback` 等)の要求(何が表示されるか、どう振る舞うか)を一切変更せず、新しい横断的ナビゲーション層を追加するだけである。したがって `openspec/specs/` 配下の既存 spec には手を入れず、新規 capability `home-screen-navigation` の ADDED spec のみを作成する。

## Risks / Trade-offs

- **[Risk]** 静的マップ(D1)が `HomeSection.id` の実際の登録内容と乖離する(例: 将来 feature が id を変更したのにマップを更新し忘れる) → **Mitigation**: ウィジェットテストで「登録済み全セクションに対応する chip が存在すること」を検証し、id の不一致があればテストが失敗するようにする。
- **[Risk]** `Scrollable.ensureVisible` はターゲット widget がまだビルドされていない(スクロール未到達で `ListView` が遅延構築中の)場合に正しく動作しない可能性がある → **Mitigation**: `HomeScreen` の `body` は `ListView`(非 `.builder`、`home_screen.dart:26`)であり全セクションが常に一括ビルドされるため、この懸念は現状の実装では発生しない。将来 `ListView.builder`化する場合は再検討が必要である旨をコードコメントに残す。
- **[Risk]** chip 列を追加することで、AppBar 直下の縦スペースが圧迫され小画面(モバイル/タブレット幅)で窮屈になる可能性 → **Mitigation**: chip 列は横スクロール可能な 1 行に収め、`ui-design-system` capability の spacing/touch-target トークン(`AppSizes.minTouchTarget`, `AppSpacing`)を流用してレイアウト崩れを防ぐ。
- **[Trade-off]** メディアライブラリの並べ替え(D4)を見送ったことで、「最近の続きを見る」までの到達コストはクイックジャンプ chip 経由でも変わらず 1 タップ + 該当セクションまでのスクロールが必要(0 タップにはならない)。発見性の抜本改善は次バッチに持ち越す。

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

ローカルに Flutter/Dart が無い環境では上記のうち `flutter` 系コマンドは GitHub Actions(`analyze-and-test` job)での実行結果を PR に記録する。`openspec validate --all --strict` と `git diff --check` はローカルで実行する。

手動検証は macOS と Windows の両方で、クイックジャンプ chip をタップして各セクションへ実際にスクロールすることを確認する(デスクトップターゲットでのポインタ操作 + キーボードフォーカス移動の両方を確認)。

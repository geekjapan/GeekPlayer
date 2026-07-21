## Context

issue #50 は、macOS / Windows 実機で「動画再生開始後にホームへ戻る導線を見失う」「漫画/コミックビューアで操作コントロールが不明瞭・利用不能に見える」という報告に基づく。動画の戻るボタン（`Icons.arrow_back` + `Navigator.of(context).maybePop()`）と漫画の AppBar は実装済みであり、監査ではそれらが自動非表示または状態依存になることでデスクトップ上で発見しにくく／一時的に効かなくなる経路を再現する。issue #43 バッチ3/4 は novel 面の表示専用 artifact 除去に限定してクローズし、#50（本件）と #51（ホーム IA）を明示的に先送りにした。

本 change は実装修正を含まない監査単独バッチである。理由は milestone #1 の運用方針（"Keep each batch small because local Flutter is unavailable and CI is the checker"）に沿い、まず問題箇所をコードから具体的に特定し、修正の要否・優先度・スコープを事前に固定してから、小さい後続 change に分割するため。

対象コードは `app/lib/features/{video,manga,book,audio,novel_kakuyomu,novel_narou}/presentation/` 配下。`grep -rn "Platform.isMacOS\|Platform.isWindows"` を対象 feature 全体（`video/ audio/ manga/ book/ novel/ novel_kakuyomu/ novel_narou/`）に対して実行した結果ヒットなし。つまり macOS/Windows 固有の分岐処理はこれらの feature に一切存在しない。同様に `KeyboardListener|Focus(|Shortcuts(|LogicalKeyboardKey|onKeyEvent|RawKeyEvent|MouseRegion|Actions(|Intent` の grep でも、キーボード/マウス操作を明示的に扱うコードはヒットしなかった（`novel/data/novel_page_session.dart` と `novel_narou/presentation/search_screen.dart` のヒットは無関係な `// Intentionally swallowed.` コメントと `ScrollController.addListener` であり、対象外）。`pubspec.yaml` に `window_manager` / `bitsdojo_window` 等のデスクトップウィンドウ管理パッケージは存在せず、OS 標準のタイトルバー・最小化/最大化/閉じるボタンがそのまま使われている（独自オーバーレイによる被覆は無い）。

## Goals / Non-Goals

**Goals:**

- 対象 6 面（動画・漫画・書籍・音声フル/ミニ・カクヨム/なろうリーダー）の「開く→操作→戻る/閉じる→ホーム」フローをコードレベルで検証し、macOS/Windows で問題になりうる箇所を `file_path:line_number` 付きで特定する。
- 各所見に、issue #50 の報告内容との対応関係、影響度（trap/discoverability/minor）、対応要否の初期判断を付与する。
- 本 change のスコープ内で直す/直さないの線引きを明確にする。
- 修正前の macOS/Windows デスクトップ操作で、既存コントロールが見えない／条件付きで効かない状態を再現し、観測結果とコード行を証拠として残す。コントロールが存在しないとは記録しない。

**Non-Goals:**

- 特定した問題の実装修正（後続 change）。
- ホーム画面 IA 改善（issue #51）。
- テストコードの追加（後続 change のタスクとする）。

## Decisions

### D1. 監査方法論: grep による横断走査 + 対象ファイルの全文読解

まず `Platform.isMacOS/isWindows` と キーボード/マウス関連 API（`KeyboardListener`, `Shortcuts`, `LogicalKeyboardKey`, `MouseRegion`, `Actions`/`Intent` 等）の grep を対象 feature ディレクトリ全体に対して行い、macOS/Windows 固有分岐・デスクトップ入力処理の有無を横断的に確認した（結果: 両方ともヒットなし＝分岐も専用入力処理も存在しない）。次に対象 6 ファイルを全文読解し、「戻る」導線の可視性条件、コントロールの表示/非表示ロジック、ナビゲーション用タップ領域の可視性条件を突き合わせた。

理由: macOS/Windows は原則同一の Flutter デスクトップ入力経路（マウス/キーボード）を共有し、Android 由来のタッチ操作前提の UI がそのまま流用されている場合に問題が生じやすい。grep でその欠落を横断的に裏付けたうえで、個別ファイルの読解で具体的な行を特定する二段構えとした。

### D2. 修正前のデスクトップ再現証拠

監査時点の macOS/Windows デスクトップ入力で、次の操作を行って issue #50 の「見つからない／効かない」状態を再現する。これは修正前の観測であり、本 change では UI や操作経路を変更しない。

- **Video**: video home から `PlayerScreen` を開く（`app/lib/features/video/presentation/home_section.dart:72-74`）。初期オーバーレイは `_scheduleHide`（`player_screen.dart:31-35`）で 3 秒後に `_overlayVisible = false` となる（`player_screen.dart:43-47`）。戻るボタン自体は `_TopBar` の `Icons.arrow_back` と `Navigator.of(context).maybePop()`（`player_screen.dart:232-244`）として存在するが、オーバーレイ配下の `IgnorePointer(ignoring: !overlayVisible)`（`player_screen.dart:104-112`）により、待機後は見えずクリックできない。デスクトップで映像面をクリックすると `_toggleOverlay`（`player_screen.dart:50-53`）がオーバーレイを再表示し、その後に戻るボタンをクリックできる。この再表示操作を知らない利用者には、戻る導線が無いように見える。
- **Manga**: manga home から `MangaViewerScreen` を開く（`app/lib/features/manga/presentation/manga_home_section.dart:61-64`）。コントロールは初期表示される（`manga_viewer_screen.dart:84-88`）が、画面クリックで `_toggleControls`（`manga_viewer_screen.dart:137-138`, `375-377`）を切り替える。`_controlsVisible` が false のとき AppBar（戻る導線を含む）は `null` になる（`manga_viewer_screen.dart:319-374`）うえ、左右のページ送りタップ領域も構築されない（`manga_viewer_screen.dart:424-446`）。この状態で画面中央をクリックすると表示復帰だけが起き、1 回ではページ送りされない。AppBar と操作領域は存在するが、デスクトップ上では状態を知らない利用者にとって発見しにくく、非表示中の端部クリックは効かない。

上記の再現結果を根拠に、以下の所見では「コントロールが無い」とは表現せず、存在するコントロールが表示条件／ヒットテスト条件によって発見不能または一時的に無効になる、と記録する。

### D3. 所見一覧（Findings）

以下は本監査で確認した所見。番号は後続 change 分割時の参照用。

**F1. 動画プレーヤー: 実装済みの「戻る」ボタンが自動非表示オーバーレイ内にあり、デスクトップで再発見が必要、かつキーボード代替経路が無い**

- `app/lib/features/video/presentation/player_screen.dart:26-53`: `_overlayVisible` は `initState` で `true` から始まり、`_autoHideAfter`（`player_screen.dart:29`, 3秒）後に自動で `false` になる（`_scheduleHide` / `player_screen.dart:43-48`）。
- 「戻る」ボタンは存在する。`Icons.arrow_back` と `Navigator.of(context).maybePop()` は `_TopBar`（`player_screen.dart:232-244`）に実装されている。ただし `_TopBar` は `_OverlayControls`（`player_screen.dart:186`）内にあり、オーバーレイの `IgnorePointer(ignoring: !overlayVisible, ...)`（`player_screen.dart:104-112`）の配下にあるため、再生開始 3 秒後に自動非表示になると、ボタンは見えずクリックもできない。上記 D2 のデスクトップ再現では、映像面クリックでオーバーレイを再表示した後に限り `maybePop` が利用できる。
- オーバーレイを再表示する手段は `GestureDetector(onTap: onSurfaceTap)`（`player_screen.dart:97-103`）による映像面タップのみ。キーボード（Esc 等）でオーバーレイ再表示や画面を閉じる代替経路は実装されていない（grep で `KeyboardListener`/`Shortcuts`/`LogicalKeyboardKey` 等のヒットなし）。
- `openspec/specs/local-video-playback/spec.md:27` は「Controls MUST appear when the user taps the video surface and SHALL auto-hide after 3 seconds of inactivity」と明記しており、3秒自動非表示自体は既存 spec で意図された挙動。ただし spec にはキーボードでの操作継続手段や「戻る」導線の常時可視性についての要求が無く、issue #50 の「戻れなくなる」報告の直接的な原因はこのギャップだと考えられる。
- 影響度: **trap（利用者を詰ませうる）**。マウスで映像面をクリックすればオーバーレイは戻るため完全なデッドエンドではないが、その再表示手段を知らないデスクトップ利用者には戻る導線が無いように見え、表示後 3 秒で再び隠れるため発見性が低い。

**F2. 漫画/コミックビューア: 実装済みの AppBar とページ送り領域がコントロール状態にゲートされ、非表示中はデスクトップ操作が効かない**

- `app/lib/features/manga/presentation/manga_viewer_screen.dart:84-88`: `_controlsVisible` は初期値 `true`。`_toggleControls`（`manga_viewer_screen.dart:137-138`）は本文全体の `GestureDetector(onTap: _toggleControls, ...)`（`manga_viewer_screen.dart:375-376`）で切り替わる。
- AppBar は実装済みで、`_controlsVisible ? AppBar(...) : null`（`manga_viewer_screen.dart:319-374`）によりコントロール表示時だけ構築される。AppBar のデフォルト leading（戻る導線）もこの条件に従う。ページ送り用の左右 60px 幅タップ領域も `if (_controlsVisible) ...`（`manga_viewer_screen.dart:424-446`）でゲートされ、非表示中は端部クリックがページ送りに到達しない。ページ番号表示（`manga_viewer_screen.dart:448-472`）も同条件で隠れる。
- D2 のデスクトップ再現では、コントロール非表示中の中央クリックは `_toggleControls` による表示復帰だけになり、1 回目のクリックでページは送られない（コントロール表示時は重なったタップ領域側が優先してヒットする）。動作自体が常に破綻しているのではなく、状態を示すヒントが無いため「操作コントロールが不明瞭・利用不能」に見える。
- キーボードでのページ送り（矢印キー/PageUp/PageDown）や Esc での終了経路も存在しない（grep 確認済み）。
- 影響度: **discoverability（操作は可能だが発見しにくい）**。

**F3. 全対象面共通: キーボード操作・macOS/Windows 固有分岐がなく、既存のクリック導線への依存が残る**

- `Platform.isMacOS` / `Platform.isWindows` の分岐が video/manga/book/audio/novel_kakuyomu/novel_narou のいずれにも存在しない（grep 確認）。
- `KeyboardListener` / `Shortcuts` / `LogicalKeyboardKey` / `MouseRegion` / `Actions`+`Intent` のいずれも対象 feature に存在しない（grep 確認、ヒットした2件は無関係）。
- マウス+キーボードが主入力であるデスクトップにおいて、既存のタップ/クリック導線だけに依存した UI は「押せることに気づけるか」で体験が決まる。F1/F2 はこの構造的欠落の具体的な現れであり、操作コントロール自体が存在しないという意味ではない。
- 影響度: **構造的所見（複数の後続修正に影響する前提条件）**。後続 change でキーボードショートカット方針を検討する際の起点とする。

**F4. 書籍(PDF/EPUB)リーダー・音声プレーヤー（フル/ミニ）・オンライン小説リーダーは「戻る」導線が常時可視**

- `app/lib/features/book/presentation/book_reader_screen.dart:88-110`: `Scaffold(appBar: AppBar(...))` は常設（`_controlsVisible` のような可視条件が無い）。Flutter の `AppBar` は `Navigator.canPop() == true` のとき自動で戻る矢印を出す（`automaticallyImplyLeading` 未設定＝デフォルト true）ため、戻る導線は常に見える。
- `app/lib/features/audio/presentation/player_screen.dart:20-24`: 同様に `Scaffold(appBar: AppBar(...))` が常設。`app/lib/features/audio/presentation/mini_player.dart` はホーム画面下部固定のミニプレイヤーで、タップでフルスクリーンへ遷移する構造（`mini_player.dart:71-75`）。
- `app/lib/features/novel_kakuyomu/presentation/reader_screen.dart:75-78`, `app/lib/features/novel_narou/presentation/reader_screen.dart`（同構造）も常設 AppBar。
- これら 4 面は F1/F2 のような「戻る導線が消える」問題を再現しなかった。ただし、いずれもキーボードでのページ送り（矢印キー/PageUp/PageDown）や Esc での終了はサポートしておらず、F3 の構造的所見は共通して当てはまる。
- 影響度: **低（既存の「戻る」導線に関しては良好）**。ただしキーボード操作の欠如という observation は記録する。

### D4. 本 change のスコープ判断: 実装修正を含めない

選択肢:
- (A) F1（動画）だけでも本 change で修正する。
- (B) 監査のみに留め、修正は全て後続 change に切り出す。**← 採用**

理由: milestone #1 の運用方針は「バッチを小さく保つ」ことを明示的に要求している。F1 の修正（戻る導線の常時可視化またはキーボード Esc 対応）は `local-video-playback` spec の「Controls... SHALL auto-hide after 3 seconds」という既存要求と衝突しうるため、spec 変更を伴う可能性が高く、修正方針の決定自体に検討が要る。F2 も同様にコントロール可視性ロジックの設計判断を要する。これらを本 change に混ぜると、コード監査という単純作業と、UI 修正という設計判断が同一 PR に混在し、レビュー・CI 検証（Flutter ローカル不可、CI 依存）の単位が大きくなる。監査を単独でクローズし、F1/F2/F3 のどれを・どの順で・どの粒度で修正するかは、この design.md の所見を根拠に別 GitHub Issue を切って着手する。

### D5. 既存の製品挙動 capability への spec delta は作成しない／監査自体を新規 capability として spec 化する

本 change はコードの挙動を一切変更しないため、`openspec/specs/` 配下の既存 capability（`local-video-playback`, `local-manga-zip-viewer`, `local-book-reader`, `local-audio-playback`, `kakuyomu-novel-reader-ui`, `narou-novel-reader-ui` 等）に対する MODIFIED spec delta は作成しない。F1/F2 を修正する後続 change で、必要な spec 変更（例: `local-video-playback` の「コントロール自動非表示」要求にキーボード代替経路の要求を追加する等）を個別に提案する。

一方で、この OpenSpec スキーマ（`spec-driven`）は「1 change につき最低 1 delta（ADDED/MODIFIED/REMOVED/RENAMED のいずれか、Scenario 必須）」を要求するため、delta ゼロの change は `openspec validate --all --strict` を通らない。既存の製品挙動 capability を無理に変更して「監査のみ」という前提を崩すのではなく、**監査という成果物自体**を新規 capability `media-viewer-flow-audit`（ADDED）として spec 化する（`specs/media-viewer-flow-audit/spec.md`）。この capability の要求は「所見が `file_path:line_number` 付きで追跡可能であること」「本 change がアプリケーションコードを変更しないこと」であり、既存の製品挙動仕様には一切踏み込まない。これにより、ツールの delta 要件を満たしつつ、監査と実装修正の分離という本 change の目的を保持する。

## Risks / Trade-offs

- **監査のみで実装が進まない体感**: issue #50 の報告者からは「まだ直っていない」と見える可能性がある → `design.md` の所見一覧と後続 Issue へのリンクを PR 説明に明記し、次の一手が明確であることを示す。
- **grep ベースの横断走査の見落とし**: `Platform.isMacOS`/`isWindows` 以外の分岐方法（例: `defaultTargetPlatform` 判定、build フレーバー分岐）が万一存在する場合は見落としうる → `defaultTargetPlatform` でも同様に grep 済み（ヒットなし、念のため tasks で明記し再確認する）。
- **CI のみで検証**: ローカル Flutter が無いため、`dart format` / `flutter analyze --fatal-infos` / `flutter test` は変更なし（コード変更が無いため実質的にスキップ）。`openspec validate --all --strict` と `git diff --check` のみローカルで実施する。

## Validation

```bash
openspec validate --all --strict
git diff --check
```

本 change はアプリケーションコードを変更しないため、`dart format` / `flutter analyze --fatal-infos` / `flutter test` の実行は不要（対象ファイルに差分が無い）。後続の修正 change ではこれらを GitHub Actions 上で確認する。

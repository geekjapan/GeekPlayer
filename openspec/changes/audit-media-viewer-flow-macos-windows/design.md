## Context

issue #50 は、macOS / Windows 実機で「動画再生開始後にホームへ戻る導線を見失う」「漫画/コミックビューアで操作コントロールが不明瞭・利用不能になる」という報告に基づく。issue #43 バッチ3/4 は novel 面の表示専用 artifact 除去に限定してクローズし、#50（本件）と #51（ホーム IA）を明示的に先送りにした。

本 change は実装修正を含まない監査単独バッチである。理由は milestone #1 の運用方針（"Keep each batch small because local Flutter is unavailable and CI is the checker"）に沿い、まず問題箇所をコードから具体的に特定し、修正の要否・優先度・スコープを事前に固定してから、小さい後続 change に分割するため。

対象コードは `app/lib/features/{video,manga,book,audio,novel_kakuyomu,novel_narou}/presentation/` 配下。`grep -rn "Platform.isMacOS\|Platform.isWindows"` を対象 feature 全体（`video/ audio/ manga/ book/ novel/ novel_kakuyomu/ novel_narou/`）に対して実行した結果ヒットなし。つまり macOS/Windows 固有の分岐処理はこれらの feature に一切存在しない。同様に `KeyboardListener|Focus(|Shortcuts(|LogicalKeyboardKey|onKeyEvent|RawKeyEvent|MouseRegion|Actions(|Intent` の grep でも、キーボード/マウス操作を明示的に扱うコードはヒットしなかった（`novel/data/novel_page_session.dart` と `novel_narou/presentation/search_screen.dart` のヒットは無関係な `// Intentionally swallowed.` コメントと `ScrollController.addListener` であり、対象外）。`pubspec.yaml` に `window_manager` / `bitsdojo_window` 等のデスクトップウィンドウ管理パッケージは存在せず、OS 標準のタイトルバー・最小化/最大化/閉じるボタンがそのまま使われている（独自オーバーレイによる被覆は無い）。

## Goals / Non-Goals

**Goals:**

- 対象 6 面（動画・漫画・書籍・音声フル/ミニ・カクヨム/なろうリーダー）の「開く→操作→戻る/閉じる→ホーム」フローをコードレベルで検証し、macOS/Windows で問題になりうる箇所を `file_path:line_number` 付きで特定する。
- 各所見に、issue #50 の報告内容との対応関係、影響度（trap/discoverability/minor）、対応要否の初期判断を付与する。
- 本 change のスコープ内で直す/直さないの線引きを明確にする。

**Non-Goals:**

- 特定した問題の実装修正（後続 change）。
- ホーム画面 IA 改善（issue #51）。
- テストコードの追加（後続 change のタスクとする）。

## Decisions

### D1. 監査方法論: grep による横断走査 + 対象ファイルの全文読解

まず `Platform.isMacOS/isWindows` と キーボード/マウス関連 API（`KeyboardListener`, `Shortcuts`, `LogicalKeyboardKey`, `MouseRegion`, `Actions`/`Intent` 等）の grep を対象 feature ディレクトリ全体に対して行い、macOS/Windows 固有分岐・デスクトップ入力処理の有無を横断的に確認した（結果: 両方ともヒットなし＝分岐も専用入力処理も存在しない）。次に対象 6 ファイルを全文読解し、「戻る」導線の可視性条件、コントロールの表示/非表示ロジック、ナビゲーション用タップ領域の可視性条件を突き合わせた。

理由: macOS/Windows は原則同一の Flutter デスクトップ入力経路（マウス/キーボード）を共有し、Android 由来のタッチ操作前提の UI がそのまま流用されている場合に問題が生じやすい。grep でその欠落を横断的に裏付けたうえで、個別ファイルの読解で具体的な行を特定する二段構えとした。

### D2. 所見一覧（Findings）

以下は本監査で確認した所見。番号は後続 change 分割時の参照用。

**F1. 動画プレーヤー: 「戻る」ボタンが自動非表示オーバーレイの中にしかない、かつキーボード代替経路が無い**

- `app/lib/features/video/presentation/player_screen.dart:26-53`: `_overlayVisible` は `initState` で `true` から始まり、`_autoHideAfter`（`player_screen.dart:29`, 3秒）後に自動で `false` になる（`_scheduleHide` / `player_screen.dart:43-48`）。
- 「戻る」ボタン（`Icons.arrow_back`, `player_screen.dart:240-244`）は `_TopBar` 内にあり、`_TopBar` は `_OverlayControls`（`player_screen.dart:109-113`, `IgnorePointer(ignoring: !overlayVisible, ...)`）配下にのみ存在する。したがって再生開始 3 秒後、オーバーレイが自動的に消えると同時に「戻る」ボタンも操作不能になる。
- オーバーレイを再表示する手段は `GestureDetector(onTap: onSurfaceTap)`（`player_screen.dart:97-103`）による映像面タップのみ。キーボード（Esc 等）でオーバーレイ再表示や画面を閉じる代替経路は存在しない（grep で `KeyboardListener`/`Shortcuts`/`LogicalKeyboardKey` 等のヒットなし）。
- `openspec/specs/local-video-playback/spec.md:27` は「Controls MUST appear when the user taps the video surface and SHALL auto-hide after 3 seconds of inactivity」と明記しており、3秒自動非表示自体は既存 spec で意図された挙動。ただし spec にはキーボードでの操作継続手段や「戻る」導線の常時可視性についての要求が無く、issue #50 の「戻れなくなる」報告の直接的な原因はこのギャップだと考えられる。
- 影響度: **trap（利用者を詰ませうる）**。マウスで映像面をクリックすればオーバーレイは戻るため完全なデッドエンドではないが、タップ後 3 秒でまた消えるため「戻る操作の発見性」が低い。

**F2. 漫画/コミックビューア: コントロール非表示時にページ送りタップ領域も同時に消える**

- `app/lib/features/manga/presentation/manga_viewer_screen.dart:84-88`: `_controlsVisible` は `initState` で `true`。`_toggleControls`（`manga_viewer_screen.dart:137-138`）は本文全体の `GestureDetector(onTap: _toggleControls, ...)`（`manga_viewer_screen.dart:375-376`）で切り替わる。
- ページ送り用のタップ領域（左右 60px 幅、`Positioned(... width: 60 ...)`）は `if (_controlsVisible) ...`（`manga_viewer_screen.dart:425-446`）でガードされており、コントロール非表示時は存在しない。同様に AppBar（`manga_viewer_screen.dart:324-374`、暗黙の戻るボタンを含む）と ページ番号表示（`manga_viewer_screen.dart:448-472`）も同条件で消える。
- コントロール非表示中に画面をタップすると `_toggleControls` によりまず表示が復帰するのみで、1回目のタップではページは送られない（`GestureDetector` の重なり順により、コントロール可視時はタップ領域側が優先してヒットする）。動作自体は破綻していないが、「コントロール非表示中に何が起きるか」を示すヒントが無く、issue #50 の「操作コントロールが不明瞭・利用不能に見える」という報告と一致する体験になっている。
- キーボードでのページ送り（矢印キー/PageUp/PageDown）や Esc での終了経路も存在しない（grep 確認済み）。
- 影響度: **discoverability（操作は可能だが発見しにくい）**。

**F3. 全対象面共通: キーボード操作・macOS/Windows 固有分岐が皆無**

- `Platform.isMacOS` / `Platform.isWindows` の分岐が video/manga/book/audio/novel_kakuyomu/novel_narou のいずれにも存在しない（grep 確認）。
- `KeyboardListener` / `Shortcuts` / `LogicalKeyboardKey` / `MouseRegion` / `Actions`+`Intent` のいずれも対象 feature に存在しない（grep 確認、ヒットした2件は無関係）。
- マウス+キーボードが主入力であるデスクトップにおいて、タップ/クリックのみに依存した UI は「押せることに気づけるか」で体験が決まる。F1/F2 はこの構造的欠落の具体的な現れ。
- 影響度: **構造的所見（複数の後続修正に影響する前提条件）**。後続 change でキーボードショートカット方針を検討する際の起点とする。

**F4. 書籍(PDF/EPUB)リーダー・音声プレーヤー（フル/ミニ）・オンライン小説リーダーは「戻る」導線が常時可視**

- `app/lib/features/book/presentation/book_reader_screen.dart:88-110`: `Scaffold(appBar: AppBar(...))` は常設（`_controlsVisible` のような可視条件が無い）。Flutter の `AppBar` は `Navigator.canPop() == true` のとき自動で戻る矢印を出す（`automaticallyImplyLeading` 未設定＝デフォルト true）ため、戻る導線は常に見える。
- `app/lib/features/audio/presentation/player_screen.dart:20-24`: 同様に `Scaffold(appBar: AppBar(...))` が常設。`app/lib/features/audio/presentation/mini_player.dart` はホーム画面下部固定のミニプレイヤーで、タップでフルスクリーンへ遷移する構造（`mini_player.dart:71-75`）。
- `app/lib/features/novel_kakuyomu/presentation/reader_screen.dart:75-78`, `app/lib/features/novel_narou/presentation/reader_screen.dart`（同構造）も常設 AppBar。
- これら 4 面は F1/F2 のような「戻る導線が消える」問題を再現しなかった。ただし、いずれもキーボードでのページ送り（矢印キー/PageUp/PageDown）や Esc での終了はサポートしておらず、F3 の構造的所見は共通して当てはまる。
- 影響度: **低（既存の「戻る」導線に関しては良好）**。ただしキーボード操作の欠如という observation は記録する。

### D3. 本 change のスコープ判断: 実装修正を含めない

選択肢:
- (A) F1（動画）だけでも本 change で修正する。
- (B) 監査のみに留め、修正は全て後続 change に切り出す。**← 採用**

理由: milestone #1 の運用方針は「バッチを小さく保つ」ことを明示的に要求している。F1 の修正（戻る導線の常時可視化またはキーボード Esc 対応）は `local-video-playback` spec の「Controls... SHALL auto-hide after 3 seconds」という既存要求と衝突しうるため、spec 変更を伴う可能性が高く、修正方針の決定自体に検討が要る。F2 も同様にコントロール可視性ロジックの設計判断を要する。これらを本 change に混ぜると、コード監査という単純作業と、UI 修正という設計判断が同一 PR に混在し、レビュー・CI 検証（Flutter ローカル不可、CI 依存）の単位が大きくなる。監査を単独でクローズし、F1/F2/F3 のどれを・どの順で・どの粒度で修正するかは、この design.md の所見を根拠に別 GitHub Issue を切って着手する。

### D4. 既存の製品挙動 capability への spec delta は作成しない／監査自体を新規 capability として spec 化する

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

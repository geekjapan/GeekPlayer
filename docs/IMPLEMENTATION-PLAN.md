# GeekPlayer — Wave-based Parallel Implementation Plan

> **対象読者**: これから `/opsx:apply` で実装に入る開発者 / エージェント
> **前提読了**: [HANDOFF.md](HANDOFF.md) → このファイル → 着手する change の `proposal.md` + `design.md`
> 最終更新: 2026-05-27 (Wave 0 完了直後)

## 0. このドキュメントの読み方

このドキュメントは「v0.1 の 8 つの change をどの順序・どの並列度で実装するか」を **実行可能なレベル** まで降ろしたものです。各 wave に:

- 実行コマンド
- サブエージェント prompt テンプレート
- exit criteria（完了判定）
- 想定 conflict と解決手順
- ロールバック手順

が含まれます。HANDOFF.md は高レベル、本ドキュメントは executable です。

### 関連ドキュメントマップ

| 質問 | 読むべきファイル |
|---|---|
| プロジェクト全体像は? | [HANDOFF.md](HANDOFF.md) |
| コーディング規約は? | [CONVENTIONS.md](CONVENTIONS.md) |
| 過去の設計判断と理由は? | [docs/adr/](adr/) (0001-0004) |
| まだ未解決の設計論点は? | [GRILL-REPORT.md](GRILL-REPORT.md) `## Open Questions Index` |
| ドメイン用語は? | [CONTEXT.md](../CONTEXT.md) |
| マイルストーンとロードマップは? | [roadmap.md](roadmap.md) |
| 着手する change の詳細は? | `openspec/changes/<change>/proposal.md` + `design.md` |
| 何を実装すれば良い?（タスク粒度） | `openspec/changes/<change>/tasks.md` |

## 1. 全体俯瞰

### 1.1 依存グラフ

```
main
 └─ Wave 1 (sequential, foundation)
     └─ add-local-video-playback
          ├─ Wave 2 (3 並列)
          │   ├─ add-local-audio-playback        (MediaSession audio variant)
          │   ├─ add-online-novel-library        (drift v2 + Novel infra + PageSession variant)
          │   └─ add-error-ux-infra              (独立、core/errors/)
          │
          └─ Wave 3 (3 並列、Wave 2 全 merge 後)
              ├─ add-narou-novel-reader           (novel-library 依存)
              ├─ add-kakuyomu-novel-reader        (novel-library 依存)
              └─ add-app-settings                 (drift v3、novel-library に乗る)
                   │
                   └─ Wave 4 (sequential)
                       └─ add-about-and-licenses  (app-settings の AppBar から呼ばれる)
```

### 1.2 想定スケジュール

| Wave | 並列度 | 想定時間 (1 change) | 累計 | 直列換算 |
|---|---|---|---|---|
| 1 (video) | sequential | 2-3 h | 2-3 h | 2-3 h |
| 2 (audio + novel-library + error-ux) | 3 並列 | 2-3 h each | 4-6 h | 6-9 h |
| 3 (narou + kakuyomu + app-settings) | 3 並列 | 2-3 h each | 6-9 h | 6-9 h |
| 4 (about) | sequential | 1 h | 7-10 h | 1 h |
| **合計** | | | **約 7-10 h** | **約 15-22 h** |

並列化で **約 2 倍の高速化** が見込めます。

### 1.3 着手判断フロー

```
本ドキュメントを読む
       ↓
[現在の wave] を確認 (git log + openspec list)
       ↓
着手 change の Pre-flight checklist を実行 (このドキュメント §5)
       ↓
sub-agent prompt template (§4) で /opsx:apply
       ↓
Exit criteria 確認 (§6)
       ↓
Merge → 次 wave へ
```

## 2. Wave 1 — `add-local-video-playback` (foundation)

### 2.1 なぜ sequential か

このwaveは **後続 7 change の土台** を構築します:
- `MediaSession` sealed hierarchy の起点
- drift schema v1
- `HomeScreen` + section レジストリ ([ADR-0004](adr/0004-home-screen-section-registry.md))
- `recent_items` テーブル（後続が `kind='audio'` `kind='novel'` で利用）
- macOS file-picker entitlements / Android permissions の最初の差分

これらが揃わない限り wave 2 の並列 worktree はビルドできません。

### 2.2 Pre-flight checklist

```bash
# repo root で実行
cd /home/geekjapan/dev/GeekPlayer
git status                                    # clean
git log --oneline -3                          # 最新は wave 0 commit
openspec status --change add-local-video-playback  # 4/4 complete
flutter analyze                                # No issues
flutter test                                   # All passed (現状は scaffold だけ)
gh auth status                                 # logged in as geekjapan
```

### 2.3 実行手順

```bash
# main 上で直接実行（worktree 不要）
cd /home/geekjapan/dev/GeekPlayer

# 1. apply 開始
/opsx:apply add-local-video-playback

# /opsx:apply は openspec/changes/add-local-video-playback/tasks.md を読み、
# セクション 1 から順にチェックボックスを消化する。
# 各 task 完了で - [ ] → - [x] に更新される。

# 2. 全 task 完了後の検証
cd app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed .

# 3. 実機検証 (任意、時間があれば)
flutter run -d macos   # / windows / <android-device>
# ファイル選択 → 動画再生 → シーク → 速度変更 → 字幕 → 戻る → 再開
# 「最近開いた」リストにエントリ確認

# 4. commit (conventional commits)
cd ..
git add app docs openspec/changes/add-local-video-playback
git commit -m "feat(video): implement local video playback foundation

Implements add-local-video-playback change. See
openspec/changes/add-local-video-playback/{proposal,design}.md
for context. All 41 tasks completed.

- MediaSession sealed abstraction with VideoSession variant
- drift schema v1: playback_positions / recent_items
- HomeScreen + Section レジストリ foundation (ADR-0004)
- file_picker integration
- macOS sandbox entitlements + Android media permissions

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"

# 5. archive
/opsx:archive add-local-video-playback

# 6. push
git push origin main
```

### 2.4 Exit criteria

このwaveは以下が **全部** green でなければ次に進まない:

- [ ] `openspec/changes/add-local-video-playback/tasks.md` の全 41 task が `- [x]`
- [ ] `flutter analyze` が `No issues found`
- [ ] `flutter test` が `All tests passed`
- [ ] `dart format --set-exit-if-changed .` が exit 0
- [ ] macOS / Windows / Android **最低 2 OS** で実機 / エミュレータ起動成功
- [ ] `HomeScreen` が `VideoHomeSection` を表示
- [ ] `openspec/specs/local-video-playback/spec.md` と `openspec/specs/media-session/spec.md` が `/opsx:archive` で生成済み
- [ ] GitHub Actions の CI run が green

これが全部揃ったら **Wave 2 解禁**。

### 2.5 想定されるトラブル

| 症状 | 原因 | 対応 |
|---|---|---|
| `build_runner` が `.g.dart` を出さない | drift codegen の依存漏れ | `flutter pub get` → `dart run build_runner build --delete-conflicting-outputs` |
| `media_kit` ロード失敗 (Linux/Win) | libmpv が見つからない | `media_kit_libs_video` パッケージが pubspec に入っているか確認 |
| `MediaSession` の sealed switch が exhaustive 警告 | `part of 'media_session.dart';` 漏れ | [ADR-0004](adr/0004-home-screen-section-registry.md) ではなく [CONVENTIONS.md §10](CONVENTIONS.md) を再確認 |
| ResumePoint が次回開いた時に効かない | URI normalize の不一致 | `Uri.file(path).toString()` を全箇所で使う |

## 3. Wave 2 — audio + novel-library + error-ux (3 並列)

### 3.1 なぜこの 3 つを並列化するか

- **audio**: `MediaSession` sealed の `AudioSession` variant 追加。novel-library とは触るファイルが違う（`core/media/audio_session.dart`）
- **novel-library**: drift schema v1 → v2、`Novel*` テーブル / `core/novel/` 配下に集中
- **error-ux**: `core/errors/` のみ。他 2 つと完全に独立

共通の編集源は:
- `app/pubspec.yaml` (3 つとも deps を足す) → CONVENTIONS.md §2 の冪等性で対処
- `media_session.dart` (audio と novel-library の両方が `part 'xxx.dart';` を追加) → 3-way merge で順序維持
- `app/lib/main.dart` (audio が `AudioService.init` を入れる、novel-library が `ConsentDialog` を入れる) → 末尾追記で衝突回避

### 3.2 Pre-flight

```bash
cd /home/geekjapan/dev/GeekPlayer
git checkout main
git pull --rebase origin main
git log --oneline -3   # Wave 1 commit が最新

# Wave 1 の完了を確認
ls openspec/specs/local-video-playback/spec.md openspec/specs/media-session/spec.md
# どちらも存在すれば Wave 1 archive 済み

# worktree 用ディレクトリ作成
git worktree add ../GeekPlayer-audio          -b feature/audio          main
git worktree add ../GeekPlayer-novel-library  -b feature/novel-library  main
git worktree add ../GeekPlayer-error-ux       -b feature/error-ux       main

# 各 worktree で Flutter SDK を確認
for d in ../GeekPlayer-audio ../GeekPlayer-novel-library ../GeekPlayer-error-ux; do
  (cd "$d/app" && flutter pub get && flutter analyze 2>&1 | tail -2)
done
```

### 3.3 サブエージェント spawn

[Sub-agent prompt template (§4)](#4-サブエージェント-prompt-template) を使い、Agent tool で 3 並列起動。各エージェントには:

- `isolation: "worktree"` を **使わない**（既に手動で worktree を作っているため）
- 代わりに `cwd` を各 worktree path に明示
- `model: "opus"` 推奨（複雑な実装は effort=max が活きる）

3 つを **1 メッセージ内で並列 Agent 呼び出し** すること（独立だから）。

### 3.4 Wave 2 merge 戦略

順序: **error-ux → audio → novel-library**（依存少→多）

```bash
cd /home/geekjapan/dev/GeekPlayer
git checkout main

# 1. error-ux を merge (一番独立)
git merge --no-ff feature/error-ux -m "Merge feature/error-ux into main"
git push origin main

# 2. audio を rebase してから merge
cd ../GeekPlayer-audio
git fetch origin
git rebase origin/main
# conflict があれば手動解決 (pubspec.yaml / main.dart が typical)
cd ../GeekPlayer
git merge --no-ff feature/audio -m "Merge feature/audio into main"
git push origin main

# 3. novel-library を rebase してから merge
cd ../GeekPlayer-novel-library
git fetch origin
git rebase origin/main
# conflict: pubspec.yaml / main.dart / media_session.dart (part 行)
cd ../GeekPlayer
git merge --no-ff feature/novel-library -m "Merge feature/novel-library into main"
git push origin main

# 4. worktree クリーンアップ
git worktree remove ../GeekPlayer-audio
git worktree remove ../GeekPlayer-novel-library
git worktree remove ../GeekPlayer-error-ux
git branch -d feature/audio feature/novel-library feature/error-ux
```

### 3.5 Exit criteria (Wave 2 全体)

- [ ] 3 change すべての全 task が `- [x]`
- [ ] main 上で `flutter analyze` / `flutter test` が green
- [ ] CI run が green
- [ ] `openspec/specs/` に `local-audio-playback` / `online-novel-library` / `site-consent` / `responsible-fetching` / `error-domain` / `error-ux-widgets` / `retry-strategy` の spec が存在
- [ ] **drift schema が v2** になっている（`database.dart` 確認）
- [ ] HomeScreen に Video / Audio / Novel の 3 セクションが表示される（MiniPlayer も）

## 4. Wave 3 — narou + kakuyomu + app-settings (3 並列)

### 4.1 並列化の根拠

- **narou**: `features/novel_narou/` に集中、`NovelRepository` の実装
- **kakuyomu**: `features/novel_kakuyomu/` に集中、`NovelRepository` の実装
- **app-settings**: `features/settings/` + drift schema v2 → v3 bump

3 つとも `core/novel/` や `core/storage/` の interface は wave 2 で確定済み。共通変更源は:
- `pubspec.yaml` （冪等で OK）
- `HomeScreen` → セクションレジストリで衝突なし
- `main.dart` → AppBar アクション登録のみ（settings/about）

### 4.2 Pre-flight

```bash
cd /home/geekjapan/dev/GeekPlayer
git checkout main && git pull --rebase origin main

# Wave 2 の完了を確認
for c in local-audio-playback online-novel-library site-consent responsible-fetching error-domain; do
  ls "openspec/specs/$c/spec.md" || echo "MISSING: $c"
done

# worktree
git worktree add ../GeekPlayer-narou          -b feature/narou          main
git worktree add ../GeekPlayer-kakuyomu       -b feature/kakuyomu       main
git worktree add ../GeekPlayer-app-settings   -b feature/app-settings   main
```

### 4.3 Sub-agent spawn

§4 の template で 3 並列。

### 4.4 Merge 戦略

順序: **app-settings → narou → kakuyomu**

理由:
- app-settings は drift v3 へ bump するため最初に確定したい
- narou が `app_settings` テーブルの `novel.reader.*` key を読むため app-settings 先行
- kakuyomu も同じ理由で narou と並列だが、HTML パーサで novel-library の責任あるフェッチ規範が確定している必要があり、kakuyomu はリトライ周りで narou と一部 import を共有する可能性 — 最後に持ってきて conflict 1 ファイルだけにする

### 4.5 Exit criteria

- [ ] 3 change すべての task 完了
- [ ] drift schema **v3**
- [ ] HomeScreen に Novel セクション内で「なろう / ノクターン系 / カクヨム」のサブナビゲーションが動く
- [ ] 初回起動で同意ダイアログが出て、サイト別にチェックボックスを ON/OFF できる
- [ ] 設定画面（gear アイコンから）でテーマ・キャッシュ管理・サイト同意の再設定ができる
- [ ] CI green

## 5. Wave 4 — `add-about-and-licenses` (sequential)

### 5.1 なぜ sequential

並列度 1。単独で完結。`add-app-settings` の About リンクから到達するため、Wave 3 後。

### 5.2 実行

```bash
cd /home/geekjapan/dev/GeekPlayer
git worktree add ../GeekPlayer-about -b feature/about main
# or main 上で直接 apply (single change なので worktree 任意)
```

### 5.3 Exit criteria

- [ ] About 画面でアプリ名 / バージョン / ビルド SHA が表示
- [ ] OSS Licenses 画面が `flutter_oss_licenses` から生成された一覧 + 手書きの libmpv (LGPL) セクションを表示
- [ ] `Apache-2.0` NOTICE 表示
- [ ] CI green

## 6. サブエージェント prompt template

各 wave で `/opsx:apply` を sub-agent に任せる場合、以下のテンプレを使う:

```
あなたは GeekPlayer リポジトリで OpenSpec change を実装するエージェントです。

## ゴール

worktree `<WORKTREE_PATH>` (= `<BRANCH_NAME>` ブランチ) で
`/opsx:apply <CHANGE_NAME>` を実行し、全 task を完了させてください。

## 前提

- 既に repo root から `git worktree add` で別ディレクトリが切られています
- Flutter は `$HOME/flutter/bin` (PATH 設定済み)
- 必要なら `$HOME/.local/bin/unzip` の Python shim がある

## 必読

1. `<WORKTREE_PATH>/docs/HANDOFF.md`
2. `<WORKTREE_PATH>/docs/IMPLEMENTATION-PLAN.md` (このドキュメント)
3. `<WORKTREE_PATH>/docs/CONVENTIONS.md` ★ 並列実装規約
4. `<WORKTREE_PATH>/docs/adr/0004-home-screen-section-registry.md` (HomeScreen 編集禁止、レジストリ使用)
5. `<WORKTREE_PATH>/openspec/changes/<CHANGE_NAME>/proposal.md`
6. `<WORKTREE_PATH>/openspec/changes/<CHANGE_NAME>/design.md`
7. `<WORKTREE_PATH>/openspec/changes/<CHANGE_NAME>/tasks.md`
8. 該当 capability の `specs/*/spec.md` (Requirement と Scenario)

## 守るべき規約

- [docs/CONVENTIONS.md](CONVENTIONS.md) を厳守
  - `pubspec.yaml` は `flutter pub add` で冪等
  - `AndroidManifest.xml` は append-only / 既存維持
  - macOS は Debug + Release の両 entitlements を編集
  - drift schema bump は単調増加
  - Riverpod v3 codegen (`@Riverpod` + `riverpod_generator`)
  - sealed class 拡張は `part of 'media_session.dart';`
- [ADR-0004](adr/0004-home-screen-section-registry.md) に従い、`HomeScreen` 本体は編集しない。`homeSectionsProvider` / `homeAppBarActionsProvider` にサブプロバイダで登録
- 他 change のファイル (`openspec/changes/<other>/`) は触らない

## 手順

1. CWD を `<WORKTREE_PATH>` に切り替え
2. `git status` で clean を確認、`git pull --rebase origin main` で最新化
3. `cd app && flutter pub get`、analyze / test が green か baseline 取得
4. `openspec/changes/<CHANGE_NAME>/tasks.md` の Section 1 から順に task を実装
5. 各 task 完了で `- [ ]` → `- [x]` に更新
6. 各セクション完了後に `flutter analyze` / `flutter test` を走らせて regression を防ぐ
7. drift codegen が必要なら `dart run build_runner build --delete-conflicting-outputs`
8. 全 task 完了後:
   - `flutter analyze` / `flutter test` / `dart format --set-exit-if-changed .` がすべて green
   - `git add` で変更を stage
   - `git commit -m "feat(<scope>): ..."` で conventional commit
9. 報告: 完了 task 数 / 残 task 数 / 失敗したコマンド / 重要な設計判断 を 10 行以内で

## 制約

- ユーザーへの質問はしない。判断は design.md と CONVENTIONS.md に基づく
- HomeScreen と main.dart の編集は最小限（registry サブプロバイダ追加と main.dart 末尾の `runApp` 拡張のみ）
- 他 change の wave で merge 順序が後の change のファイルは決して触らない
- `/opsx:archive` は **やらない**（archive は merge 後に main で行う）
- commit のみで OK。push は親エージェントが merge 時に行う
- 失敗・不明な点があれば commit せず報告する

## 完了条件 ([docs/IMPLEMENTATION-PLAN.md §6](IMPLEMENTATION-PLAN.md) の Exit criteria に対応)

- 全 task が `- [x]`
- `flutter analyze` clean
- `flutter test` all passed
- `dart format` clean
- commit 完了（push しない）
```

`<WORKTREE_PATH>`, `<BRANCH_NAME>`, `<CHANGE_NAME>` を埋めて Agent tool で起動。

## 7. Worktree ライフサイクル

### 7.1 作成

```bash
git worktree add <PATH> -b <BRANCH_NAME> main
```

`<PATH>` は repo の **兄弟ディレクトリ** が推奨（`../GeekPlayer-<change>`）。subdirectory にすると `app/build` などが衝突する。

### 7.2 確認

```bash
git worktree list
# /home/geekjapan/dev/GeekPlayer           556ba83 [main]
# /home/geekjapan/dev/GeekPlayer-audio     XXXXXXX [feature/audio]
# ...
```

### 7.3 各 worktree の初期化

```bash
cd <PATH>/app
flutter pub get
# .dart_tool, build/ は worktree ごとに独立 — main の cache は使えない
```

### 7.4 削除

```bash
# repo root から
git worktree remove <PATH>
git branch -d <BRANCH_NAME>   # merge 済みなら
```

merge していないブランチは `-D` で force delete。

### 7.5 落とし穴

- 同じブランチ名を 2 worktree から checkout は **不可**
- `flutter clean` を 1 worktree でやっても他 worktree の build cache は消えない
- `pubspec.lock` は各 worktree で別だが、commit すべきは main 1 つ — 各 worktree の commit に `pubspec.lock` を含めるのは OK（merge で 3-way 解決される）

## 8. Conflict 解決プレイブック

### 8.1 想定される conflict (頻度順)

| ファイル | 原因 | 解決方針 |
|---|---|---|
| `app/pubspec.yaml` | 複数 change が dep を足す | 両方の deps を採用、バージョン制約は新しい方 / より広い方を選ぶ |
| `app/pubspec.lock` | 上記の resolution 結果 | 削除して `flutter pub get` で再生成 |
| `app/lib/main.dart` | 末尾追記の重なり | 両方の追記を順序維持で採用 |
| `app/lib/core/media/media_session.dart` | `part 'xxx.dart';` 行の追加 | 全 `part` 行を採用、辞書順に並べる |
| `app/android/app/src/main/AndroidManifest.xml` | `<uses-permission>` の追加 | CONVENTIONS.md §3 に従い両方採用、重複は片方削除 |
| `app/macos/Runner/*.entitlements` | key/value の追加 | XML を merge、両方の key を保持 |
| `docs/HANDOFF.md` `docs/CONVENTIONS.md` | 両 wave で更新があった | 通常起きない（doc は main で先行更新） |
| `*.g.dart` (codegen) | drift / riverpod 生成 | 削除して再生成 |

### 8.2 標準解決手順

```bash
# 1. conflict 表示
git status

# 2. 自動解決可能なものから対応
git checkout --theirs <PATH>       # main 側を採用
git checkout --ours   <PATH>       # branch 側を採用
# どちらでもない手動 merge は emacs / VSCode で

# 3. codegen 系は再生成
cd app
rm -f lib/**/*.g.dart
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 4. 検証
flutter analyze
flutter test

# 5. rebase 続行
git add <resolved files>
git rebase --continue
```

### 8.3 重大な conflict が起きたら

- **`MediaSession` sealed の構造的変更** が複数 change で起きた場合: 一旦 rebase abort し、設計レベルで議論。新 GRILL-REPORT round を回す。
- **drift schema version の衝突** (両 change が同じバージョンを bump): 後発側を rebase で次のバージョンに変更、design.md / tasks.md も更新。
- **テストが落ちる原因が不明**: `git bisect` でどの commit が原因か特定。

## 9. CI 戦略

### 9.1 各 feature branch での CI

`.github/workflows/ci.yaml` は現状 `push: branches: [main]` と `pull_request: branches: [main]` のみ。**feature branch への push では走らない** ため、PR を出すと CI が走る。

### 9.2 推奨フロー

```bash
# feature branch を push
git push -u origin feature/audio

# PR を立てる (CI が走る)
gh pr create --base main --head feature/audio \
  --title "feat(audio): local audio playback" \
  --body "Implements add-local-audio-playback. See proposal/design/tasks under openspec/changes/."

# CI green を待つ
gh pr checks --watch

# merge (squash 推奨、本ドキュメントの例は --no-ff だが小規模なら squash)
gh pr merge --merge   # or --squash
```

### 9.3 並列 PR が複数 ある時

- 各 PR は独立に CI を走らせる
- merge 順序を守れば再 CI は不要
- 後発 PR は merge 前に `git rebase origin/main` → push し直し → 再 CI

## 10. ロールバック手順

### 10.1 wave 中の task 失敗

- 該当 change の commit を `git reset --hard HEAD~1` で戻す
- `tasks.md` の `- [x]` を `- [ ]` に手で戻す
- 設計に問題がある場合は GRILL-REPORT に新 Q を追加して止める

### 10.2 wave merge 後の重大な regression

- `git revert -m 1 <merge commit sha>` で revert
- main は revert commit が乗った状態に
- 該当 change を新ブランチで再実装

### 10.3 wave 1 失敗

最も重要。Wave 1 が失敗すると全 wave が止まる。

- `git revert` で main を Wave 0 直後に戻す
- video の design.md を見直し、必要なら proposal を改訂
- GRILL-REPORT に Q を追加して再起動

## 11. リスクレジスター

| ID | リスク | 影響 | 緩和策 |
|---|---|---|---|
| R-1 | Wave 1 の HomeScreen registry 設計が後続で不足 | 全 wave 停止 | ADR-0004 のレジストリ拡張余地 (`HomeSection` interface) を最初に固める。`order` 値の予約も拡張可能に |
| R-2 | drift schema migration test 漏れ | 本番リリース後に DB 壊れる | 各 change の tasks に必ず in-memory migration test を入れる ([CONVENTIONS.md §5](CONVENTIONS.md)) |
| R-3 | `media_kit` Android 不安定 | 動画再生が一部端末で動かない | `add-local-video-playback` Risks D に記載済み。SW フォールバック許可で対応 |
| R-4 | カクヨム HTML 構造変更 | カクヨム読書機能停止 | `add-kakuyomu-novel-reader` の `kakuyomu-resilience` capability で外部ブラウザフォールバック |
| R-5 | サブエージェントの worktree 隔離が機能不全 (新 OS bug 等) | 並列実行できない | sequential fallback に切り替え。HANDOFF と本ドキュメントの順序を守れば直列でも実装可能 |
| R-6 | `flutter_oss_licenses` の libmpv 取りこぼし | LGPL compliance 不全 | `add-about-and-licenses` の手書き LGPL セクションで補完。`tasks` に視認テスト含む |
| R-7 | iOS / iPadOS v0.2 で LGPL 配布が不可 | iOS リリース不可 | v0.2 計画開始時に ADR を起こす (Q-RISK-001 参照) |

## 12. ポスト実装 (Wave 4 完了後)

### 12.1 すべての wave 完了後の最終確認

```bash
cd /home/geekjapan/dev/GeekPlayer
git log --oneline -10
openspec list --json | jq '.changes[] | {name, completedTasks, totalTasks}'

# active changes が全部 archive 済み
ls openspec/changes/         # archive ディレクトリのみ
ls openspec/specs/           # 全 capability の spec が並ぶ

# UI smoke test
cd app
flutter run -d macos
# → 動画 / 音楽 / 小説（なろう / カクヨム）を 1 件ずつ動作確認
# → 設定 → About まで遷移できる
```

### 12.2 v0.1.0 リリース手順 (案)

1. `app/pubspec.yaml` の `version: 1.0.0+1` を `version: 0.1.0+1` に修正（最終版で）
2. `git tag v0.1.0`
3. `git push origin v0.1.0`
4. `gh release create v0.1.0 --generate-notes`
5. （v0.2 で）各 OS のバイナリビルドを Release assets に上げる

### 12.3 GRILL-REPORT の次 round

実装中に新発見された設計論点を [GRILL-REPORT.md](GRILL-REPORT.md) に追記し、必要なら新 ADR を起こす。

未解決のまま残る MEDIUM/LOW (17 件) は v0.2 で再評価。

## 13. このドキュメントのメンテナンス

- 各 wave 完了時に「Wave N 完了」のセクションを追加
- 想定スケジュールから乖離したら追記して原因を残す
- 新たな conflict パターンを発見したら §8.1 に追加
- 新 ADR が出たら §0 のドキュメントマップを更新

## Context

GeekPlayer は OSS（Apache-2.0）として GitHub Releases で配布される
([`openspec/config.yaml:17`](../../config.yaml))。動画再生エンジンに採用した
libmpv は LGPL-2.1+ であり、ADR-0002 で動的リンク利用を選択した
([`docs/adr/0002-hybrid-media-engine.md:39`](../../../docs/adr/0002-hybrid-media-engine.md))。
LGPL の主要要件は (1) 改変版ライブラリへの差し替え権利の保証、(2) 上流ソースの
入手手段の明示、(3) ライセンス本文同梱、(4) 著作権表示の保持 の 4 点で、動的
リンク + OSS / GitHub Releases 配布であれば (1) は自動的に満たされるが、(2)〜(4)
は **書面通知（アプリ内 UI でも可）** で明示する必要がある。

現状の通知は [`THIRD_PARTY_NOTICES.md:1`](../../../THIRD_PARTY_NOTICES.md) と
[`LICENSE:189`](../../../LICENSE) にしか存在せず、アプリ実行中のユーザーが目視
できない。本 change は About 画面と OSS Licenses 画面を実装し、libmpv 専用の
LGPL 通知セクションを `oss-license-notices` capability の一部として書面化する。

依存パッケージのライセンス本文を手で管理するのは現実的でなく、`flutter_oss_licenses`
を `dev_dependencies` に入れ、ビルド時に `pubspec.yaml` を走査して
`lib/oss_licenses.dart` を生成する方針を採る。生成物は VCS にコミットして、
CI でも再現可能にする。

## Goals / Non-Goals

**Goals:**

- ユーザーが About 画面を開いたとき、アプリ名 / バージョン / ビルド番号 /
  コミット SHA / GitHub・Roadmap・ライセンスへのリンクが一目で確認できる
- OSS Licenses 画面で、依存パッケージ一覧から個別のライセンス本文まで辿れる
- libmpv に関する LGPL 通知が独立セクションとして常時可視であり、上流ソース
  URL と差し替え手順が記載されている
- Apache-2.0 NOTICE が表示される（LICENSE の `Copyright 2026 GeekPlayer
  Contributors` 行）
- バージョン取得は `package_info_plus`、コミット SHA は `--dart-define=GIT_SHA=...`
  経由でビルド時に注入される
- 3 画面（About / Licenses 一覧 / Licenses 詳細）すべてが ja-first

**Non-Goals:**

- 設定画面そのものの実装（`add-app-settings` の責務）
- アプリ更新確認 / 自動アップデート（v0.2 `add-auto-update`）
- プライバシーポリシー画面
- 英語ローカライズ（v0.2）
- ライセンス本文の差分検出・通知
- ライセンス互換性チェック（GPL 系の混入検知など）

## Decisions

### D1. 依存ライセンス収集に `flutter_oss_licenses` を採用

`flutter_oss_licenses` は `dev_dependencies` で導入し、`dart run flutter_oss_licenses:generate -o lib/oss_licenses.dart` で
Dart コードを生成する。生成物は VCS にコミットし、CI ではビルド前に
`--source` モードで再生成して差分が出ないことを検証する。

**代替案: Flutter 標準の `LicenseRegistry` + 自前画面**
→ `LicenseRegistry` は pubspec の動的依存を完全には捕捉できず、特に
`media_kit_libs_video` のネイティブ依存（libmpv 本体・FFmpeg 等）が漏れる。
`flutter_oss_licenses` はパッケージ単位で確実に拾える。**ただし libmpv 自体は
Dart パッケージではないため、後述の D3 で手動セクションを別途設ける。**

**代替案: `oss_licenses` パッケージ（無印）**
→ メンテナンス頻度が低く、Null Safety 対応も遅い。`flutter_oss_licenses` を採用。

### D2. バージョン情報は `package_info_plus`、SHA は `--dart-define`

`package_info_plus` で `appName` / `version` / `buildNumber` を取得する。
コミット SHA は実行時には取得できないため、ビルド時の Dart コンパイル引数
`--dart-define=GIT_SHA=$(git rev-parse --short HEAD)` で渡す。

`app/lib/features/about/data/build_info.dart` で:

```dart
const String kGitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'unknown');
```

として読み出し、`'unknown'` の場合は About 画面で "(dev build)" と表示する。

**代替案: ビルド時に Dart ファイルを生成 (`build.dart` で `git rev-parse` 実行)**
→ Flutter は標準のビルドフックが弱く、CI / ローカル / IDE で挙動が割れる。
`--dart-define` は引数 1 つで完結し IDE でも launch.json で渡せる。

### D3. libmpv の LGPL 通知は **手動セクション** として独立

`flutter_oss_licenses` が自動生成するのは Dart パッケージのライセンスのみで、
libmpv 自体（ネイティブバイナリ）は対象外。`lgpl-compliance` capability に
基づき、`app/lib/features/about/presentation/lgpl_notice_section.dart` を
ハードコードで実装し、以下を必ず含める:

- libmpv が LGPL-2.1+ で配布されていること
- 本アプリは `media_kit` 経由で **動的リンク** していること
- 上流ソース URL: `https://github.com/mpv-player/mpv`
- 利用者が libmpv 部分のみを差し替えて再構築する権利を持つこと
- OS 別の差し替え手順概要（macOS: `.app/Contents/Frameworks/Mpv.framework`、
  Windows: 実行ファイル隣の `mpv-2.dll` 等、Android: APK 内 `lib/<abi>/libmpv.so`）

セクションはライセンス一覧画面の最上部に固定表示する（一覧と一緒にスクロール
される領域ではなく、画面遷移すれば消える Sliver header ではない常時可視位置）。

**代替案: 自動生成リストの 1 項目として埋め込む**
→ LGPL 通知は法務的に求められる粒度が他の MIT ライセンス通知より大きく、
混ぜると視認性が落ちる。「目立つ独立セクション」で運用する方が安全。

### D4. Apache-2.0 NOTICE 表示

`LICENSE:189` の `Copyright 2026 GeekPlayer Contributors` 行を About 画面に
表示する。Apache-2.0 第 4 条 (d) は NOTICE ファイルを派生物に同梱することを
要求するため、リポジトリのトップにある `LICENSE` 本文の `APPENDIX` 部分を
ライセンス画面でも全文閲覧できるようにする（`assets/legal/LICENSE` として
バンドルする）。

### D5. 外部リンクは `url_launcher`

GitHub リポジトリ / Roadmap / ライセンス各 URL は `url_launcher` の
`launchUrl(uri, mode: LaunchMode.externalApplication)` で OS のブラウザに渡す。
アプリ内 WebView は導入しない（依存追加コスト > 利得）。

### D6. ナビゲーション — 暫定的にホームに導線、後で設定画面に移設

`add-app-settings` がまだ存在しないため、`HomeScreen` の AppBar に
情報アイコン（"About" 入口）を 1 つだけ置く。`add-app-settings` 着地後は
このアイコンを削除し、設定画面の「アプリ情報」項目から到達するルートに
切り替える。Navigator 2.0 / GoRouter は本 change のスコープ外で、`Navigator.push`
の手動遷移で十分。

### D7. 画面構成

```
AboutScreen
├── ヘッダー (アプリ名 / バージョン / ビルド番号 / コミット SHA)
├── Apache-2.0 NOTICE 行
├── リンクボタン (GitHub / Roadmap / Full License)
└── "OSS ライセンス" ボタン → LicenseListScreen

LicenseListScreen
├── LGPL Notice Section (libmpv 専用、最上部固定)
├── Apache-2.0 NOTICE Section (GeekPlayer 本体)
└── 依存パッケージ一覧 (ListView, flutter_oss_licenses の生成データ)
     └── タップ → LicenseDetailScreen

LicenseDetailScreen
└── 単一パッケージの名前 / バージョン / ライセンス本文 (SelectableText)
```

### D8. テスト戦略

- **ユニット**: `build_info.dart` の `kGitSha` フォールバック挙動を
  `app/test/features/about/build_info_test.dart` で検証
- **ウィジェット**: `AboutScreen` がモック `PackageInfo` を流し込んだ状態で
  アプリ名 / バージョン / ビルド番号 / SHA を表示することを `pumpWidget` で
  確認。`unknown` 時に "(dev build)" にフォールバックすること
- **ウィジェット**: `LgplNoticeSection` が `mpv-player/mpv` URL を含むこと、
  `LicenseListScreen` が LGPL セクションを最上部に表示すること
- **生成データ整合性**: `flutter_oss_licenses` の生成出力 (`lib/oss_licenses.dart`)
  が `pubspec.yaml` と同期しているかを CI で検証する task（任意）

## Risks / Trade-offs

- **`flutter_oss_licenses` の依存パッケージ漏れ** → 生成スクリプトの
  カバレッジを CI に組み込み、`media_kit` / `just_audio` / `drift` / `dio` /
  `riverpod` 等の主要依存が出力に含まれることをスナップショットテストで検証。
- **libmpv バイナリ差し替え手順の説明が現実的か** → 手順は「概要」レベル
  に留め、詳細は `THIRD_PARTY_NOTICES.md` への外部リンクと、上流の
  `media_kit_libs_video` リポジトリの README へのリンクで補完する。アプリ内
  全文を出すと OS / バージョン依存が高く陳腐化しやすい。
- **`GIT_SHA` を `--dart-define` で渡し忘れた場合の表示** → `'unknown'`
  フォールバック + UI 上で "(dev build)" 表記。CI のリリースワークフローでは
  忘れるとリリース版にも "(dev build)" が出るため、リリース手順書と
  GitHub Actions の `dart-define` 指定を必須として明文化する task を入れる。
- **`url_launcher` の Android インテント設定漏れ** →
  `AndroidManifest.xml` に `<queries>` で `https` スキーム宣言が必要
  （Android 11+）。task に明示。
- **生成物 (`lib/oss_licenses.dart`) を VCS に入れる是非** → 入れる。ビルド
  時生成は IDE / CI / ローカルで足並みが揃いにくく、`flutter analyze` が
  生成前後で違う結果を返すと開発体験が悪い。
- **Apache-2.0 NOTICE の運用** → コントリビューターが増えたら NOTICE 行の
  著作権表示を更新する責務が発生する。CONTRIBUTING に明文化する（本 change
  外）。
- **ライセンス本文の言語** → ja-first のアプリだが、ライセンス本文は原文
  英語のまま表示する（翻訳すると法的拘束力に疑義が出る）。説明文のみ ja。

## Migration Plan

- 既存ユーザーなし → マイグレーション無し
- ロールバック: 本 change をリバートすると About 画面と依存
  (`package_info_plus` / `flutter_oss_licenses` / `url_launcher`) と
  `lib/oss_licenses.dart` の生成物が消える。`HomeScreen` の About 入口
  アイコンも削除される。データ層への影響なし

## Open Questions

- **Q-D1**: ライセンス一覧画面の検索フィルタは v0.1 で必要か?
  → 不要。依存数が 20〜30 程度の見込みでスクロールで十分。v0.2 で再評価。
- **Q-D2**: ライセンス画面に「Copy to clipboard」ボタンを置くか?
  → `SelectableText` で十分。明示的なボタンは v0.2 以降。
- **Q-D3**: libmpv 差し替え手順を `docs/lgpl-relink.md` として外出しし、
  アプリからは要約 + リンクにするか?
  → tasks 段階で判断。第一案は外出し（陳腐化リスク軽減）。
- **Q-D4**: `flutter_oss_licenses` 生成物のフォーマット（JSON 出力 vs Dart
  コード出力）どちらを採るか?
  → Dart コード出力（`-o lib/oss_licenses.dart`）。型安全で IDE 補完が効く。

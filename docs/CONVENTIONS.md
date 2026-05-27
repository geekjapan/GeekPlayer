# GeekPlayer — 開発規約

並列 Wave 実装で merge conflict を最小化するための共通規約。各 change の `tasks.md`
からこのドキュメントを参照してください。

最終更新: 2026-05-27（Wave 0 整備）

## 1. ホーム画面のセクション追加

`HomeScreen` を直接編集してはいけません。
**[ADR-0004](adr/0004-home-screen-section-registry.md)** に従い、Riverpod の
`homeSectionsProvider` にサブプロバイダを追加する方式で行います。

- 自身の `*HomeSection`（or `*AppBarAction`）を `app/lib/features/<feature>/presentation/` に実装
- 自身のサブプロバイダを Riverpod codegen で公開（例: `@Riverpod(keepAlive: true) List<HomeSection> videoHomeSections(...)`)
- `app/lib/features/library/home_section_registry.dart` の `homeSectionsProvider` に **`...ref.watch(<feature>HomeSectionsProvider)` 1 行** を追加

`order` 値の予約は ADR-0004 参照。

## 2. `pubspec.yaml` への依存追加

`flutter pub add <pkg>` は **冪等** に扱います。

- 既に `pubspec.yaml` に同名パッケージが存在する場合は `flutter pub add` を実行してもエラーにならず、バージョン制約だけが更新される（または変わらない）
- 各 change の tasks.md には「冪等: 既に存在すれば skip」と明記
- バージョン pin したい場合は `flutter pub add <pkg>:^x.y.z` を指定（複数 change で違うバージョンを要求すると最後の add が勝つので、design.md で根拠を残すこと）

## 3. Android `AndroidManifest.xml`

複数 change が `AndroidManifest.xml` に追記する想定です。**append-only / 既存維持** が原則:

- 既存の `<uses-permission>` / `<service>` / `<receiver>` / `<queries>` 行を削除・変更しない
- 自分の追加が既に存在するかを `grep` などで確認し、存在すれば skip（冪等）
- 各 tasks.md の AndroidManifest 編集 task に「既存セクションを保持」を明記
- `<application>` タグ内へ追加する `<service>` や `<receiver>` は **末尾**に追加（順序依存はないが、3-way merge で衝突を減らすため）

## 4. macOS / iOS の Entitlements と Info.plist

macOS は **`Debug.entitlements` と `Release.entitlements` の両方** を編集する必要があります（よく忘れる）。

- 各 tasks.md の macOS 編集 task に「Debug + Release の両方の `.entitlements`」を明示
- `Info.plist` への追加（`LSBackgroundModes` 等）も同様に append-only
- iOS は v0.2 対応のため v0.1 では `app/ios/Runner/*.entitlements` を編集しない（ただし `flutter create` が生成する空 entitlements は維持）

## 5. drift スキーマのバージョニング

drift schema version の単調増加を守ること:

| Version | 導入 change |
|---|---|
| v1 | `add-local-video-playback`（`playback_positions`, `recent_items`） |
| v2 | `add-online-novel-library`（`novel_works`, `novel_episodes`, `novel_bookmarks`, `site_consents`） |
| v3 | `add-app-settings`（`app_settings`） |

各 change は **自分が bump するバージョンの `onUpgrade` migration を必ず書く**こと
（pre-release でも CI で in-memory DB の migration テストを走らせるため、
schema version 0 → N の jump を許容しない）。

新規 change が drift テーブルを追加する場合は、最新の version + 1 を確保し、
このドキュメントの表を更新する責務がある。

## 6. State management (Riverpod)

**Riverpod v3 + codegen** で書く。

- `@Riverpod(keepAlive: true)` 等のアノテーションを使用
- `*.g.dart` の生成は `dart run build_runner build --delete-conflicting-outputs`
- 旧 `AutoDisposeNotifierProvider<...>` 直書きは新規コードで使わない（既存スキャフォールド側は適宜置き換え）

## 7. テスト

- ユニットテスト: `app/test/<feature>/...` に配置
- ウィジェットテスト: `flutter_test` の `pumpWidget` ベース
- drift マイグレーションテスト: in-memory DB で v(N) → v(N+1) を検証、既存データの保持を確認
- 統合テスト: `app/integration_test/` に配置（CI では skip タグ、ローカル / リリース前に手動実行）

## 8. ファイル命名

| 種類 | 規約 | 例 |
|---|---|---|
| ファイル名 | snake_case | `video_session.dart` |
| クラス名 | PascalCase | `VideoSession` |
| プロバイダ | camelCase + `Provider` | `videoSessionProvider` |
| drift table | PascalCase (drift convention) | `PlaybackPositions` |
| drift DAO | PascalCase + `Dao` | `PlaybackPositionsDao` |
| feature ディレクトリ | snake_case | `features/novel_narou/` |

## 9. Conventional Commits

```
feat: add video playback resume support
fix: rate limiter not respecting Retry-After
docs: add ADR-0004 home screen registry
refactor: extract NarouEpisodeFetcher from NarouNovelRepository
test: add drift v1->v2 migration test
chore: bump just_audio to 0.10.6
```

スコープ (`feat(narou): ...`) は任意。

## 10. ファイル間 sealed class 結合

[Q-CROSS-011](GRILL-REPORT.md) で決定: `MediaSession` のように複数ファイルに分かれる
sealed hierarchy は `app/lib/core/media/media_session.dart` を起点に
**`part of 'media_session.dart';`** で結合する。Dart 3 の sealed class 同一ライブラリ
制約のため、別ディレクトリ / 別 library に置くことはできない。

例:
- `app/lib/core/media/media_session.dart` — `library media_session;` + `part 'video_session.dart'; part 'audio_session.dart'; part 'page_session.dart';`
- 各 variant ファイルは `part of 'media_session.dart';` を冒頭に

各 variant を追加する change はこの規約に従い、`media_session.dart` の `part` 宣言を
1 行追加する（accumulate）。

# 0004 — HomeScreen をセクションレジストリ方式で構成する

**Status**: accepted (2026-05-27)

## Context

[GRILL-REPORT Q-CROSS-013](../GRILL-REPORT.md) で指摘されたとおり、v0.1 だけでも
**6 つの change が `HomeScreen` を編集**しようとしている:

- `add-local-video-playback`: `VideoHomeSection`
- `add-local-audio-playback`: `AudioHomeSection`, `MiniPlayer`
- `add-online-novel-library`: `NovelHomeSection`
- `add-narou-novel-reader`: `NarouHomeSection` (NovelHomeSection の中のタブ群)
- `add-kakuyomu-novel-reader`: `KakuyomuSection`
- `add-app-settings`: AppBar に gear アイコン
- `add-about-and-licenses`: AppBar に info アイコン

これらを Wave 並列で実装する場合、`home_screen.dart` 1 ファイルでの merge conflict
が必至。各 change は他の change の存在を知らず、自身のセクションを `Column` の
何番目に挿すかを設計時に決められない。

## Decision

**`HomeScreen` を「セクション集約コンテナ」として書き、各 change はセクション
ウィジェットを Riverpod のレジストリプロバイダに登録するだけにする**。

### 物理レイアウト

```
app/lib/features/library/
├── home_screen.dart                  # 集約コンテナ。各セクションを描画するだけ
├── home_section.dart                 # interface (abstract)
└── home_section_registry.dart        # Riverpod provider 群
```

### 抽象

```dart
abstract class HomeSection {
  String get id;                  // 例: 'video', 'audio', 'novel.narou'
  int get order;                  // セクション表示順 (小さいほど上)
  Widget build(BuildContext context, WidgetRef ref);
}

@Riverpod(keepAlive: true)
List<HomeSection> homeSections(HomeSectionsRef ref) {
  // 各 feature が ref.read() できる別 provider にセクションを登録し、
  // ここで集約して order 順にソートして返す
  return [
    ...ref.watch(videoHomeSectionsProvider),
    ...ref.watch(audioHomeSectionsProvider),
    ...ref.watch(novelHomeSectionsProvider),
  ];
}

@Riverpod(keepAlive: true)
List<HomeAppBarAction> homeAppBarActions(HomeAppBarActionsRef ref) {
  // settings (gear) と about (info) アイコンも同様
  return [
    ...ref.watch(settingsAppBarActionsProvider),
    ...ref.watch(aboutAppBarActionsProvider),
  ];
}
```

`HomeScreen` の実装は:

```dart
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(homeSectionsProvider);
    final actions = ref.watch(homeAppBarActionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeekPlayer'),
        actions: actions.map((a) => a.build(context, ref)).toList(),
      ),
      body: ListView(
        children: sections.map((s) => s.build(context, ref)).toList(),
      ),
    );
  }
}
```

### 各 change の責務

- 自身の機能用 `*HomeSection`（または `*AppBarAction`）クラスを実装
- 自身用のサブプロバイダ（例: `videoHomeSectionsProvider`）を Riverpod で公開
- **`HomeScreen` のコードと `homeSectionsProvider` のコードは触らない**

最初に `HomeScreen` と `home_section_registry.dart` を書くのは
`add-local-video-playback` の責務（foundation）。後続の change はサブプロバイダを
追加するだけ。

### `order` 値の規約

予約済み:

| Order | Owner |
|---|---|
| 100 | `MiniPlayer` (sticky top, audio change が提供) |
| 200 | `VideoHomeSection` |
| 300 | `AudioHomeSection` |
| 400 | `NovelHomeSection` (全 novel サイトを含む) |
| 500 | (v0.2) `BookHomeSection` |
| 600 | (v0.2) `MangaHomeSection` |

数字は 100 刻みで余裕を持たせ、後から間に差し込めるようにする。

## Considered Options

- **(a) `HomeScreen` を編集して直接 Column 配置（採用しない）**: 並列実装で merge conflict 必至。
- **(b) Composite Widget で `children: [VideoHomeSection(), AudioHomeSection(), ...]`（採用しない）**: `HomeScreen` 自体は触らずに済むが、各 change が `HomeScreen` の children list を編集する必要があり結局 conflict が起きる。
- **(c) Riverpod レジストリ provider（採用）**: 各 change は自身の provider だけ書く。集約 provider は spread (`...ref.watch(...)`) で複数 provider から集めるため、provider 追加でも `homeSectionsProvider` の中身は変わらない（既存サブプロバイダの参照だけ追加）。
- **(d) Service Locator + `injectAll<HomeSection>()`（採用しない）**: Flutter エコシステムでは Riverpod が圧倒的なため、別の DI を持ち込む必要なし。

## Consequences

- 並列 Wave 2/3 で `home_screen.dart` 競合が起きない（変更は各機能の `*HomeSection` ファイルと、`homeSectionsProvider` の **サブプロバイダ参照 1 行**のみ）
- 集約プロバイダの `ref.watch(...)` 行の追加は競合源になりうる — ただし 1 ファイルの 1 セクションの末尾追記のみで、3-way merge が問題なく解決できる
- セクション順は `order` で制御する規約のため、設計時に「どこに表示されるか」を意識した数値を選ぶ責務が各 change にある
- AppBar アクションも同じ抽象に乗せるため、settings / about 等の右上アイコン追加も conflict free
- Riverpod v3 codegen (`@Riverpod`) を使う前提（[GRILL-REPORT Q-CROSS-014](../GRILL-REPORT.md) で決定済み）

## Related

- GRILL-REPORT Q-CROSS-013
- `add-local-video-playback` change（HomeScreen と registry の初期実装を担う）
- 全 6 後続 change（サブプロバイダ追加のみで対応）

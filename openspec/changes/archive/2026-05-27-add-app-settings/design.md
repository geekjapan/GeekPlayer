## Context

v0.1 のコア機能 change（`add-local-video-playback` / `add-local-audio-playback`
/ `add-online-novel-library` / `add-narou-novel-reader` / `add-kakuyomu-novel-reader`）
は個別に Riverpod state を抱えていて、ユーザー設定（再生速度の既定値、字幕デフォルト、
小説ビューアの文字サイズ等）はメモリ上にしか存在しない。再起動で揮発するうえ、
同意管理 / R18 リセット / キャッシュ管理など「設定画面に集約すべき」 UI も今は
各 feature 内に散らばっている。

本 change は次を満たす中央集権的な設定基盤を導入する:

- 単一の `Settings` 画面に全カテゴリを集約（Material 3 ListView + Section）
- 全設定値を 1 つの drift テーブル `app_settings(key, value)` に永続化
- 値の読み書きは Riverpod の `AppSettingsNotifier` に統一し、観測者が即時更新を
  受け取る
- 各 feature は `AppSettings` の特定フィールドを `select` して必要な値のみ購読
  （リビルド粒度を抑える）

採用済みの前提（CONTEXT.md / 既存 change から）:

- Riverpod v2 / drift 単一 DB / Material 3 / ja-first
- drift schema は本 change が **v3**（v1=video の核, v2=novel-library 系,
  v3=app-settings）。v1 → v3 のスキップアップグレードも `onUpgrade` で覆う
- 同意 UI は `add-online-novel-library/specs/site-consent/spec.md` の Requirement
  「Settings screen permanent disclosure」「Consent revocation and re-grant from
  settings」を実装するための受け皿。本 change は同 Requirement の振る舞いを
  変更せず、UI 配置（`SettingsScreen > オンラインサービス` セクション）のみ提供する

## Goals / Non-Goals

**Goals:**

- ユーザーがホーム画面の歯車から `SettingsScreen` を開き、10 セクションの設定を
  閲覧 / 変更でき、変更は即時に永続化される
- 表示テーマ・小説ビューアの見た目・再生速度の既定値などが、アプリ再起動を跨いで
  保持される
- `AppSettings` を購読する feature が変更を即座に反映する（再生中の動画の速度や、
  小説ビューア表示中のフォントサイズなど、観測可能な状態）
- `app_settings` テーブルがスキーマ v3 で問題なく追加され、既存ユーザーの v1 / v2
  DB から `onUpgrade` で破壊なくマイグレーションされる
- 設定値の型安全な codec が一貫しており、不正値が DB に混入しても
  `AppSettings.defaults()` にフォールバックする

**Non-Goals:**

- About 画面の本体 UI（バージョン文字列 / ライセンス本文）→ `add-about-and-licenses`
- 同意ダイアログの初回表示・ポリシーバージョン管理 → `add-online-novel-library`
  の `site-consent` capability
- R18 年齢確認ダイアログの提示ロジック → `add-narou-novel-reader` の `r18-age-gate`
- 自動アップデート / 言語切替 → v0.2
- 設定値のインポート / エクスポート / クラウド同期 → v1.x 以降
- 設定 UI の英語化（ja-first を維持。intl 経由の ARB 切り出しは v0.2）

## Decisions

### D1. ストレージは EAV 形式の単一テーブル `app_settings(key TEXT PK, value TEXT)`

設定の追加・削除が頻繁で、項目数も v0.2 以降に増える。各値の型はアプリ層で
`SettingCodec<T>` が責任を持ち、DB には常に `TEXT` で保存する:

```dart
class AppSettings {
  const AppSettings({
    required this.themeMode,           // 'light' | 'dark' | 'system'
    required this.defaultPlaybackSpeed, // double
    required this.subtitlesByDefault,   // bool
    required this.audioBackgroundPlayback, // bool
    required this.audioNotificationPersistent, // bool
    required this.novelWritingMode,     // 'vertical' | 'horizontal'
    required this.novelFontSizeSp,      // double
    required this.novelLineHeight,      // double
    required this.novelFontFamily,      // 'noto-serif-jp' 等
    required this.novelBackgroundLight, // ARGB hex
    required this.novelBackgroundDark,  // ARGB hex
    required this.recentItemsCap,       // 10 | 25 | 50 | 100
    required this.novelCacheCapMb,      // int? null=無制限
  });
  factory AppSettings.defaults() => ...;
}
```

**代替案: テーブルを項目ごとに分割（Schema-on-write）**
→ マイグレーション頻度が増え、項目追加のたびに schema バージョンが上がる。EAV
の方が「設定の本質的に動的な性質」と整合する。

**代替案: `shared_preferences` / `flutter_secure_storage`**
→ DB を単一にする方針（CONTEXT.md / ADR）と矛盾する。トランザクション境界も
そろわない。

### D2. `AppSettingsNotifier` は読み書きの単一ゲート、`select` でリビルド粒度を絞る

```dart
@Riverpod(keepAlive: true)
class AppSettingsNotifier extends _$AppSettingsNotifier {
  @override
  Future<AppSettings> build() async {
    final rows = await ref.read(appSettingsRepositoryProvider).readAll();
    return AppSettings.fromRows(rows);
  }

  Future<void> update(AppSettings Function(AppSettings) f) async {
    final current = await future;
    final next = f(current);
    await ref.read(appSettingsRepositoryProvider).writeDiff(current, next);
    state = AsyncData(next);
  }
}
```

各 feature は `ref.watch(appSettingsNotifierProvider.select((s) => s.value?.defaultPlaybackSpeed))`
の形で値を購読する。

**代替案: 設定項目ごとに個別 Notifier**
→ 数が増えて配線が複雑化、トランザクション境界が崩れる。

### D3. drift schema v3、`onUpgrade` で v1 → v3 / v2 → v3 を覆う

`database.dart` の `MigrationStrategy.onUpgrade` で以下を実行:

```
if (from < 2) await m.create... // add-online-novel-library 担当
if (from < 3) await m.createTable(appSettings);
```

`from` 連鎖は **本 change ではテーブル作成のみ**で済む（既存テーブルへの破壊的
変更なし）。v1 / v2 がまだ実装前の段階では `from < 3` の分岐だけ書ければよく、
他 change との衝突を避けるため `onUpgrade` のスケルトンを **本 change で v3
分岐を「追加」する形**にする。v2 の実装が後に来ても merge 衝突は最小限。

**代替案: drift の `MigrationStepWithVersion`（drift 2.18+）**
→ より宣言的だが、v1 → v3 の skip-migration をテストする方が運用上重要なので、
従来式の `from < N` 分岐に留める。

### D4. UI 構造: Material 3 `ListView` + `SettingsSection` ウィジェット

```dart
ListView(
  children: const [
    DisplaySection(),
    PlaybackSection(),
    VideoSection(),
    AudioSection(),
    NovelSection(),
    LibrarySection(),
    CacheSection(),
    OnlineServicesSection(),
    R18Section(),
    AboutSection(),
  ],
);
```

各 `SettingsSection` は `Material 3` の `ListTile` を縦に並べた `Card` で、
ヘッダ（セクション名）と本体（行群）から構成。サブ画面が必要な項目（例: 小説の
背景色ピッカー）は `Navigator.push` で別 Route。

**代替案: タブ式 / 階層ドリルダウン**
→ 設定数が現状で十分一画面に収まる。スクロール 1 つで通せる方が ja UI の慣習に
合う。

### D5. 値変更はオプティミスティック、書き込みは debounce 250ms

連続スライダー（文字サイズ / 行間）の変更で SQLite を毎フレーム叩かないよう、
`AppSettingsNotifier.update` は `state` を即時更新しつつ、DB への書き込みは
key 単位で 250ms debounce する。アプリ終了時は `dispose` で flush。

**代替案: 即時書き込み**
→ スライダー操作で 60 回 / 秒の write が走る。

### D6. 同意取消時の本文キャッシュ削除フロー

「オンラインサービス」セクションでサイトの同意を OFF にすると、`SiteConsentRepository`
（`add-online-novel-library` 提供）の `revoke()` を呼ぶ前に確認ダイアログを出す:

> 「このサイトの本文キャッシュ（XX MB）も削除しますか?」 [削除する] [残す]

「削除する」を選んだ場合のみ、本 change 内の `CacheRepository.deleteBySite(site)`
を呼ぶ。`SiteConsentRepository` の振る舞い自体は変更しない（同 capability の
Requirement 「Consent revocation and re-grant from settings」が定める通り、
revoke してもキャッシュは消さないのがデフォルト）。

### D7. 「再生中の値変更」のリアルタイム反映ポリシー

| 設定 | 再生中の変更反映 |
|---|---|
| 動画字幕デフォルト | 既に開いている動画には適用しない（次回起動から） |
| デフォルト再生速度 | 同上 |
| 音楽バックグラウンド再生 | 即時反映（`audio_service` の設定 API を呼び直す） |
| 音楽通知の継続表示 | 即時反映 |
| 小説文字サイズ / 行間 / フォント / 背景色 | 即時反映（リーダー画面が watch している） |
| テーマ（light/dark/system） | 即時反映（`MaterialApp.themeMode` を watch） |
| "最近開いた" 上限 | 次回ホーム画面表示時に prune を実行 |

各セクションのヘルプテキストにこのポリシーを ja 文言で 1 行ずつ書く。

### D8. キャッシュサイズの計測コスト

`SELECT SUM(LENGTH(body_html)) FROM novel_episodes` で取得する。1 万話で
~50ms 程度を想定し、画面オープン時に 1 回だけ計算し、`AsyncValue` で表示。
サイズ計算中は `LinearProgressIndicator` を表示。

**代替案: 集計値をテーブルに持つ**
→ 削除 / 追加のたびにメンテが必要でバグの温床になる。SUM(LENGTH) で十分。

### D9. キャッシュ上限の運用

`novelCacheCapMb == null` → 無制限（デフォルト）。値があり現在のキャッシュサイズが
超過している場合、設定画面で **赤いバナー**を表示し、「古い順に削除」ボタンを
提示する。**自動的に削除しない**（ユーザーの能動操作を尊重、ADR-0001 の運用方針
に合わせる）。

### D10. テスト戦略

- ユニット: `SettingCodec<T>` の encode/decode（bool / int / double / null / enum）
- ユニット: `AppSettings.fromRows` で不正値・欠損値が defaults にフォールバック
- drift: `NativeDatabase.memory()` で v1 → v3 / v2 → v3 マイグレーションを検証
- ウィジェット: `SettingsScreen` の各セクションがレンダリングされる
- ウィジェット: スライダー操作で 250ms debounce 後に repository.write が呼ばれる
- 統合: テーマを system → dark に変更すると `MaterialApp.themeMode` が変わる

## Risks / Trade-offs

- **マイグレーション順序の依存**:
  v1=video / v2=novel-library / v3=app-settings の順序前提が他 change の実装と
  ずれた場合、`onUpgrade` の分岐が壊れる → 本 change の design.md と
  `database.dart` のコメントで順序を明示し、各 change がこの順序に従う
- **設定値変更時のリアルタイム反映の難所（再生中）**:
  動画の速度・字幕は再生中の差し替えで media_kit の挙動が不安定になりうる →
  D7 の表のとおり「次回起動から」に倒すか、`media_kit` の API が冪等なものだけ
  即時反映、それ以外は次回起動から
- **キャッシュサイズの正確な計測コスト**:
  小説キャッシュが 100k 話超の極端なケースで SUM(LENGTH) が遅くなる →
  D8 の通り `AsyncValue` で表示し、UI を block しない。1 秒超えたら背景 isolate
  で計算する fallback を入れる
- **EAV 設計の型安全性低下**:
  `value TEXT` に何でも入る → `SettingCodec` で型情報を集中管理。`AppSettings`
  値オブジェクトを介さない直接アクセスは禁止し、`AppSettingsRepository` 内に
  封じ込める
- **drift `onUpgrade` の skip-migration**:
  v1 → v3 のスキップを CI でカバーしないと本番でだけ壊れる → tasks に v1 → v3
  / v2 → v3 のテストケースを明示
- **小説ビューアの背景色設定とテーマ整合性**:
  明暗テーマと独立に背景色を持つと、テーマ切替時に視認性が悪化する組合せが発生
  → 明暗それぞれに別キーで持ち、テーマ切替で自動切替

## Migration Plan

- ファーストリリースなので既存ユーザーなし。drift schema v3 を初回 install で
  作成
- 本 change 単体を revert する場合、`AppSettingsNotifier` を購読する feature は
  `AppSettings.defaults()` 相当のハードコード値で動く設計にしておく（feature 側に
  fallback の責務）
- 万一 v3 マイグレーションで失敗した場合、`app_settings` テーブルが無い前提で
  defaults を返す（DAO 層で `CatchError`）

## Open Questions

- **Q-D1**: アクセントカラー UI を v0.1 で出すか? → 出さない。テーマシステムが
  v0.2 で拡張されるため、UI placeholder（disabled trailing arrow + "v0.2 で対応"
  バッジ）にする
- **Q-D2**: フォント選択肢の初期セット? → `noto-serif-jp` / `noto-sans-jp` の 2
  択で開始。バンドル方法は別途検討（pubspec の `flutter.fonts` で固定 2 種）
- **Q-D3**: 履歴クリアと "最近開いた" 上限変更の関係? → 上限を 100 → 25 に下げた
  だけでは過去エントリを消さず、次回ホーム画面で表示時に prune する（破壊操作の
  明示的化）
- **Q-D4**: 設定値のテレメトリ送信は? → OSS / no-telemetry の方針（README）に
  従い、送信しない

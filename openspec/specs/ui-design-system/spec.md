# ui-design-system Specification

## Purpose

Defines GeekPlayer's shared UI design-system foundation: a single brand seed and a centralized `buildAppTheme(Brightness)` builder (Material 3, light + dark) with app-wide component themes, plus shared design tokens (spacing / radius / breakpoint / size) that feature screens build on instead of ad-hoc styling.
## Requirements
### Requirement: 集中テーマビルダーと単一ブランド seed

アプリは単一のブランド seed から light/dark 双方の `ThemeData` を生成する集中テーマビルダー `ThemeData buildAppTheme(Brightness)` を `app/lib/core/theme/app_theme.dart` に持たなければならない (MUST)。seed は `const Color kSeedColor`（teal `0xFF109A78`）とし、`ColorScheme.fromSeed(seedColor: kSeedColor, brightness: ...)` と `useMaterial3: true` を用いなければならない (MUST)。`main.dart` の `MaterialApp` は `theme` / `darkTheme` をこのビルダーから取得し、インラインの `ThemeData` リテラルを残してはならない (MUST NOT)。ビルダーは少なくとも floating な SnackBar を含むアプリ共通の component theme を定義しなければならない (MUST)。

#### Scenario: 両 brightness が seed から生成される

- **WHEN** `buildAppTheme(Brightness.light)` と `buildAppTheme(Brightness.dark)` を呼ぶ
- **THEN** いずれも `useMaterial3 == true` で、それぞれ対応する `brightness` の `colorScheme` を持ち、その `colorScheme` は `kSeedColor` から導出されている

#### Scenario: SnackBar は floating

- **WHEN** いずれかの brightness のテーマを生成する
- **THEN** `snackBarTheme.behavior == SnackBarBehavior.floating`

### Requirement: 共有デザイントークン

アプリは spacing・radius・breakpoint・タッチターゲット / コンテンツ幅のスケールを単一ソース `app/lib/core/theme/tokens.dart` に const で定義しなければならない (MUST)。後続の UI 実装はマジックナンバーではなくこれらのトークンを参照すべきである (SHOULD)。

#### Scenario: トークンが const として利用できる

- **GIVEN** `app/lib/core/theme/tokens.dart`
- **WHEN** その定数を参照する
- **THEN** spacing（4 / 8 / 12 / 16 / 24 / 32）、radius（8 / 12 / 16）、最小タッチターゲット `48`、コンテンツ幅 `840`、読書幅 `680` が const として得られる

### Requirement: タッチターゲットと section spacing は共有トークンを参照する

後続の UI 実装で最小タッチターゲットまたは設定 section の余白を明示する場合、`app/lib/core/theme/tokens.dart` の `AppSizes.minTouchTarget` と `AppSpacing` を参照しなければならない (MUST)。48dp の a11y タッチターゲットを手書き数値として重複定義してはならない (MUST NOT)。

#### Scenario: notice link button が minTouchTarget token を使う

- **WHEN** Apache NOTICE または LGPL notice のリンクボタンを構築する
- **THEN** ボタンの最小高さは `AppSizes.minTouchTarget` から決まり、48 logical pixels 以上になる

#### Scenario: SettingsSection が spacing token を使う

- **WHEN** 設定 screen の `SettingsSection` を構築する
- **THEN** section 外側余白と見出し周辺の余白は `AppSpacing` token 由来の値で定義される


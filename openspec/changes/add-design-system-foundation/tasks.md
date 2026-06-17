## 1. デザイントークン

- [x] 1.1 `app/lib/core/theme/tokens.dart` を新規作成: `AppSpacing`(xs4/sm8/md12/lg16/xl24/xxl32)、`AppRadius`(sm8/md12/lg16/full999)、`AppBreakpoints`(compact600/medium1024)、`AppSizes`(minTouchTarget48/maxContentWidth840/maxReaderWidth680) を `abstract final class` の const で定義

## 2. テーマビルダー

- [x] 2.1 `app/lib/core/theme/app_theme.dart` を新規作成: `const Color kSeedColor = Color(0xFF109A78)` と `ThemeData buildAppTheme(Brightness)`（M3 / `ColorScheme.fromSeed` / 両 brightness）
- [x] 2.2 アプリ共通の component theme を定義: SnackBar(floating)、AppBar(centerTitle:false)、Card、ListTile、Filled/Outlined/Text button(min 48dp)、Slider、Dialog
- [x] 2.3 `app/lib/main.dart` の 2 つのインライン `ThemeData` を `buildAppTheme(Brightness.light/dark)` 呼び出しへ置換（`core/theme/app_theme.dart` を import）

## 3. dark-first 既定

- [x] 3.1 `AppSettings.defaults()` の `themeMode` を `ThemeMode.dark` へ変更
- [x] 3.2 `main.dart` の pre-load fallback `?? ThemeMode.system` を `?? ThemeMode.dark` へ変更
- [x] 3.3 `app/test/features/settings/domain/app_settings_test.dart` の期待値を `ThemeMode.dark` へ更新

## 4. 検証

- [x] 4.1 `app/test/core/theme/app_theme_test.dart` を追加: `buildAppTheme` が M3・両 brightness・SnackBar floating を満たし、トークンが文書化された値であることを検証
- [x] 4.2 `openspec validate add-design-system-foundation --strict` が通ることを確認
- [ ] 4.3 PR を作成し CI（`analyze --fatal-infos` + `test` + 6 ビルド）が green を確認

# Proposal: add-design-system-foundation

## Why

GeekPlayer's UI runs on the bare Flutter starter theme: two inline `ThemeData(ColorScheme.fromSeed(Colors.indigo))` blocks in `app/lib/main.dart` with no `TextTheme`, no component themes, no design tokens, and no shared theme module. A senior-designer review (6 areas, 69 findings, 18 high) found that the root cause of most inconsistency is structural, not cosmetic: every feature reinvents its spacing rhythm, radii, and component styling, so the home feed visibly splits into two design idioms (Card + titleLarge for video/audio vs bare Padding + titleMedium elsewhere). There is also no deliberate out-of-the-box theme stance for an app that is mostly used in dim conditions.

This change establishes the design-system foundation that every later UI improvement depends on.

## What Changes

- Add a single brand seed `const kSeedColor = Color(0xFF109A78)` (teal) and a centralized `ThemeData buildAppTheme(Brightness)` builder (Material 3) in a new `app/lib/core/theme/`, replacing the two inline `ThemeData` literals in `main.dart`.
- Define shared design tokens (spacing, radius, breakpoint, touch-target, content-width scales) as the single source of truth for later widget work.
- Define app-wide component themes (floating SnackBars, AppBar, Card, ListTile, Filled/Outlined/Text buttons with a 48dp minimum, Slider, Dialog) so screens stop restyling primitives ad hoc.
- Make dark the out-of-the-box default theme (`AppSettings.defaults().themeMode = ThemeMode.dark`) — a media player is predominantly used in dim conditions and the video/manga surfaces are already dark. (MODIFIES the `settings-persistence` default.)

Out of scope (follow-up changes): migrating feature screens onto the tokens/shared widgets, the responsive + navigation shell, player and reader redesigns, the `ThemeExtension` for media-scrim/reader palettes, and the broader correctness/a11y fix sweep.

## Impact

- New capability spec: `ui-design-system`.
- Modified spec: `settings-persistence` (default `themeMode` → `dark`).
- Code: new `app/lib/core/theme/{tokens,app_theme}.dart`; edits to `app/lib/main.dart` and `app/lib/features/settings/domain/app_settings.dart`; updated `app_settings` default test; new theme unit test.
- Behavior change: fresh installs now default to dark mode (users can still switch to system/light in settings).
- Verification is via CI (`flutter analyze --fatal-infos` + `flutter test` + builds) — Flutter/Dart are not installed on the dev machine.

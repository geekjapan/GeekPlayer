# Design: add-design-system-foundation

## Context

The senior-designer review confirmed token hygiene is already decent (`textTheme`/`colorScheme` used across ~22 files; hardcoded ARGB colors rare) but there is no shared structure. Two in-tree patterns already prove the target: `SettingsSection` (a local reusable card scaffold) and `core/errors/error_banner.dart` (a clean severity → `colorScheme` role mapping). A centralized theme therefore propagates to existing consumers for free — the work is consolidation, not invention.

Constraint: Flutter/Dart are not installed on the dev machine, so verification is via CI (`analyze --fatal-infos`, `test`, builds). The lint bar is strict (`flutter_lints` + strict-casts/inference/raw-types, single quotes, const constructors, trailing commas).

## Goals

- One source of truth for theme + tokens that propagates to existing `textTheme`/`colorScheme` consumers for free.
- Zero behavioral regressions except the intentional dark-first default.
- Keep the foundation small and low-risk; defer anything without a consumer yet.

## Decisions

### D1. Brand seed = teal `#109A78`, content-forward, dark-first
Chosen over keeping indigo so the rebrand reads as intentional, and over blue/violet (too close to indigo) and amber (clashes with warning semantics). A calm teal chrome lets colorful artwork be the visual hero. Both light and dark are generated from the one seed via `ColorScheme.fromSeed`; dark is shipped as the default.

### D2. Centralized `buildAppTheme(Brightness)` in `core/theme/`
A single function builds both themes so light/dark cannot drift. `main.dart` calls `buildAppTheme(Brightness.light/dark)`. This is the hook every later component theme and token plugs into.

### D3. Tokens as plain `abstract final class` consts (not a `ThemeExtension` yet)
`AppSpacing`/`AppRadius`/`AppBreakpoints`/`AppSizes` are compile-time consts — zero runtime cost, trivially testable, no `lerp` boilerplate. A `ThemeExtension` (media-scrim colors, reader palettes) is deferred to the phase that consumes it (players/readers), to avoid shipping dead code now.

### D4. Dark-first as the out-of-the-box default (`settings-persistence` MODIFIED)
`AppSettings.defaults().themeMode` becomes `ThemeMode.dark`; the `main.dart` pre-load fallback also becomes `dark` to avoid a light flash before settings hydrate. Users can still choose `system`/`light` in settings. This modifies the documented default in `settings-persistence`.

## Risks / Trade-offs

- Cannot compile locally → rely on CI. Mitigation: use stable Material 3 theme APIs, the Dart 3 `ThemeData(... )` data-class theme forms (`CardThemeData`/`DialogThemeData` for SDK 3.44), and a unit test for `buildAppTheme`.
- Dark default may surprise users who expect system-following — acceptable and reversible (a single setting), documented in the spec.
- Scope creep: feature-screen migration is intentionally excluded; this change only lands the foundation + the dark-first default.

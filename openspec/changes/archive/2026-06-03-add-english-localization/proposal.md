## Why

GeekPlayer is currently ja-first, but v0.2 explicitly includes English UI. Adding English localization before large new book and manga surfaces prevents another wave of hard-coded Japanese strings from becoming migration debt.

## What Changes

- Add English ARB coverage for the existing localization surface and make `en` a supported locale.
- Introduce a convention and tests that prevent new user-visible text in v0.2 screens from bypassing `AppLocalizations`.
- Localize navigation labels, settings/about/error strings, online-novel notices, and common media-reader actions that will be reused by PDF/EPUB and manga features.
- Keep Japanese as the default/fallback locale.

## Non-goals

- No machine translation pipeline or external translation service.
- No runtime language picker beyond following the OS locale.
- No rewrite of domain identifiers, log payloads, or protocol strings.
- No PDF/EPUB or manga feature implementation.

## Capabilities

### New Capabilities

- `english-localization`: Defines English UI support, fallback behavior, localized copy coverage, and tests for localization completeness.

### Modified Capabilities

- `error-domain`: Extends error localization from Japanese-only to Japanese and English strings.
- `about-screen`: Requires About screen copy and link labels to render in Japanese or English according to locale.
- `app-settings`: Requires settings section titles, labels, and placeholders to render through localization.
- `site-consent`: Requires consent dialogs and responsible-fetching disclosures to render through localization.

## Impact

- Localization files: `app/lib/l10n/app_ja.arb`, new `app/lib/l10n/app_en.arb`, generated `app/lib/l10n/app_localizations*.dart`.
- UI surfaces: `app/lib/features/settings/presentation/settings_screen.dart`, `app/lib/features/about/presentation/about_screen.dart`, `app/lib/features/novel/presentation/novel_settings_screen.dart`, `app/lib/core/errors/error_messages.dart`.
- Tests: existing widget tests under `app/test/features/settings/`, `app/test/features/about/`, and `app/test/core/errors/` gain locale variants.
- Docs: `docs/roadmap.md:43`, `docs/GRILL-REPORT.md:533`, `docs/CONVENTIONS.md:62`.

## 1. Inventory

- [x] 1.1 Inspect existing `app/lib/l10n/` files and generated localization setup
- [x] 1.2 Inventory shared user-visible strings in settings, about, error UX, consent, home navigation, and common reader actions
- [x] 1.3 Decide which feature-local Japanese literals remain out of scope and document them as follow-up inventory

  Out-of-scope (feature-local, deferred to their owning v0.2/future changes; each must localize its own new copy per the spec "New v0.2 UI copy is localizable by default"):
  - Narou reader/search/ranking panel internals (`novel_narou/presentation/*`), incl. the `小説家になろう` panel title.
  - The permanent ADR-0001 disclosure prose in `novel/presentation/settings_section.dart` (long-form; shared *settings section headings/controls* ARE localized).
  - The disabled placeholder button `検索画面を開く (後続 change で有効化)` in `novel_home_section.dart` (transitional; enabled by site-specific changes).
  - Age-gate dialog (`features/age_gate/*`) and audio/video player surfaces (`player_screen`, `mini_player`).

## 2. Localization Files

- [x] 2.1 Add `app/lib/l10n/app_en.arb` with key parity against `app_ja.arb` (116/116 translatable keys, verified by parity test)
- [x] 2.2 Add English translations for existing error messages, settings labels, about labels, consent copy, and shared actions
- [x] 2.3 Regenerate localization outputs using the repository's Flutter localization workflow (`flutter gen-l10n` → `app_localizations_en.dart`)
- [x] 2.4 Confirm generated files are committed or reproducible according to the existing project convention (generated `app_localizations*.dart` are tracked and reproducible)

## 3. UI Wiring

- [x] 3.1 Wire MaterialApp supported locales to include English (`en` now in `supportedLocales`; `main.dart` no longer hard-pins `Locale('ja')`, so the app follows the OS locale with Japanese fallback per design D3)
- [x] 3.2 Replace shared Settings screen literals with `AppLocalizations` (settings_screen + all 10 section files)
- [x] 3.3 Replace About screen literals with `AppLocalizations` (about_screen, lgpl_notice_section, license_screen)
- [x] 3.4 Replace consent and responsible-fetching disclosure literals with `AppLocalizations` (consent_dialog, kakuyomu_consent_dialog, kakuyomu_consent_required_screen, novel_home_section consent banner)
- [x] 3.5 Replace common error and reader-action literals with `AppLocalizations` (error-domain copy + `actionRetry` already routed through `AppLocalizations`/`ErrorMessages.localize`)

## 4. Tests

- [x] 4.1 Add an ARB key parity test for Japanese and English (`test/l10n/arb_parity_test.dart`)
- [x] 4.2 Add English locale widget coverage for Settings (`test/l10n/settings_about_locale_test.dart`)
- [x] 4.3 Add English locale widget coverage for About (`test/l10n/settings_about_locale_test.dart`)
- [x] 4.4 Add English locale coverage for error localization (`test/l10n/error_locale_en_test.dart`)
- [x] 4.5 Add English locale coverage for consent/disclosure UI where practical (`test/l10n/consent_locale_test.dart`)

## 5. Verification

- [x] 5.1 Run `cd app && dart run build_runner build --delete-conflicting-outputs` (no codegen drift; 0 changed outputs)
- [x] 5.2 Run `cd app && dart format --output=none --set-exit-if-changed .` (clean, 0 changed)
- [x] 5.3 Run `cd app && flutter analyze --fatal-infos` (No issues found)
- [x] 5.4 Run `cd app && flutter test` (406 tests passed)
- [x] 5.5 Run `openspec validate --all --strict` (this change + its delta specs pass; the single remaining failure is the pre-existing, unrelated `spec/app-settings` requirement-11 issue, out of scope and archive-only)
- [x] 5.6 Run `git diff --check` (clean)

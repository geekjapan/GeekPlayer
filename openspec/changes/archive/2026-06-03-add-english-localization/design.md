## Context

v0.1 already uses Flutter localization plumbing for error messages, but much of the UI remains Japanese literals. v0.2 will add large new book and manga surfaces, so English support should land before those screens create more copy to migrate.

## Goals / Non-Goals

**Goals:**

- Make Japanese and English supported locales.
- Keep Japanese as the fallback/default.
- Move user-visible reusable copy through `AppLocalizations`.
- Add tests that catch missing English strings and locale rendering regressions.

**Non-Goals:**

- No in-app language picker.
- No automated translation workflow.
- No localization of logs, protocol identifiers, database values, or license text.

## Decisions

### D1. Use Flutter gen-l10n ARB files

The app already has generated localization files. Continue with `app/lib/l10n/app_ja.arb` and add `app/lib/l10n/app_en.arb`. The alternative is a custom translation map, but Flutter's generated APIs give compile-time accessors and better testability.

### D2. Localize reusable shell and shared surfaces first

Prioritize `MaterialApp`, settings, about, errors, consent, navigation labels, and common reader actions. Feature-specific long-form copy can move incrementally, but any new v0.2 screen must use localization from the start.

### D3. Follow OS locale only

This change adds `en` support without introducing a language setting. A language picker would require persistence, settings UX, and user expectations around hot reload of locale; it belongs in a later change if needed.

### D4. Add a lint-like test instead of a custom analyzer plugin

Use focused tests to verify ARB key parity and representative widget rendering in `ja` and `en`. A custom analyzer rule for string literals would be stronger but more expensive and brittle.

## Risks / Trade-offs

- [Risk] Some existing Japanese literals remain -> Mitigation: scope the first pass to shared screens and add a TODO inventory for remaining feature-local copy.
- [Risk] Generated localization files get stale -> Mitigation: run `flutter gen-l10n` or the existing Flutter build step and verify generated files in tests.
- [Risk] English copy quality is uneven -> Mitigation: keep strings concise and literal; defer editorial polish to a later docs/copy pass.

## Migration Plan

1. Add `app_en.arb` with parity against `app_ja.arb`.
2. Regenerate localization files.
3. Replace shared UI literals with localization getters.
4. Add locale-specific widget tests.

Rollback is safe by reverting ARB/generated/UI changes; no data migration is involved.

## Open Questions

- Whether to add an in-app language picker remains deferred.

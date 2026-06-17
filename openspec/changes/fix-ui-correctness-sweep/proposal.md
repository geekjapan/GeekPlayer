# Proposal: fix-ui-correctness-sweep

## Why

The senior-designer UI review surfaced genuine correctness/accessibility defects behind the cosmetic ones. This change starts the fix sweep with two high-confidence, low-risk corrections (batch 1); the remaining sweep items are deferred to later batches so each stays small and CI-verifiable (Flutter/Dart are not installed locally — CI is the only checker).

## What Changes (batch 1)

- **Narou work-detail episode list**: rows rendered a blank title (`Text('')`, with 第N話 only in `leading`), and short works (`generalAllNo == 0`, `isShort`) showed ZERO episodes. Make 第N話 the row title with a trailing chevron, and derive the row count from `summary.isShort ? 1 : summary.generalAllNo` so short works show their single episode. This brings the screen in line with `narou-novel-reader-ui` ("Episode list shows numbered episodes").
- **Audio & video home-section error rows**: the error icon hardcoded `Colors.redAccent`, which ignores dark mode and is off-palette from the teal seed. Use `Theme.of(context).colorScheme.error`.

Deferred to later batches: raw exception strings → `ErrorMessages.localize`; ISO-8601 date formatting; empty-placeholder / `policyVersion` debug-text cleanup (spec-entangled); destructive-button error color; 48dp license links; settings-section header.

## Impact

- Code: `app/lib/features/novel_narou/presentation/work_detail_screen.dart`; `app/lib/features/{audio,video}/presentation/home_section.dart`.
- Spec: `narou-novel-reader-ui` — add a short-work episode-list scenario.
- No behavior regressions; the Narou episode list now renders correctly and adapts to dark mode.

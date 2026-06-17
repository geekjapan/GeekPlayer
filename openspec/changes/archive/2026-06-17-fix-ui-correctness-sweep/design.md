# Design: fix-ui-correctness-sweep

## Context

Phase 2 of the UI improvement roadmap is the correctness/a11y fix sweep. Some "quick wins" turned out to be entangled with specs/tests (the novel empty-placeholder is tied to an `online-novel-library` spec scenario; raw-error-string fixes need the `ErrorMessages.localize` contract), so the sweep is split into small batches rather than one blind pass. Batch 1 is the two cleanest, highest-confidence fixes. Flutter/Dart are not installed locally → CI is the only analyze/format/test checker (see memory: CI gates fail one layer at a time).

## Decisions

### D1. Fix the Narou episode list to match its spec and handle short works
The row count is derived once as `episodeCount = summary.isShort ? 1 : summary.generalAllNo` (short works report `generalAllNo == 0`). 第N話 moves from `leading` to `title` (the row's primary text) with a trailing chevron affordance, matching `narou-novel-reader-ui` "Episode list shows numbered episodes". Per-episode chapter title/date remain out of scope (not available from the summary object) — unchanged from before.

### D2. Semantic error color
`_ErrorRow` in the audio/video home sections uses `Theme.of(context).colorScheme.error` instead of `Colors.redAccent`, so the error icon adapts to light/dark and stays on-palette. The `Icon` drops `const` (the color is now resolved from context).

## Risks / Trade-offs

- No widget test exists for the Narou work-detail episode rows (only domain/data tests), so the title/short-work change is verified by CI compile + the existing suite plus manual reasoning.
- The error-icon line sits at the 80-col formatter boundary; if `dart format` wraps it, a one-line follow-up fix will be needed (CI will report).

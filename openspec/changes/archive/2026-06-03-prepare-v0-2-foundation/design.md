## Context

GeekPlayer has a tagged v0.1 baseline and no active OpenSpec changes, but the docs still mix pre-implementation instructions with completed v0.1 state. v0.2 introduces larger cross-cutting work, including books, manga, platform expansion, localization, CI, and auto-update. Several old GRILL findings also affect v0.2 entry criteria.

## Goals / Non-Goals

**Goals:**

- Make the docs accurately describe the current repository state.
- Convert unresolved GRILL findings into resolved decisions, deferred ADRs, or explicit future-change prerequisites.
- Add a v0.2 readiness spec so new changes can start from a stable checklist.
- Create the iOS/iPadOS media-engine/distribution ADR before any platform implementation.

**Non-Goals:**

- No app feature implementation.
- No migration of drift schemas.
- No changes to runtime behavior.

## Decisions

### D1. Treat this as a planning/readiness change

This change updates docs, ADRs, and specs only. The alternative is to fold cleanup into the first feature change, but that would make the feature implementation carry stale-state risk and unrelated decision churn.

### D2. Add a new v0.2 readiness capability

The readiness checklist becomes a real OpenSpec capability instead of a prose-only handoff note. This keeps future v0.2 changes testable at the spec level: if prerequisites are missing, the change is not ready to apply.

### D3. Use additive deltas for existing capabilities

Existing v0.1 behavior remains valid. The deltas add planning prerequisites for `site-consent`, `settings-persistence`, and `lgpl-compliance` without rewriting their current requirements.

### D4. Number the new ADR after existing ADRs

Create `docs/adr/0006-ios-media-engine-distribution-policy.md`. ADR-0005 exists in prior audit memory and may not be present in this checkout; using 0006 avoids accidental reuse if that file returns from another branch.

## Risks / Trade-offs

- [Risk] Docs may drift again after v0.2 starts -> Mitigation: add tasks to update `HANDOFF.md`, `roadmap.md`, and `GRILL-REPORT.md` as part of this change.
- [Risk] ADR number gap looks odd -> Mitigation: document the reason in the ADR header and avoid renumbering existing ADRs.
- [Risk] Planning-only change feels non-functional -> Mitigation: keep tasks small and require `openspec validate --all --strict` plus `git diff --check`.

## Migration Plan

1. Update docs and GRILL statuses.
2. Add ADR-0006.
3. Validate OpenSpec.
4. Archive this change before implementing v0.2 feature changes.

Rollback is a normal git revert of docs/OpenSpec files; no app data or runtime state is affected.

## Open Questions

- Whether `add-platform-ios` will keep media_kit via direct distribution or swap video playback engines is intentionally decided in ADR-0006 during this change.

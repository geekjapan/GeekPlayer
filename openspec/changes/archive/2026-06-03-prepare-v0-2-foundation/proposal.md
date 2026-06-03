## Why

v0.1 is implemented and archived, but the handoff documents still contain stale pre-implementation sections and the v0.2 backlog has several unresolved design questions. Before adding new reader surfaces, GeekPlayer needs a small foundation pass that makes the current state trustworthy and turns v0.2 into an ordered, implementable backlog.

## What Changes

- Refresh v0.1/v0.2 documentation so current status, active changes, release state, and next steps no longer contradict each other.
- Resolve or explicitly route the remaining v0.2-impacting questions from `docs/GRILL-REPORT.md`.
- Add an ADR for iOS/iPadOS media-engine and LGPL distribution policy before any `add-platform-ios` implementation.
- Define the v0.2 sequencing rules for localization, book reader, manga viewer, library features, platform expansion, CI, and auto-update changes.
- Add a lightweight verification checklist for future v0.2 change proposals.

## Non-goals

- No user-facing feature implementation.
- No platform enablement for Linux, iOS, or iPadOS.
- No dependency changes in `app/pubspec.yaml`.
- No database schema migration.

## Capabilities

### New Capabilities

- `v0-2-foundation-readiness`: Defines the readiness contract for starting v0.2 changes, including stale-doc cleanup, unresolved-question routing, ADR prerequisites, and backlog sequencing.

### Modified Capabilities

- `site-consent`: Clarifies how v0.2 planning must handle R18 consent semantics and revocation/cache policy before expanding online novel or settings behavior.
- `settings-persistence`: Clarifies v0.2 planning requirements for settings-driven behavior and future localization-facing settings copy.
- `lgpl-compliance`: Adds the requirement that iOS/iPadOS platform work must be preceded by an explicit media-engine/distribution ADR.

## Impact

- Documentation: `docs/HANDOFF.md:5`, `docs/HANDOFF.md:144`, `docs/GRILL-REPORT.md:573`, `docs/roadmap.md:30`, `docs/release.md:1`.
- ADRs: new `docs/adr/0006-ios-media-engine-distribution-policy.md`.
- OpenSpec: new `openspec/specs/v0-2-foundation-readiness/spec.md` after archive, plus deltas for `site-consent`, `settings-persistence`, and `lgpl-compliance`.
- Verification: `openspec list --json`, `openspec validate --all --strict`, `git diff --check`.

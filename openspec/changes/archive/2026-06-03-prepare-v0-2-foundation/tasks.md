## 1. Current State Audit

- [x] 1.1 Run `openspec list --json` and confirm the active-change baseline before editing docs
- [x] 1.2 Review `docs/HANDOFF.md`, `docs/GRILL-REPORT.md`, `docs/roadmap.md`, `docs/release.md`, and `README.md` for stale v0.1/v0.2 claims
- [x] 1.3 Record the current v0.1 release, OpenSpec archive, and CI status in the refreshed handoff

## 2. Documentation Refresh

- [x] 2.1 Update `docs/HANDOFF.md` so v0.1 archived state is the only authoritative baseline
- [x] 2.2 Remove or clearly mark stale v0.1 wave-apply instructions as historical
- [x] 2.3 Update `docs/roadmap.md` with an explicit v0.2 sequencing section
- [x] 2.4 Add a v0.2 proposal readiness checklist to the docs
- [x] 2.5 Update `README.md` only if its v0.2 summary contradicts the refreshed roadmap (no change: README v0.2 summary is consistent with the refreshed roadmap; it omits but does not contradict)

## 3. GRILL Resolution Pass

- [x] 3.1 Triage every unchecked item in `docs/GRILL-REPORT.md`
- [x] 3.2 Mark fixed repository gaps that already have tests or implementation
- [x] 3.3 Assign remaining feature-specific questions to named future changes
- [x] 3.4 Keep strategic iOS/libmpv distribution work assigned to ADR-0006

## 4. ADR

- [x] 4.1 Create `docs/adr/0006-ios-media-engine-distribution-policy.md`
- [x] 4.2 Compare direct distribution with media_kit, iOS engine substitution, and other LGPL compliance options
- [x] 4.3 Record the selected option and its consequences for future `add-platform-ios`

## 5. Verification

- [x] 5.1 Run `openspec validate --all --strict` (this change + its 3 delta specs pass strict; 1 pre-existing failure in `spec/app-settings` requirement 11 is unrelated, untouched by this change, and out of scope — main specs are archive-only per CLAUDE.md/HANDOFF §8)
- [x] 5.2 Run `git diff --check` (clean, no whitespace errors)
- [x] 5.3 Confirm `openspec status --change prepare-v0-2-foundation` reports apply-ready artifacts (isComplete: true, all 4 artifacts done)

## ADDED Requirements

### Requirement: v0.2 entry documentation is current

The system SHALL keep the v0.2 entry documentation internally consistent before any v0.2 feature change is applied. `docs/HANDOFF.md` MUST describe the current v0.1 archive state, MUST remove or clearly mark stale pre-v0.1 apply instructions, and MUST point future implementers to active v0.2 changes rather than archived v0.1 waves.

#### Scenario: Handoff does not claim v0.1 changes are unimplemented

- **WHEN** a developer reads `docs/HANDOFF.md`
- **THEN** the document states that v0.1 changes are archived and does not present archived v0.1 changes as the next implementation step

### Requirement: Remaining GRILL questions are routed

Every unchecked item in `docs/GRILL-REPORT.md` that affects v0.2 SHALL be resolved, assigned to a named future change, or explicitly deferred with rationale. The report MUST distinguish fixed repository gaps from strategic decisions that require ADRs.

#### Scenario: Open question index has no unowned v0.2 blocker

- **WHEN** a developer reviews `docs/GRILL-REPORT.md` after this change
- **THEN** every remaining unchecked item names a follow-up change, ADR, or deferral reason

### Requirement: v0.2 backlog order is explicit

The repository SHALL document the recommended v0.2 change order, including localization before large new UI surfaces, book/manga reader sequencing, platform expansion prerequisites, and CI/auto-update placement.

#### Scenario: A future agent can select the next change

- **WHEN** a future agent starts from the v0.2 docs
- **THEN** it can identify the next recommended OpenSpec change without reading prior chat history

### Requirement: v0.2 proposal checklist exists

The repository SHALL provide a checklist for future v0.2 proposals covering affected capabilities, ADR prerequisites, platform support, dependency/license impact, drift schema versioning, localization, and validation commands.

#### Scenario: New v0.2 feature proposal uses the checklist

- **WHEN** a developer creates a v0.2 feature proposal
- **THEN** the proposal can be checked against the documented readiness checklist before implementation starts

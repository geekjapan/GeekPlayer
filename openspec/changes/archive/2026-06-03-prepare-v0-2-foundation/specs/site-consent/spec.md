## ADDED Requirements

### Requirement: R18 consent semantics are assigned before expansion

Before any v0.2 change modifies R18 online novel behavior, the system SHALL document whether age verification and responsible-fetching consent remain in `site_consents` or move to separate persistence. The chosen model MUST define policy version values, revocation behavior, and cache handling.

#### Scenario: R18 expansion change checks consent ownership

- **WHEN** a v0.2 change proposes new R18 behavior
- **THEN** its proposal references the chosen R18 consent model and does not introduce a second conflicting interpretation

### Requirement: Consent revocation cache policy is explicit

The system SHALL document what happens to cached R18 and site-specific online novel content when the user revokes consent. The policy MUST define whether cached entries remain readable, are hidden, or are offered for deletion.

#### Scenario: Revocation policy is testable

- **WHEN** a developer implements consent revocation UI
- **THEN** the expected cached-content behavior is specified before code is written

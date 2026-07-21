## ADDED Requirements

### Requirement: Consent dialog does not surface internal policyVersion as user copy

The `ConsentDialog` MUST NOT display the internal `policyVersion` control value (e.g. `policyVersion: 2026-05-27`) as user-facing body copy. `policyVersion` remains a technical control persisted to `site_consents` and used for stale-policy re-prompt detection; it is not user disclosure. Removing the displayed value MUST NOT change the stamping or re-prompt semantics defined in "First-launch consent dialog" and "Policy version tracking".

#### Scenario: Dialog body omits the policyVersion debug string

- **WHEN** the `ConsentDialog` is rendered (first launch or stale-policy re-prompt)
- **THEN** no text matching "policyVersion:" appears in the dialog body, and each supported `Site` checkbox plus the confirm / "すべて拒否" actions remain present

#### Scenario: policyVersion stamping is unchanged

- **WHEN** the user confirms a decision in the `ConsentDialog`
- **THEN** the persisted `site_consents` rows are still stamped with the current `policyVersion`, exactly as before the debug copy was removed

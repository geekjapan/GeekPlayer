# lgpl-compliance Delta Specification (add-platform-ios)

The following requirements are ADDED to the `lgpl-compliance` capability. All existing requirements in `openspec/specs/lgpl-compliance/spec.md` remain in force.

## ADDED Requirements

### Requirement: iOS platform libmpv replacement path is documented

The per-platform libmpv replacement instructions (in both `THIRD_PARTY_NOTICES.md` and the in-app LGPL notice section) MUST cover iOS in addition to the existing macOS, Windows, and Android entries. The iOS instructions MUST specify the in-bundle location of the libmpv framework, that the app must be re-signed after replacement (Ad Hoc or developer signing), and that this applies to non-App-Store distribution only (per ADR-0006).

#### Scenario: iOS replacement path is documented in THIRD_PARTY_NOTICES

- **WHEN** `THIRD_PARTY_NOTICES.md` is rendered
- **THEN** the iOS instructions reference the path `Frameworks/` inside the `.app` bundle as the location of the libmpv framework, and note that re-signing is required after replacement

#### Scenario: iOS replacement path is visible in app LGPL notice

- **WHEN** the LGPL notice section is rendered in the app
- **THEN** the per-platform replacement instructions include an iOS entry referencing the framework location inside the app bundle

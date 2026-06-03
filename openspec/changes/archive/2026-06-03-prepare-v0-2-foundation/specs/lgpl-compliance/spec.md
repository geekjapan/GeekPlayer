## ADDED Requirements

### Requirement: iOS and iPadOS platform work requires a media-engine distribution ADR

Before any `add-platform-ios` or iPadOS implementation begins, the repository SHALL include an accepted ADR that decides how GeekPlayer handles libmpv/media_kit, LGPL obligations, and non-store distribution on iOS/iPadOS.

#### Scenario: iOS platform proposal checks ADR

- **WHEN** a developer proposes iOS or iPadOS support
- **THEN** the proposal references the accepted media-engine distribution ADR and follows its selected option

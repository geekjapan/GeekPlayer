## ADDED Requirements

### Requirement: v0.2 settings changes name their runtime propagation model

Every v0.2 change that adds or consumes an `AppSettings` value SHALL define whether the value applies only to new sessions or updates currently active sessions. The implementation MUST use Riverpod subscriptions consistently with that decision.

#### Scenario: Reader setting declares propagation behavior

- **WHEN** a v0.2 reader setting is proposed
- **THEN** its design states whether changing the setting affects the open reader immediately or only the next opened document

### Requirement: Settings-facing copy participates in localization

Every new v0.2 settings label, section heading, placeholder, and dialog string SHALL use the localization system rather than a raw UI literal.

#### Scenario: New settings row is localizable

- **WHEN** a developer adds a settings row in a v0.2 change
- **THEN** the row label has Japanese and English localization entries

## ADDED Requirements

### Requirement: About screen supports English copy

The About screen SHALL render localized section labels, link labels, and fallback metadata labels in Japanese or English according to `AppLocalizations`.

#### Scenario: About screen renders English labels

- **WHEN** the About screen is pumped with `Locale('en')`
- **THEN** labels for version, build number, commit, repository, roadmap, and license are displayed in English

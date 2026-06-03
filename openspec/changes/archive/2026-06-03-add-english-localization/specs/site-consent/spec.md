## ADDED Requirements

### Requirement: Consent and responsible-fetching disclosures support English copy

Consent dialogs and online-novel responsible-fetching disclosures SHALL render through localization and support Japanese and English while preserving site names, ADR identifiers, URLs, and rate-limit values as literal technical terms.

#### Scenario: Consent dialog renders English disclosure

- **WHEN** the first-launch consent dialog is pumped with `Locale('en')`
- **THEN** the disclosure explains active caching, rate limiting, robots.txt, and per-site consent in English

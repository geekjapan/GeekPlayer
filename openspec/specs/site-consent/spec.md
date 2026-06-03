# site-consent Specification

## Purpose
TBD - created by archiving change add-online-novel-library. Update Purpose after archive.
## Requirements
### Requirement: First-launch consent dialog

The system SHALL display a `ConsentDialog` on first launch when no rows exist in `site_consents`, OR when the stored `policyVersion` is older than the current ADR-0001 policy version. The dialog MUST present each supported `Site` (narou / noc / kakuyomu) as an independent checkbox and MUST allow the user to confirm with any combination of grants (including all denied). The dialog MUST be dismissible only via an explicit user action.

#### Scenario: First launch shows the dialog

- **GIVEN** the user installs the app for the first time and `site_consents` is empty
- **WHEN** the app finishes initial startup and renders the home screen
- **THEN** the `ConsentDialog` appears modally above the home screen and cannot be dismissed by tapping outside or pressing the back button alone

#### Scenario: Granting some sites persists per-site rows

- **WHEN** the user checks `narou` and `noc` (leaves `kakuyomu` unchecked) and taps "決定"
- **THEN** three rows are written to `site_consents`: `(narou, granted=true)`, `(noc, granted=true)`, `(kakuyomu, granted=false)`, each with the current `policyVersion` and `decidedAt = now`

#### Scenario: "すべて拒否" persists three denied rows

- **WHEN** the user taps "すべて拒否"
- **THEN** three rows are written to `site_consents` with `granted=false` for narou / noc / kakuyomu, and the `NovelHomeSection` placeholder is "サイトへの同意がありません — 設定から有効化してください"

#### Scenario: Closing the app without deciding re-prompts on next launch

- **GIVEN** the `ConsentDialog` is visible and the user force-quits the app
- **WHEN** the app is launched again
- **THEN** the `ConsentDialog` is shown again because no rows exist in `site_consents`

### Requirement: Settings screen permanent disclosure

The system SHALL display a permanent disclosure block at the top of the `Settings > オンライン小説` screen reproducing the responsible-scraping notice required by ADR-0001 §注意書き-3. The disclosure MUST list the sites covered, the rate limits applied, and a link to the ADR document. The disclosure MUST be visible regardless of current consent state.

#### Scenario: Disclosure is always visible

- **WHEN** the user navigates to `Settings > オンライン小説`
- **THEN** the disclosure block is the first element on the screen and contains the strings "ADR-0001", "1 req / 2 s" (for kakuyomu), and "能動キャッシュ"

### Requirement: Consent revocation and re-grant from settings

The system SHALL allow the user to grant, revoke, or re-grant consent for each `Site` independently from `Settings > オンライン小説`. Revoking consent MUST stop all subsequent `NovelRepository` calls for that `Site` but MUST NOT delete Library entries or cached `novel_episodes` rows belonging to that `Site`.

#### Scenario: Revoking kakuyomu consent stops fetches

- **GIVEN** the user previously granted kakuyomu consent and added a kakuyomu Work to the Library
- **WHEN** the user toggles kakuyomu consent to OFF in settings
- **THEN** `site_consents` is updated to `(kakuyomu, granted=false)`, the existing Library entry remains readable from cached `novel_episodes`, and any subsequent call to a kakuyomu `NovelRepository` method throws `SiteConsentRequiredError`

#### Scenario: Re-granting consent resumes fetches without re-prompt

- **GIVEN** kakuyomu consent was previously revoked
- **WHEN** the user toggles kakuyomu consent back to ON
- **THEN** `site_consents` is updated to `granted=true` with a fresh `decidedAt`, and subsequent `NovelRepository` calls for kakuyomu succeed without showing the `ConsentDialog`

### Requirement: Consent enforcement at the repository layer

The system SHALL gate every `NovelRepository` operation on the corresponding `SiteConsent`. If the consent for the target `Site` is missing or `granted=false`, the operation MUST throw `SiteConsentRequiredError` synchronously before any network call is issued.

#### Scenario: Missing consent fails fast

- **GIVEN** `site_consents` has no row for `narou`
- **WHEN** any `NovelRepository` operation is called with `site == narou`
- **THEN** `SiteConsentRequiredError` is thrown before any HTTP request is dispatched

#### Scenario: Consent denied fails fast

- **GIVEN** `site_consents` has `(narou, granted=false)`
- **WHEN** any `NovelRepository` operation is called with `site == narou`
- **THEN** `SiteConsentRequiredError` is thrown before any HTTP request is dispatched

### Requirement: Policy version tracking

The system SHALL store the `policyVersion` string (default `'2026-05-27'`, matching ADR-0001 acceptance date) on every row of `site_consents` at the time the user makes the decision. When the app starts and the stored `policyVersion` is older than the current shipping `policyVersion`, the system MUST treat existing consents as expired and re-show the `ConsentDialog` with a banner explaining that the policy was updated.

#### Scenario: Older policyVersion triggers re-prompt

- **GIVEN** `site_consents` contains rows with `policyVersion='2026-05-27'` and the current shipping policy version is `'2026-09-01'`
- **WHEN** the app starts
- **THEN** the `ConsentDialog` is shown with the banner "ポリシーが更新されました"

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

### Requirement: Consent and responsible-fetching disclosures support English copy

Consent dialogs and online-novel responsible-fetching disclosures SHALL render through localization and support Japanese and English while preserving site names, ADR identifiers, URLs, and rate-limit values as literal technical terms.

#### Scenario: Consent dialog renders English disclosure

- **WHEN** the first-launch consent dialog is pumped with `Locale('en')`
- **THEN** the disclosure explains active caching, rate limiting, robots.txt, and per-site consent in English


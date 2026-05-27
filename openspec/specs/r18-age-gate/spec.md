# r18-age-gate Specification

## Purpose
TBD - created by archiving change add-narou-novel-reader. Update Purpose after archive.
## Requirements
### Requirement: Age gate dialog before R18 functionality

The system SHALL display an `AgeGateDialog` whenever the user first attempts to use any UI affordance that depends on the R18 endpoint (ノクターン / ミッドナイト / ムーンライト tabs, R18 search, R18 ranking). The dialog MUST present a clear yes/no question ("あなたは18歳以上ですか?"), include a short explanatory paragraph about the R18 content nature, and provide exactly two action buttons ("はい、18歳以上です" and "いいえ"). The dialog MUST be implemented at `app/lib/features/age_gate/presentation/age_gate_dialog.dart` and SHALL be modal (barrier-dismissible only via explicit no-press or system back).

#### Scenario: Dialog appears on first R18 access

- **GIVEN** no `SiteConsent` for `Site.noc` exists
- **WHEN** the user taps the "ノクターン" entry point in the なろう section
- **THEN** the `AgeGateDialog` is presented modally before any R18 API request is issued

#### Scenario: Granting consent persists and unlocks R18

- **GIVEN** the `AgeGateDialog` is open
- **WHEN** the user taps "はい、18歳以上です"
- **THEN** `SiteConsentRepository.grant(Site.noc, policyVersion: 'age-verified')` is called, the dialog dismisses, and the requested R18 screen loads

#### Scenario: Declining keeps the R18 surface locked

- **GIVEN** the `AgeGateDialog` is open
- **WHEN** the user taps "いいえ" or invokes system back
- **THEN** the dialog dismisses without granting consent, the requested R18 screen is NOT navigated to, and the user is returned to the previous screen

#### Scenario: Subsequent access reuses the granted consent

- **GIVEN** the user has previously granted R18 consent
- **WHEN** the user taps any R18 entry point again
- **THEN** the `AgeGateDialog` is NOT shown and the R18 screen loads directly

### Requirement: Persistent consent storage backed by site_consents table

The age-gate consent SHALL be persisted in the shared `site_consents` drift table provided by `add-online-novel-library`, keyed by `Site.noc`. The stored record MUST include at least the consent grant timestamp. Consent SHALL NOT expire automatically; it remains valid until explicitly revoked through the settings UI.

#### Scenario: Consent survives app restart

- **GIVEN** the user has granted R18 consent in a previous session and quit the app
- **WHEN** the app is launched again
- **THEN** `SiteConsentRepository.isGranted(Site.noc)` returns `true` and the R18 surface is available without re-prompting

#### Scenario: Consent is read from drift on cold start

- **WHEN** the app cold-starts and the `SiteConsentRepository` is first queried
- **THEN** the `site_consents` row for `Site.noc` is read directly from drift (not from a cached preference), so manual DB clears reliably reset the gate

### Requirement: Settings screen lets users revoke and re-grant consent

The settings screen SHALL include an "オンライン小説" subsection with a "年齢確認をやり直す" entry implemented at `app/lib/features/age_gate/presentation/age_gate_settings_section.dart`. The entry MUST show the current consent state (granted with timestamp, or not granted). When the user activates the entry, the system MUST present a confirmation dialog, and on confirm SHALL revoke the consent via `SiteConsentRepository.revoke(Site.noc)`. After revocation, R18 surfaces MUST be hidden until consent is granted again.

#### Scenario: Settings shows current consent state

- **GIVEN** the user has previously granted R18 consent on 2026-04-01
- **WHEN** the user opens `Settings > オンライン小説`
- **THEN** the row displays "同意済み (2026-04-01)" or equivalent localized text

#### Scenario: Revoking consent hides R18 surfaces immediately

- **GIVEN** the user is on the settings screen with R18 consent currently granted
- **WHEN** the user taps "年齢確認をやり直す" and confirms revocation
- **THEN** `SiteConsentRepository.revoke(Site.noc)` is called, the row updates to "未同意", and any subsequently opened なろう home section MUST NOT show R18 tabs

#### Scenario: Active R18 repository is invalidated after revoke

- **GIVEN** an R18 reader screen is currently rendered with an active `NarouR18NovelRepository`
- **WHEN** the user navigates to settings and revokes consent
- **THEN** on return to the R18 reader the Riverpod provider holding the R18 repository SHALL be invalidated, the screen SHALL navigate back to a non-R18 fallback, and no further R18 API requests SHALL be issued

### Requirement: Defensive fallback if consent state is corrupted or missing

The system SHALL treat any non-`granted` consent state — including missing rows, malformed timestamps, and explicit `revoked` markers — as "not granted". The R18 repository MUST refuse to operate in any state other than explicit grant. If the user's settings UI is somehow bypassed (e.g., direct DB tampering causing an unexpected enum value), the system SHALL fail closed and re-show the `AgeGateDialog` on next R18 access.

#### Scenario: Unknown consent value is treated as not granted

- **GIVEN** the `site_consents` row for `Site.noc` contains an unknown status value
- **WHEN** the app evaluates `SiteConsentRepository.isGranted(Site.noc)`
- **THEN** the method returns `false` and a structured log entry records the corruption

#### Scenario: Missing row defaults to not granted

- **GIVEN** no `site_consents` row exists for `Site.noc`
- **WHEN** any R18 access is attempted
- **THEN** the `AgeGateDialog` is shown and the API call is blocked until the user explicitly grants consent


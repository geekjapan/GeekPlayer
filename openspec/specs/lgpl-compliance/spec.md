# lgpl-compliance Specification

## Purpose
TBD - created by archiving change add-about-and-licenses. Update Purpose after archive.
## Requirements
### Requirement: libmpv LGPL notice section

The system SHALL render a dedicated LGPL notice section at the top of the License list screen via `app/lib/features/about/presentation/lgpl_notice_section.dart`. The section MUST state, in user-readable Japanese supplemented by the verbatim upstream license name, that:

- libmpv is distributed under LGPL-2.1+
- GeekPlayer uses libmpv via `media_kit` as a **dynamically linked** library
- The full license text is available within the OSS Licenses screen of this app
- The user has the right to replace the libmpv component with a modified build and re-run GeekPlayer

The section MUST appear above all auto-generated dependency entries and MUST NOT be collapsible to ensure visibility.

#### Scenario: LGPL section is visible without scrolling on first paint

- **WHEN** the License list screen is opened on a device with a viewport of 360x640 logical pixels or larger
- **THEN** the LGPL notice section header and the words "LGPL-2.1+" and "動的リンク" are visible without requiring the user to scroll

#### Scenario: LGPL section text is selectable

- **WHEN** the user long-presses any paragraph within the LGPL notice section
- **THEN** the text is selectable and can be copied to the clipboard

### Requirement: Upstream source URL is provided

The LGPL notice section SHALL display the upstream libmpv source URL `https://github.com/mpv-player/mpv` as a tappable link. Tapping MUST open the URL in the OS default browser via `url_launcher`.

#### Scenario: User taps the upstream link

- **WHEN** the user taps the "上流ソース (mpv-player/mpv)" link
- **THEN** the OS default browser opens `https://github.com/mpv-player/mpv`

#### Scenario: Upstream URL is hardcoded, not derived from a build variable

- **WHEN** the app is built with any combination of `--dart-define` flags
- **THEN** the displayed upstream URL is exactly `https://github.com/mpv-player/mpv` and is not affected by environment variables

### Requirement: Per-platform libmpv replacement instructions

The LGPL notice section SHALL provide a per-platform summary of how a user can replace the libmpv binary shipped with GeekPlayer with their own build. The summary MUST cover macOS, Windows, and Android (the v0.1 distribution targets) and MUST include the in-package location of the binary on each platform. A "詳細は THIRD_PARTY_NOTICES を参照" link to the canonical document SHALL be included for users who need exhaustive steps.

#### Scenario: macOS replacement path is documented

- **WHEN** the LGPL notice section is rendered
- **THEN** the macOS instructions reference the path `Contents/Frameworks/` inside the `.app` bundle as the location of the libmpv framework

#### Scenario: Windows replacement path is documented

- **WHEN** the LGPL notice section is rendered
- **THEN** the Windows instructions reference replacing the `mpv-2.dll` (or equivalent) file located alongside the `GeekPlayer.exe` binary

#### Scenario: Android replacement path is documented

- **WHEN** the LGPL notice section is rendered
- **THEN** the Android instructions reference the path `lib/<abi>/libmpv.so` inside the APK or App Bundle and note that re-signing the APK is required after replacement

#### Scenario: Detailed steps link points to repository document

- **WHEN** the user taps "詳細は THIRD_PARTY_NOTICES を参照"
- **THEN** the OS default browser opens the canonical URL `https://github.com/geekjapan/GeekPlayer/blob/main/THIRD_PARTY_NOTICES.md`

### Requirement: User rights statement under LGPL

The LGPL notice section SHALL include an explicit statement, in Japanese, affirming that under LGPL-2.1+ the user is entitled to (a) study, modify, and rebuild the libmpv component independently of GeekPlayer, and (b) redistribute that modified component subject to LGPL terms. The statement MUST NOT be obscured by collapsible UI elements.

#### Scenario: Rights statement is rendered as plain text

- **WHEN** the License list screen is opened
- **THEN** the LGPL notice section contains a paragraph that includes the phrases "差し替える権利", "再構築", and "LGPL-2.1+" rendered as plain selectable text

### Requirement: LGPL full license text bundled in app

The full text of the LGPL-2.1 license SHALL be bundled at `app/assets/legal/LGPL-2.1.txt` and accessible from the LGPL notice section via a "LGPL-2.1 全文" link that opens a license-detail-style screen. The bundled text MUST match the upstream FSF text byte-for-byte; CI MUST verify the asset checksum against a committed expected SHA-256.

#### Scenario: License text is reachable from the notice section

- **WHEN** the user taps the "LGPL-2.1 全文" link
- **THEN** a screen renders the contents of `assets/legal/LGPL-2.1.txt` in a `SelectableText` widget

#### Scenario: License asset integrity is verified in CI

- **WHEN** the CI runs the asset-integrity check
- **THEN** the SHA-256 of `app/assets/legal/LGPL-2.1.txt` matches the value committed in `app/assets/legal/checksums.txt` and the build fails otherwise

### Requirement: iOS and iPadOS platform work requires a media-engine distribution ADR

Before any `add-platform-ios` or iPadOS implementation begins, the repository SHALL include an accepted ADR that decides how GeekPlayer handles libmpv/media_kit, LGPL obligations, and non-store distribution on iOS/iPadOS.

#### Scenario: iOS platform proposal checks ADR

- **WHEN** a developer proposes iOS or iPadOS support
- **THEN** the proposal references the accepted media-engine distribution ADR and follows its selected option

### Requirement: iOS platform libmpv replacement path is documented

The per-platform libmpv replacement instructions (in both `THIRD_PARTY_NOTICES.md` and the in-app LGPL notice section) MUST cover iOS in addition to the existing macOS, Windows, and Android entries. The iOS instructions MUST specify the in-bundle location of the libmpv framework, that the app must be re-signed after replacement (Ad Hoc or developer signing), and that this applies to non-App-Store distribution only (per ADR-0006).

#### Scenario: iOS replacement path is documented in THIRD_PARTY_NOTICES

- **WHEN** `THIRD_PARTY_NOTICES.md` is rendered
- **THEN** the iOS instructions reference the path `Frameworks/` inside the `.app` bundle as the location of the libmpv framework, and note that re-signing is required after replacement

#### Scenario: iOS replacement path is visible in app LGPL notice

- **WHEN** the LGPL notice section is rendered in the app
- **THEN** the per-platform replacement instructions include an iOS entry referencing the framework location inside the app bundle


## ADDED Requirements

### Requirement: OSS license collection is automated at build time

The system SHALL collect license metadata for every Dart package in `app/pubspec.yaml` using `flutter_oss_licenses`. The generator MUST emit a Dart source file at `app/lib/oss_licenses.dart` that is committed to the repository. The CI build MUST verify that re-running the generator produces no diff against the committed file.

#### Scenario: Adding a new dependency requires regeneration

- **GIVEN** a contributor adds a new dependency `foo: ^1.0.0` to `app/pubspec.yaml`
- **WHEN** the CI build runs without first regenerating `lib/oss_licenses.dart`
- **THEN** the regeneration verification step fails with a non-zero exit code and prints the missing package name

#### Scenario: Committed license data drives the UI

- **WHEN** the app is launched and the License list screen is opened
- **THEN** every package listed in `lib/oss_licenses.dart` is rendered as a tappable list entry showing the package name and version

### Requirement: License list screen displays all dependencies

The system SHALL provide a `LicenseListScreen` at `app/lib/features/about/presentation/license_screen.dart` that lists every dependency from the generated license data, sorted alphabetically by package name. The list MUST be scrollable and MUST not paginate. Tapping an entry MUST open a `LicenseDetailScreen` that displays the package name, version, and full license text using `SelectableText` so users can copy the content.

#### Scenario: User views the license body for a single package

- **WHEN** the user taps the list entry for `media_kit`
- **THEN** the `LicenseDetailScreen` opens and displays the MIT license body for the installed version of `media_kit` in a `SelectableText` widget

#### Scenario: License text preserves the original language

- **WHEN** any license body is displayed
- **THEN** the original English (or the upstream-author-provided) license text is shown verbatim without translation

### Requirement: Apache-2.0 NOTICE section for GeekPlayer

The system SHALL display an Apache-2.0 NOTICE section on the License list screen showing the copyright line `Copyright 2026 GeekPlayer Contributors` and a tappable link to the full LICENSE file (bundled as an asset under `app/assets/legal/LICENSE`). The section MUST be visually distinct from the dependency list.

#### Scenario: NOTICE section is always visible on the license screen

- **WHEN** the License list screen is opened
- **THEN** the Apache-2.0 NOTICE section is rendered above the dependency list, contains the literal copyright line, and includes a "ライセンス全文" link that opens the bundled `LICENSE` text in a `LicenseDetailScreen`-style view

### Requirement: License repository abstracts the generated data

The system SHALL provide an `OssLicenseRepository` at `app/lib/features/about/data/oss_license_repository.dart` that returns an immutable list of `LicenseEntry` value objects (defined at `app/lib/features/about/domain/license_entry.dart`) for UI consumption. The UI layer MUST NOT import `oss_licenses.dart` directly; it MUST go through the repository.

#### Scenario: UI receives sorted entries

- **WHEN** the License list screen reads from `OssLicenseRepository.fetchEntries()`
- **THEN** the returned list is sorted ascending by `name`, contains no duplicates, and every entry has a non-empty `licenseText` field

# about-screen Specification

## Purpose
TBD - created by archiving change add-about-and-licenses. Update Purpose after archive.
## Requirements
### Requirement: About screen displays application identity

The system SHALL provide an `AboutScreen` at `app/lib/features/about/presentation/about_screen.dart` that displays the application name, version, build number, and commit SHA. The application name, version, and build number MUST be obtained at runtime via `package_info_plus`. The commit SHA MUST be obtained from a Dart compile-time environment variable `GIT_SHA` (passed via `--dart-define=GIT_SHA=...`). When `GIT_SHA` is not provided, the screen MUST display the literal text `(dev build)` in place of the SHA.

#### Scenario: Release build shows production metadata

- **GIVEN** the app is launched from a release build compiled with `--dart-define=GIT_SHA=abc1234` and `package_info_plus` returns `version=0.1.0`, `buildNumber=12`
- **WHEN** the user navigates to the About screen
- **THEN** the screen displays "GeekPlayer", "0.1.0", "12", and "abc1234" within 200ms of the screen first appearing

#### Scenario: Dev build falls back to `(dev build)`

- **GIVEN** the app is launched without `--dart-define=GIT_SHA`
- **WHEN** the user navigates to the About screen
- **THEN** the commit SHA field shows the literal text `(dev build)` and no error is logged

#### Scenario: Version retrieval failure does not crash the screen

- **WHEN** `package_info_plus` throws or returns an empty `version` string
- **THEN** the About screen still renders with placeholder values `"-"` for the missing fields and the rest of the screen remains interactive

### Requirement: About screen provides external links

The About screen SHALL display tappable links to the GitHub repository, the Roadmap document, and the full license document. Each link MUST open in the OS default browser via `url_launcher` in `LaunchMode.externalApplication`. No in-app WebView SHALL be embedded.

#### Scenario: User taps the GitHub link

- **WHEN** the user taps the "GitHub リポジトリ" link
- **THEN** the OS default browser opens the URL `https://github.com/geekjapan/GeekPlayer` and the About screen remains on the navigation stack

#### Scenario: External app launch failure is reported

- **WHEN** `url_launcher` reports that no app can handle `https` URLs
- **THEN** a SnackBar with the message "リンクを開けませんでした" is shown and no exception propagates to the UI tree

### Requirement: Navigation entry point from home screen

The system SHALL provide a navigation entry point from `HomeScreen` (`app/lib/main.dart`) to the About screen. The entry point MUST be a recognizable icon button (e.g., info icon) in the home screen's AppBar. The entry point is provisional and SHALL be replaced when the `add-app-settings` change introduces a settings screen.

#### Scenario: Home screen exposes an info icon

- **WHEN** the home screen is displayed
- **THEN** the AppBar contains an icon button with semantic label "アプリ情報" that navigates to the About screen on tap

### Requirement: ja-first copy in About screen

All user-visible copy on the About screen SHALL be Japanese. Identifiers and version strings remain machine-formatted. English localization is deferred to v0.2 via `intl` ARB files.

#### Scenario: Section headings render in Japanese

- **WHEN** the About screen is displayed
- **THEN** the section headings include literal strings such as "バージョン", "ビルド番号", "コミット" rendered in Japanese


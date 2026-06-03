# local-book-reader Specification

## Purpose

Defines the Book Reader experience for locally opened PDF and EPUB files: opening files through the OS picker, navigating and resuming reading position, and recovering gracefully when a previously opened file is missing.

## Requirements

### Requirement: User can open PDF and EPUB files

The system SHALL allow the user to choose a local `.pdf` or `.epub` file from the OS file picker and open it in a Book Reader screen. Unsupported extensions MUST be rejected with an `UnsupportedFormatError`.

#### Scenario: PDF file opens

- **WHEN** the user selects a readable `.pdf` file
- **THEN** the Book Reader screen opens and renders the first page or last saved position

#### Scenario: EPUB file opens

- **WHEN** the user selects a readable `.epub` file
- **THEN** the Book Reader screen opens and renders the first chapter or last saved position

#### Scenario: Unsupported file is rejected

- **WHEN** the user selects a `.cbz` file from the book picker
- **THEN** the app shows an `UnsupportedFormatError` and does not open the Book Reader screen

### Requirement: Reader navigation and resume

The Book Reader SHALL support forward/back navigation, direct progress changes where the format supports it, and automatic resume from the last saved `PagePosition`.

#### Scenario: Reader resumes saved PDF page

- **GIVEN** the user previously closed a PDF on page 12
- **WHEN** the same PDF is opened again
- **THEN** the reader restores page 12 before user interaction

#### Scenario: Reader resumes saved EPUB location

- **GIVEN** the user previously closed an EPUB at chapter 3 with scroll fraction 0.5
- **WHEN** the same EPUB is opened again
- **THEN** the reader restores chapter 3 near the saved scroll fraction

### Requirement: Missing local file is recoverable

If a previously opened book file no longer exists at its stored URI, the system SHALL keep the metadata entry and show a recoverable file-not-found error with an option to remove the entry.

#### Scenario: Missing book does not crash

- **GIVEN** a book metadata entry exists but the file was deleted outside the app
- **WHEN** the user opens that book from the recent list
- **THEN** the reader is not opened, a file-not-found message is shown, and the user can remove the stale entry

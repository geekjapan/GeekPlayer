/// Compile-time feature flags.
///
/// These are intentionally `const bool` (NOT runtime settings) so the
/// dead-code elimination pass can strip the entire site-specific tree
/// when a flag is set to `false`. This is the kill-switch path required
/// by the `kakuyomu-resilience` spec ("Kill-switch path for ToS
/// escalation"): a release built with `kakuyomuEnabled = false` MUST
/// not register `KakuyomuNovelRepository` with any provider.
///
/// To disable a site, set the flag to `false` and cut a hotfix release.
library;

/// Master switch for the entire カクヨム feature surface.
///
/// When `false`:
///   - `KakuyomuNovelRepository` is NOT instantiated (provider returns
///     `null` / throws unsupported).
///   - All Kakuyomu UI entry points (home section tab, search, ranking,
///     latest, work detail, reader) are hidden.
///   - On app launch, the user is prompted to delete any previously
///     cached Kakuyomu episode bodies (`LibraryRepository.purgeBySite`).
const bool kakuyomuEnabled = true;

/// Current shipping policy version string stored on each
/// `site_consents` row.
///
/// Value tied to ADR-0001 / ADR-0003 acceptance date (2026-05-27). When
/// the responsible-fetching ADR is materially revised, bump this string
/// so the `ConsentDialog` re-prompts users (`site-consent` spec,
/// Requirement "Policy version tracking").
const String kPolicyVersion = '2026-05-27';

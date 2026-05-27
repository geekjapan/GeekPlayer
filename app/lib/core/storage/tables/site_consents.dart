import 'package:drift/drift.dart';

/// drift v2 schema: per-site responsible-fetching consent record.
///
/// Primary key `{site}`. `policyVersion` stores the ADR-0001 / ADR-0003
/// version the user agreed to (design.md D7, Q-D3). Bumping
/// `kPolicyVersion` re-prompts existing users via the
/// `hasFreshConsent(Site, currentVersion)` helper.
///
/// A row with `granted = false` represents an explicit refusal — the
/// `ConsentGuardedRepository` decorator throws `SiteConsentRequiredError`
/// before any network call for such sites.
@DataClassName('SiteConsentRow')
class SiteConsents extends Table {
  TextColumn get site => text()();
  BoolColumn get granted => boolean()();
  DateTimeColumn get decidedAt => dateTime()();
  TextColumn get policyVersion => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{site};
}

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/novel/models/site.dart';
import '../../../core/novel/policy_version.dart';
import '../../../core/storage/database.dart';
import '../../../core/storage/providers.dart';

part 'consent_repository.g.dart';

/// Thin wrapper over [SiteConsentsDao] that speaks in domain [Site]
/// values rather than raw strings.
///
/// Owns the policy-version comparison (`hasFreshConsent`) and the
/// "grant all / deny all" bulk paths used by [ConsentDialog]
/// (`features/novel/presentation/consent_dialog.dart`).
class ConsentRepository {
  ConsentRepository(this._dao);

  final SiteConsentsDao _dao;

  /// True iff [site] has an explicit `granted=true` row whose
  /// `policyVersion` equals the currently shipping [kPolicyVersion].
  ///
  /// Returning `false` for "no row" / "granted=false" / "stale policy"
  /// lets callers re-prompt with a single predicate (spec
  /// `site-consent` "Policy version tracking").
  Future<bool> hasFreshConsent(Site site) {
    return _dao.hasFreshConsent(site.code, kPolicyVersion);
  }

  /// True iff EVERY supported site has a fresh consent decision (either
  /// granted=true OR granted=false, both with the current policyVersion).
  ///
  /// Used by the startup hook to decide whether to show the
  /// [ConsentDialog]: only the absence of a decision triggers it, an
  /// explicit "all denied" counts as decided.
  Future<bool> hasAnyDecisionForAllSites() async {
    final List<SiteConsentRow> rows = await _dao.getAll();
    if (rows.length < Site.values.length) return false;
    for (final SiteConsentRow row in rows) {
      if (row.policyVersion != kPolicyVersion) return false;
    }
    // All three sites must be represented.
    final Set<String> seen = rows.map((SiteConsentRow r) => r.site).toSet();
    for (final Site s in Site.values) {
      if (!seen.contains(s.code)) return false;
    }
    return true;
  }

  Future<void> grant(Site site) {
    return _dao.setConsent(
      site: site.code,
      granted: true,
      policyVersion: kPolicyVersion,
    );
  }

  Future<void> revoke(Site site) {
    return _dao.setConsent(
      site: site.code,
      granted: false,
      policyVersion: kPolicyVersion,
    );
  }

  /// Bulk "decision" path used by [ConsentDialog]: write one row per
  /// supported site reflecting the user's choices, all stamped with
  /// the current `policyVersion`.
  Future<void> saveDecisions(Map<Site, bool> decisions) async {
    for (final Site s in Site.values) {
      final bool granted = decisions[s] ?? false;
      await _dao.setConsent(
        site: s.code,
        granted: granted,
        policyVersion: kPolicyVersion,
      );
    }
  }

  Future<Map<Site, SiteConsentRow>> getAll() async {
    final List<SiteConsentRow> rows = await _dao.getAll();
    final Map<Site, SiteConsentRow> out = <Site, SiteConsentRow>{};
    for (final SiteConsentRow r in rows) {
      final Site? s = Site.fromCode(r.site);
      if (s != null) out[s] = r;
    }
    return out;
  }
}

@Riverpod(keepAlive: true)
ConsentRepository consentRepository(Ref ref) {
  return ConsentRepository(ref.watch(siteConsentsDaoProvider));
}

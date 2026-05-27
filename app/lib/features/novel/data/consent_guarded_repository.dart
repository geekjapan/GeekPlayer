import 'dart:async';

import '../../../core/novel/errors.dart';
import '../../../core/novel/models/episode.dart';
import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work.dart';
import '../../../core/novel/models/work_id.dart';
import '../../../core/novel/models/work_query.dart';
import '../../../core/novel/novel_repository.dart';
import 'consent_repository.dart';

/// Decorator that gates every call on [NovelRepository] through
/// [ConsentRepository.hasFreshConsent].
///
/// Spec `site-consent` "Consent enforcement at the repository layer":
/// if the consent for the target [Site] is missing or `granted=false`,
/// the call MUST throw [SiteConsentRequiredError] before any network
/// request is dispatched. Because the underlying check is an async DB
/// read, we await it as the first step of each method — no HTTP work
/// happens before that future completes.
class ConsentGuardedRepository implements NovelRepository {
  ConsentGuardedRepository({
    required NovelRepository inner,
    required ConsentRepository consent,
  }) : _inner = inner, // ignore: prefer_initializing_formals
       _consent = consent; // ignore: prefer_initializing_formals

  final NovelRepository _inner;
  final ConsentRepository _consent;

  @override
  Site get site => _inner.site;

  Future<void> _check() async {
    final bool ok = await _consent.hasFreshConsent(_inner.site);
    if (!ok) {
      throw SiteConsentRequiredError(
        '${_inner.site.code} site consent required',
        site: _inner.site,
      );
    }
  }

  @override
  Future<List<Work>> searchWorks(WorkQuery query) async {
    await _check();
    return _inner.searchWorks(query);
  }

  @override
  Future<Work> fetchWork(WorkId id) async {
    await _check();
    return _inner.fetchWork(id);
  }

  @override
  Stream<Episode> fetchEpisodes(WorkId workId) async* {
    await _check();
    yield* _inner.fetchEpisodes(workId);
  }

  @override
  Future<EpisodeBody> fetchEpisodeBody(
    WorkId workId,
    EpisodeId episodeId,
  ) async {
    await _check();
    return _inner.fetchEpisodeBody(workId, episodeId);
  }
}

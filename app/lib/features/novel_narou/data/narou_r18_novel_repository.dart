import 'dart:async';

import '../../../core/novel/models/episode.dart';
import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work.dart';
import '../../../core/novel/models/work_id.dart';
import '../../../core/novel/models/work_query.dart';
import '../../../core/novel/novel_repository.dart';
import '../../novel/data/consent_repository.dart';
import '../domain/narou_work_query.dart';
import 'narou_api_client.dart';
import 'narou_episode_fetcher.dart';
import 'narou_novel_repository.dart';

/// ノクターン系統（`novel18.syosetu.com` 系）向けの [NovelRepository]。
///
/// 取り扱い特殊事項:
///   1. **同意必須**: コンストラクタ `assertConsent` で `Site.noc` の
///      `hasFreshConsent` を `false` と判定した場合 `StateError` を投げる
///      （仕様 `r18-age-gate`: "Construction without consent throws"）。
///   2. **revoke 反応**: `ConsentRepository` を購読し、同意が落とされた
///      瞬間に内部の `_disposed` フラグを立て、以降のメソッド呼び出しを
///      すべて `StateError` 化する。
///
/// 注意: 本クラスは "同意済みフラグ" を呼び出し時点でも確認する。実 DB
/// 検証は同期的に行えないため、コンストラクタ段階の事前検証 +
/// 監視ストリームによる事後 invalidation の二段構えで防御する。
class NarouR18NovelRepository implements NovelRepository {
  NarouR18NovelRepository._({
    required NarouApiClient apiClient,
    required NarouEpisodeFetcher episodeFetcher,
    required ConsentRepository consentRepository,
    required Stream<bool> consentStream,
  }) : _delegate = NarouNovelRepository(
         apiClient: apiClient,
         episodeFetcher: episodeFetcher,
       ),
       _consent = consentRepository {
    _subscription = consentStream.listen((bool granted) {
      if (!granted) _disposed = true;
    });
  }

  /// ファクトリ: 同意確認を `await` してから安全に new する。
  /// 未同意 → [StateError]。
  static Future<NarouR18NovelRepository> create({
    required NarouApiClient apiClient,
    required NarouEpisodeFetcher episodeFetcher,
    required ConsentRepository consentRepository,
    required Stream<bool> consentStream,
  }) async {
    final bool ok = await consentRepository.hasFreshConsent(Site.noc);
    if (!ok) {
      throw StateError(
        'NarouR18NovelRepository requires SiteConsent for Site.noc '
        '(age-verified) before instantiation',
      );
    }
    return NarouR18NovelRepository._(
      apiClient: apiClient,
      episodeFetcher: episodeFetcher,
      consentRepository: consentRepository,
      consentStream: consentStream,
    );
  }

  final NarouNovelRepository _delegate;
  // ignore: unused_field
  final ConsentRepository _consent;
  late final StreamSubscription<bool> _subscription;
  bool _disposed = false;

  /// 既存インスタンス側で外部から `Stream<bool>` の更新が来ない場合のため
  /// に、テスト用 / 明示的な再検証ポイント。
  Future<void> reverifyConsent() async {
    final bool ok = await _consent.hasFreshConsent(Site.noc);
    if (!ok) _disposed = true;
  }

  void _ensureLive() {
    if (_disposed) {
      throw StateError(
        'NarouR18NovelRepository has been invalidated '
        '(SiteConsent for Site.noc was revoked)',
      );
    }
  }

  @override
  Site get site => Site.noc;

  @override
  Future<List<Work>> searchWorks(WorkQuery query) {
    _ensureLive();
    // 一般版と同じ delegate を使うが site を Site.noc で上書きする必要は
    // ない。NarouApiClient コンストラクタで `site: Site.noc` を渡しているから。
    final WorkQuery normalized = query is NarouSearchOptions
        ? query.copyWith(site: Site.noc)
        : NarouSearchOptions(
            site: Site.noc,
            keyword: query.keyword,
            limit: query.limit,
            offset: query.offset,
          );
    return _delegate.searchWorks(normalized);
  }

  @override
  Future<Work> fetchWork(WorkId id) {
    _ensureLive();
    final WorkId nocId = id.site == Site.noc
        ? id
        : WorkId(site: Site.noc, externalId: id.externalId);
    return _delegate.fetchWork(nocId);
  }

  @override
  Stream<Episode> fetchEpisodes(WorkId workId) {
    _ensureLive();
    final WorkId nocId = workId.site == Site.noc
        ? workId
        : WorkId(site: Site.noc, externalId: workId.externalId);
    return _delegate.fetchEpisodes(nocId);
  }

  @override
  Future<EpisodeBody> fetchEpisodeBody(WorkId workId, EpisodeId episodeId) {
    _ensureLive();
    final WorkId nocId = workId.site == Site.noc
        ? workId
        : WorkId(site: Site.noc, externalId: workId.externalId);
    return _delegate.fetchEpisodeBody(nocId, episodeId);
  }

  /// 主に Riverpod の `ref.onDispose` から呼ばれることを想定。
  Future<void> dispose() async {
    await _subscription.cancel();
    _disposed = true;
  }
}

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:webfeed_revised/webfeed_revised.dart';

import '../domain/exceptions.dart';
import '../domain/kakuyomu_feed_item.dart';
import '../domain/kakuyomu_search_query.dart';

/// Period selector for the Kakuyomu official ranking RSS endpoints.
enum KakuyomuRankingPeriod { daily, weekly, monthly, cumulative }

/// Source backed by Kakuyomu's official RSS / Atom feeds.
///
/// Handles search (`/search?q=...&format=rss`), the latest feed, the
/// ranking feeds (daily / weekly / monthly / cumulative), and the
/// per-work update notification feed. Endpoint formats are taken from
/// the public RSS schema published on kakuyomu.jp; see
/// `proposal.md` §What Changes for the schema reference.
///
/// Parser strategy: each entry is converted to a [KakuyomuFeedItem]
/// inside an item-level `try / catch`. A malformed item is skipped and
/// logged at WARN; the rest of the feed continues to be emitted. This
/// satisfies the `kakuyomu-novel-source` spec scenario "One malformed
/// item does not abort the feed".
class KakuyomuRssSource {
  KakuyomuRssSource({required Dio dio, Logger? logger})
      : _dio = dio, // ignore: prefer_initializing_formals
        _logger = logger ?? Logger();

  final Dio _dio;
  final Logger _logger;

  static const String _baseHost = 'https://kakuyomu.jp';

  /// Search the public Kakuyomu search RSS endpoint.
  Future<List<KakuyomuFeedItem>> search(KakuyomuSearchQuery query) async {
    final Map<String, String> params = query.toQueryParameters();
    return _fetchAndParse(
      Uri.parse('$_baseHost/search').replace(queryParameters: <String, String>{
        ...params,
        'format': 'rss',
      }).toString(),
    );
  }

  /// Newest published works feed.
  Future<List<KakuyomuFeedItem>> latest() {
    return _fetchAndParse('$_baseHost/rss/latest');
  }

  /// Ranking feed for the given [period].
  Future<List<KakuyomuFeedItem>> ranking(KakuyomuRankingPeriod period) {
    final String slug = switch (period) {
      KakuyomuRankingPeriod.daily => 'daily',
      KakuyomuRankingPeriod.weekly => 'weekly',
      KakuyomuRankingPeriod.monthly => 'monthly',
      KakuyomuRankingPeriod.cumulative => 'entire',
    };
    return _fetchAndParse('$_baseHost/rss/ranking/$slug');
  }

  /// Updates feed for a single work (id is the Kakuyomu numeric work id).
  Future<List<KakuyomuFeedItem>> workUpdates(String workId) {
    return _fetchAndParse('$_baseHost/works/$workId/episodes.atom');
  }

  /// Internal: fetch a URL, sniff RSS vs Atom via Content-Type and
  /// document shape, then normalize to [KakuyomuFeedItem]s.
  ///
  /// Per-item failures are logged and skipped (best-effort).
  Future<List<KakuyomuFeedItem>> _fetchAndParse(String url) async {
    try {
      final Response<String> resp = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final String? body = resp.data;
      if (body == null || body.isEmpty) {
        throw KakuyomuParseException(
          message: 'empty body for $url',
          selector: '<root>',
          url: url,
        );
      }
      final String? contentType = resp.headers.value('content-type');
      return parseFeedBody(body, contentType: contentType, logger: _logger);
    } on DioException catch (e) {
      throw KakuyomuUpstreamUnavailableException(
        message: 'failed to fetch $url: ${e.message ?? e.type.name}',
        lastStatus: e.response?.statusCode,
      );
    }
  }
}

/// Pure parser entry point — used by [KakuyomuRssSource] and by the
/// snapshot tests (which feed it captured fixtures directly).
List<KakuyomuFeedItem> parseFeedBody(
  String body, {
  String? contentType,
  Logger? logger,
}) {
  final Logger log = logger ?? Logger();
  final String ct = (contentType ?? '').toLowerCase();
  final bool atomByHint = ct.contains('atom') || body.contains('<feed');
  if (atomByHint) {
    final AtomFeed feed = AtomFeed.parse(body);
    return _itemsFromAtom(feed, log);
  }
  final RssFeed feed = RssFeed.parse(body);
  return _itemsFromRss(feed, log);
}

List<KakuyomuFeedItem> _itemsFromRss(RssFeed feed, Logger log) {
  final List<KakuyomuFeedItem> out = <KakuyomuFeedItem>[];
  final List<RssItem> items = feed.items ?? <RssItem>[];
  for (final RssItem item in items) {
    try {
      final String? link = item.link;
      if (link == null || link.isEmpty) {
        log.w('KakuyomuRssSource: skipping item without <link>');
        continue;
      }
      out.add(
        KakuyomuFeedItem(
          title: item.title ?? '',
          workId: extractWorkIdFromUrl(link),
          url: link,
          author: item.dc?.creator ?? item.author,
          publishedAt: item.pubDate,
          summary: item.description,
        ),
      );
    } catch (e, st) {
      log.w('KakuyomuRssSource: dropping malformed item: $e\n$st');
    }
  }
  return out;
}

List<KakuyomuFeedItem> _itemsFromAtom(AtomFeed feed, Logger log) {
  final List<KakuyomuFeedItem> out = <KakuyomuFeedItem>[];
  final List<AtomItem> items = feed.items ?? <AtomItem>[];
  for (final AtomItem item in items) {
    try {
      final List<AtomLink> links = item.links ?? <AtomLink>[];
      String? link;
      for (final AtomLink l in links) {
        if (l.href != null && l.href!.isNotEmpty) {
          link = l.href;
          break;
        }
      }
      if (link == null) {
        log.w('KakuyomuRssSource: skipping atom entry without href');
        continue;
      }
      out.add(
        KakuyomuFeedItem(
          title: item.title ?? '',
          workId: extractWorkIdFromUrl(link),
          url: link,
          author:
              (item.authors != null && item.authors!.isNotEmpty)
                  ? item.authors!.first.name
                  : null,
          publishedAt: _tryParseDate(item.published) ?? item.updated,
          summary: item.summary ?? item.content,
        ),
      );
    } catch (e, st) {
      log.w('KakuyomuRssSource: dropping malformed atom entry: $e\n$st');
    }
  }
  return out;
}

DateTime? _tryParseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
}

/// Parse `https://kakuyomu.jp/works/{id}` (with or without trailing
/// segments) and return the numeric `id` portion. Returns an empty
/// string if the URL does not match the expected pattern.
String extractWorkIdFromUrl(String url) {
  try {
    final Uri uri = Uri.parse(url);
    final List<String> segs = uri.pathSegments;
    final int worksIdx = segs.indexOf('works');
    if (worksIdx >= 0 && worksIdx + 1 < segs.length) {
      return segs[worksIdx + 1];
    }
  } catch (_) {
    // fall through
  }
  return '';
}

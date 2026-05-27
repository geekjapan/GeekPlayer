import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../domain/exceptions.dart';
import '../domain/kakuyomu_episode.dart';
import '../domain/kakuyomu_work.dart';
import '../domain/reader_segment.dart';

/// CSS selectors used by [KakuyomuHtmlParser].
///
/// Collected here as `const` strings so grep-based maintenance is cheap
/// when Kakuyomu HTML shifts and the snapshot tests fail with an
/// "unexpected selector" diff. If you change any value below, also
/// regenerate the goldens in `app/test/fixtures/kakuyomu/html/`.
const String _selWorkTitle = 'h1#workTitle';
const String _selWorkAuthor = '#workAuthor-activityName';
const String _selWorkSynopsis = '#introduction';
const String _selWorkTag = '#workMeta-tags a';
const String _selWorkLastUpdated = 'time[itemprop="dateModified"]';
const String _selEpisodeListItem = '.widget-toc-episode';
const String _selEpisodeAnchor = 'a';
const String _selEpisodeTime = 'time';
const String _selEpisodeTitle = '#workTitle';
const String _selEpisodeBody = '.widget-episodeBody';
const String _selEpisodeBodyParagraphs = 'p';

/// Pure HTML parser for Kakuyomu work and episode pages.
///
/// Lives in its own file so the snapshot tests can exercise it in
/// isolation (no Dio dependency). `KakuyomuHtmlSource` calls into this
/// class and wraps parser failures in [KakuyomuParseException].
class KakuyomuHtmlParser {
  const KakuyomuHtmlParser();

  /// Parse a Kakuyomu work-detail page (`/works/{id}`).
  ///
  /// [workId] is the numeric id of the work being parsed; we use it
  /// when extracting episode anchors so a missing episode id can be
  /// reported via [KakuyomuParseException] with the right context.
  KakuyomuWorkDetail parseWorkPage(String html, {required String workId}) {
    final Document doc = html_parser.parse(html);

    String text(String sel) {
      final Element? el = doc.querySelector(sel);
      if (el == null) {
        throw KakuyomuParseException(
          message: 'missing required element',
          selector: sel,
          url: 'https://kakuyomu.jp/works/$workId',
        );
      }
      return el.text.trim();
    }

    final String title = text(_selWorkTitle);
    final String author = text(_selWorkAuthor);
    final String synopsis =
        doc.querySelector(_selWorkSynopsis)?.text.trim() ?? '';
    final List<String> tags = doc
        .querySelectorAll(_selWorkTag)
        .map((Element e) => e.text.trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);

    final DateTime? lastUpdatedAt = _parseDate(
      doc.querySelector(_selWorkLastUpdated)?.attributes['datetime'],
    );

    final List<KakuyomuEpisodeSummary> episodes = <KakuyomuEpisodeSummary>[];
    for (final Element item in doc.querySelectorAll(_selEpisodeListItem)) {
      final Element? a = item.querySelector(_selEpisodeAnchor);
      if (a == null) continue;
      final String? href = a.attributes['href'];
      if (href == null || !href.contains('/episodes/')) continue;
      final RegExpMatch? m = RegExp(r'/episodes/(\d+)').firstMatch(href);
      if (m == null) continue;
      final String epId = m.group(1)!;
      final String epTitle = a.text.trim();
      final DateTime? publishedAt = _parseDate(
        item.querySelector(_selEpisodeTime)?.attributes['datetime'],
      );
      episodes.add(
        KakuyomuEpisodeSummary(
          id: epId,
          title: epTitle,
          publishedAt: publishedAt,
        ),
      );
    }

    return KakuyomuWorkDetail(
      id: workId,
      title: title,
      author: author,
      synopsis: synopsis,
      tags: tags,
      episodes: episodes,
      lastUpdatedAt: lastUpdatedAt,
    );
  }

  /// Parse a Kakuyomu episode page (`/works/{wid}/episodes/{eid}`).
  KakuyomuEpisodeBody parseEpisodePage(
    String html, {
    required String workId,
    required String episodeId,
  }) {
    final Document doc = html_parser.parse(html);
    final String url = 'https://kakuyomu.jp/works/$workId/episodes/$episodeId';

    final String title = doc.querySelector(_selEpisodeTitle)?.text.trim() ?? '';

    final Element? bodyEl = doc.querySelector(_selEpisodeBody);
    if (bodyEl == null) {
      throw KakuyomuParseException(
        message: 'missing episode body container',
        selector: _selEpisodeBody,
        url: url,
      );
    }

    final List<ReaderSegment> segs = <ReaderSegment>[];
    for (final Element p in bodyEl.querySelectorAll(
      _selEpisodeBodyParagraphs,
    )) {
      final ReaderSegment seg = _paragraphToSegment(p);
      segs.add(seg);
    }

    return KakuyomuEpisodeBody(id: episodeId, title: title, paragraphs: segs);
  }

  ReaderSegment _paragraphToSegment(Element p) {
    // Empty paragraph → blank line. Kakuyomu uses <p><br></p> for
    // visual blank lines too — treat those as blank.
    final String fullText = p.text.trim();
    final bool hasRuby = p.querySelector('ruby') != null;
    if (!hasRuby) {
      if (fullText.isEmpty) return const BlankLineSegment();
      return ParagraphSegment(fullText);
    }

    // Walk children and flatten into a sequence of TextRun / RubyPair.
    final List<RubyRun> runs = <RubyRun>[];
    final StringBuffer pending = StringBuffer();
    void flushText() {
      if (pending.isNotEmpty) {
        runs.add(TextRun(pending.toString()));
        pending.clear();
      }
    }

    for (final Node n in p.nodes) {
      if (n is Text) {
        pending.write(n.text);
      } else if (n is Element) {
        if (n.localName == 'ruby') {
          flushText();
          final String base = n.nodes
              .where(
                (Node x) =>
                    x is Text ||
                    (x is Element &&
                        x.localName != 'rt' &&
                        x.localName != 'rp'),
              )
              .map((Node x) => x.text ?? '')
              .join();
          final String reading = n.querySelector('rt')?.text.trim() ?? '';
          runs.add(RubyPair(base: base.trim(), reading: reading));
        } else if (n.localName == 'br') {
          // ignore inline <br> inside a paragraph (treat as space).
          pending.write(' ');
        } else {
          pending.write(n.text);
        }
      }
    }
    flushText();
    if (runs.isEmpty) return const BlankLineSegment();
    return RubyParagraphSegment(runs);
  }
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
}

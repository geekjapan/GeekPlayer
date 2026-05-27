import 'package:flutter/foundation.dart';

import 'site.dart';

/// Lightweight search / listing parameters consumed by site-specific
/// `NovelRepository` implementations.
///
/// v0.1 covers a minimal subset that lets us issue "list latest works"
/// and "filter by author / keyword" calls. Site-specific extensions
/// (e.g. なろう公式 API's `genre`, `nocgenre`, `keyword`) are not
/// represented here — those subclasses MAY accept additional named
/// parameters via their own typed configuration objects.
@immutable
class WorkQuery {
  const WorkQuery({
    required this.site,
    this.keyword,
    this.limit = 20,
    this.offset = 0,
  });

  final Site site;
  final String? keyword;
  final int limit;
  final int offset;

  WorkQuery copyWith({
    Site? site,
    String? keyword,
    int? limit,
    int? offset,
  }) {
    return WorkQuery(
      site: site ?? this.site,
      keyword: keyword ?? this.keyword,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkQuery &&
        other.site == site &&
        other.keyword == keyword &&
        other.limit == limit &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(site, keyword, limit, offset);

  @override
  String toString() =>
      'WorkQuery(${site.code}, keyword=$keyword, limit=$limit, offset=$offset)';
}

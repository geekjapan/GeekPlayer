import 'package:flutter/foundation.dart';

import 'site.dart';

/// Composite primary key for `novel_works`: `(site, externalId)`.
///
/// `externalId` is the site-side identifier: a `Ncode` for narou /
/// noc (e.g. `n9669bk`) or a kakuyomu work id (numeric string).
/// Structural equality lets `WorkId` be used as a Map key and inside
/// Riverpod `.family` providers.
@immutable
class WorkId {
  const WorkId({required this.site, required this.externalId});

  final Site site;
  final String externalId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkId &&
        other.site == site &&
        other.externalId == externalId;
  }

  @override
  int get hashCode => Object.hash(site, externalId);

  @override
  String toString() => 'WorkId(${site.code}:$externalId)';
}

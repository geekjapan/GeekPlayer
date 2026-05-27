import 'package:flutter/foundation.dart';

import '../../../core/novel/models/episode.dart';

/// なろう側で取得した 1 話分のメタデータ（本文は含まない）。
///
/// 共通 [Episode] と 1:1 に対応するが、なろう固有の "サブタイトル"
/// (`subtitle`) と "更新日" (`updateAt`) を追加で保持する。
@immutable
class NarouEpisode {
  const NarouEpisode({
    required this.index,
    required this.subtitle,
    this.updateAt,
  });

  /// 1-based エピソード番号。
  final int index;

  /// サブタイトル（タイトル文字列）。
  final String subtitle;

  /// 各話の更新日時。null = HTML から取得できなかった。
  final DateTime? updateAt;

  /// 共通 [Episode] への変換。
  Episode toEpisode() {
    return Episode(id: EpisodeId(index), title: subtitle);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NarouEpisode &&
        other.index == index &&
        other.subtitle == subtitle &&
        other.updateAt == updateAt;
  }

  @override
  int get hashCode => Object.hash(index, subtitle, updateAt);

  @override
  String toString() => 'NarouEpisode($index, "$subtitle")';
}

/// 検索 / mapper エラー型。`narou-novel-source` spec
/// "Defensive mapping" の `NarouResponseError` に対応する。
class NarouResponseError implements Exception {
  NarouResponseError(this.message, {this.entryIndex});

  final String message;
  final int? entryIndex;

  @override
  String toString() =>
      'NarouResponseError(entryIndex=$entryIndex): $message';
}

import 'package:flutter/foundation.dart';

import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work_query.dart';
import 'narou_genre.dart';

/// なろう公式 API (`novelapi` / `novel18api`) 検索のパラメタを表す
/// `WorkQuery` のサブクラス。
///
/// 共通 `WorkQuery` の `keyword` / `limit` / `offset` に加えて、
/// なろう固有のフィルタを保持する。`add-online-novel-library` の
/// `WorkQuery` がまだ `extensions` フィールドを公開していないため、
/// design.md D5 の代替として **サブクラス継承**を採用する
/// (tasks.md 2.3 が明示)。
///
/// 各フィールドは optional。何も指定しなければ「keyword だけで検索」
/// が成立する。`toQueryParameters()` は `Map<String, String>` を
/// **安定順序**（キー昇順）で返す — テスト容易性と URL キャッシュキー
/// の安定性のため。
@immutable
class NarouSearchOptions extends WorkQuery {
  const NarouSearchOptions({
    super.site = Site.narou,
    super.keyword,
    super.limit = 20,
    super.offset = 0,
    this.genres = const <NarouGenre>{},
    this.minChars,
    this.maxChars,
    this.lastUpdatedAfter,
    this.completed,
    this.pickup,
    this.longRunning,
  });

  /// 多重選択可能なジャンル。空集合 = ジャンル絞り込みなし。
  final Set<NarouGenre> genres;

  /// 文字数下限 (inclusive)。
  final int? minChars;

  /// 文字数上限 (inclusive)。
  final int? maxChars;

  /// 最終更新日の下限 (inclusive)。`lastup` パラメタに UNIX 時刻で
  /// 渡す。
  final DateTime? lastUpdatedAfter;

  /// 完結フラグ。`true` で完結作のみ、`false` で連載中のみ。
  final bool? completed;

  /// ピックアップフラグ。
  final bool? pickup;

  /// 長期連載フラグ（最終更新が 1 ヶ月以上前）。
  final bool? longRunning;

  /// なろう API に渡す query parameters を返す。
  ///
  /// - `out=json` は呼び出し側の `NarouApiClient` で固定で付与する。
  /// - `genre` は複数選択時は数値コード昇順を `-` 連結（例: `201-301`）。
  /// - `length` は `<min>-<max>` 形式。片側だけの場合は `<min>-` / `-<max>`。
  /// - `lastup` は UNIX 時刻（秒）。
  /// - `lim` / `st` はそれぞれ `limit` / `offset`。
  /// - 真偽値フラグは `1` 指定時のみ存在し、`false` の場合はキー自体を
  ///   省略する（なろう API 仕様）。
  ///
  /// 戻り値のキー順序は `SplayTreeMap` ベースで昇順固定。
  Map<String, String> toQueryParameters() {
    final Map<String, String> params = <String, String>{};
    if (keyword != null && keyword!.isNotEmpty) {
      params['word'] = keyword!;
    }
    params['lim'] = limit.toString();
    if (offset > 0) {
      params['st'] = offset.toString();
    }
    if (genres.isNotEmpty) {
      final List<int> codes = genres.map((NarouGenre g) => g.code).toList()
        ..sort();
      params['genre'] = codes.map((int c) => c.toString()).join('-');
    }
    if (minChars != null || maxChars != null) {
      final String lo = (minChars ?? '').toString();
      final String hi = (maxChars ?? '').toString();
      params['length'] = '$lo-$hi';
    }
    if (lastUpdatedAfter != null) {
      final int secs =
          lastUpdatedAfter!.toUtc().millisecondsSinceEpoch ~/ 1000;
      params['lastup'] = secs.toString();
    }
    if (completed == true) params['type'] = 'er'; // er = 完結 + 短編
    if (pickup == true) params['ispickup'] = '1';
    if (longRunning == true) params['stop'] = '1';
    // Sort for stable order.
    final List<String> keys = params.keys.toList()..sort();
    return <String, String>{for (final String k in keys) k: params[k]!};
  }

  /// site / keyword / limit / offset を変更したコピーを作る。
  /// なろう固有フィールドは現状の値を維持。
  @override
  NarouSearchOptions copyWith({
    Site? site,
    String? keyword,
    int? limit,
    int? offset,
    Set<NarouGenre>? genres,
    int? minChars,
    int? maxChars,
    DateTime? lastUpdatedAfter,
    bool? completed,
    bool? pickup,
    bool? longRunning,
  }) {
    return NarouSearchOptions(
      site: site ?? this.site,
      keyword: keyword ?? this.keyword,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      genres: genres ?? this.genres,
      minChars: minChars ?? this.minChars,
      maxChars: maxChars ?? this.maxChars,
      lastUpdatedAfter: lastUpdatedAfter ?? this.lastUpdatedAfter,
      completed: completed ?? this.completed,
      pickup: pickup ?? this.pickup,
      longRunning: longRunning ?? this.longRunning,
    );
  }
}

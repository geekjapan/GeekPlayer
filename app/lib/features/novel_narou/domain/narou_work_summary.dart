import 'package:flutter/foundation.dart';

import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work.dart';
import '../../../core/novel/models/work_id.dart';

/// 検索結果リスト 1 件分の "要約" ビュー。
///
/// 公式 API の検索 (`novelapi` / `novel18api`) は本文を返さないため、
/// このクラスは「Work 一覧で表示するのに必要なフィールドだけ」を保持
/// する。共通 [Work] へは [toWork] で変換する。
///
/// design.md "Defensive mapping" 方針:
/// **必須は `ncode` と `title` のみ**。それ以外は欠損許容 / 安全な
/// default にフォールバックする。
@immutable
class NarouWorkSummary {
  const NarouWorkSummary({
    required this.ncode,
    required this.title,
    required this.site,
    this.writer = '',
    this.story = '',
    this.keywords = const <String>[],
    this.genreCode,
    this.bigGenreCode,
    this.generalAllNo = 0,
    this.length = 0,
    this.novelType = 1, // 1 = 連載, 2 = 短編
    this.end = 0,
    this.lastUp,
  });

  final String ncode;
  final String title;
  final Site site;
  final String writer;
  final String story;
  final List<String> keywords;
  final int? genreCode;
  final int? bigGenreCode;

  /// 連載作品の総話数。短編は 1。
  final int generalAllNo;

  /// 総文字数。
  final int length;

  /// 1 = 連載, 2 = 短編。
  final int novelType;

  /// 0 = 連載中, 1 = 完結 / 短編。
  final int end;

  /// 最終更新日時。`null` = API レスポンスに含まれていなかった。
  final DateTime? lastUp;

  bool get isShort => novelType == 2;
  bool get isCompleted => end == 1;

  /// 共通ドメインの [Work] へ変換。`addedAt` は呼び出し時の `now` を
  /// 使う（実際に Library に追加される瞬間に上書きされる）。
  Work toWork() {
    return Work(
      id: WorkId(site: site, externalId: ncode),
      title: title,
      author: writer,
      synopsis: story.isEmpty ? null : story,
      episodeCount: isShort ? 1 : generalAllNo,
      addedAt: DateTime.now().toUtc(),
      lastSyncedAt: lastUp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NarouWorkSummary &&
        other.ncode == ncode &&
        other.title == title &&
        other.site == site &&
        other.writer == writer &&
        other.story == story &&
        listEquals(other.keywords, keywords) &&
        other.genreCode == genreCode &&
        other.bigGenreCode == bigGenreCode &&
        other.generalAllNo == generalAllNo &&
        other.length == length &&
        other.novelType == novelType &&
        other.end == end &&
        other.lastUp == lastUp;
  }

  @override
  int get hashCode => Object.hash(
    ncode,
    title,
    site,
    writer,
    story,
    Object.hashAll(keywords),
    genreCode,
    bigGenreCode,
    generalAllNo,
    length,
    novelType,
    end,
    lastUp,
  );

  @override
  String toString() => 'NarouWorkSummary($ncode, "$title")';
}

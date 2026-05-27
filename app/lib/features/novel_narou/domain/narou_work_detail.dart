import 'package:flutter/foundation.dart';

import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work.dart';
import 'narou_work_summary.dart';

/// 作品詳細ビュー。
///
/// 検索結果の [NarouWorkSummary] と同じフィールドを持つが、`detail`
/// エンドポイントから取得した「より詳しい」結果として扱う型として
/// 分離する（design.md "Decisions"）。
@immutable
class NarouWorkDetail {
  const NarouWorkDetail({
    required this.summary,
    this.firstUp,
    this.weeklyUnique = 0,
  });

  final NarouWorkSummary summary;

  /// 初回掲載日。
  final DateTime? firstUp;

  /// 週間ユニーク数（あれば）。
  final int weeklyUnique;

  String get ncode => summary.ncode;
  String get title => summary.title;
  Site get site => summary.site;
  String get writer => summary.writer;
  String get story => summary.story;
  List<String> get keywords => summary.keywords;
  int get generalAllNo => summary.generalAllNo;
  bool get isShort => summary.isShort;
  bool get isCompleted => summary.isCompleted;
  DateTime? get lastUp => summary.lastUp;
  int get length => summary.length;

  Work toWork() => summary.toWork();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NarouWorkDetail &&
        other.summary == summary &&
        other.firstUp == firstUp &&
        other.weeklyUnique == weeklyUnique;
  }

  @override
  int get hashCode => Object.hash(summary, firstUp, weeklyUnique);
}

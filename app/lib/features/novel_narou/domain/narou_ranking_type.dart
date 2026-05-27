/// なろうランキング API (`rankget`) の集計期間。
///
/// `rankget` エンドポイントは `rtype=YYYYMMDD-<suffix>` というクエリで
/// ランキング種別を受け取る。各 enum 値の [pathSuffix] が API に渡す
/// `<suffix>` 部分（"d" = daily 等）に相当する。
///
/// 参考: <https://dev.syosetu.com/man/rankapi/> "rtype"。
enum NarouRankingType {
  daily('d', '日間'),
  weekly('w', '週間'),
  monthly('m', '月間'),
  quarterly('q', '四半期'),
  yearly('y', '年間'),
  allTime('a', '累計');

  const NarouRankingType(this.pathSuffix, this.label);

  /// `rtype` パラメタの suffix。
  final String pathSuffix;

  /// 日本語表示ラベル（タブ名等で使用）。
  final String label;
}

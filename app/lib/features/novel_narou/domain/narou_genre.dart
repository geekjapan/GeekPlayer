/// なろう API の `biggenre` / `genre` 数値コードに対応する enum。
///
/// 「小説家になろう」公式 API では検索の `genre` パラメタは数値コード（例:
/// 恋愛=101, ファンタジー=201, ...）でしか受け付けない。アプリ側のドメイン
/// 表現としては数値を露出させずに enum で扱い、API リクエスト時に [code]
/// で変換する。`biggenre` (大ジャンル) と `genre` (小ジャンル) の両方を
/// この enum で表現するため、コードは小ジャンル単位の値を保持する。
///
/// 参考: <https://dev.syosetu.com/man/api/> "genre / biggenre"。
enum NarouGenre {
  // 大ジャンル 1: 恋愛
  loveModern(101, '現実世界〔恋愛〕', NarouBigGenre.love),
  loveFantasy(102, '異世界〔恋愛〕', NarouBigGenre.love),
  // 大ジャンル 2: ファンタジー
  fantasyHigh(201, 'ハイファンタジー〔ファンタジー〕', NarouBigGenre.fantasy),
  fantasyLow(202, 'ローファンタジー〔ファンタジー〕', NarouBigGenre.fantasy),
  // 大ジャンル 3: 文芸
  literaryPure(301, '純文学〔文芸〕', NarouBigGenre.literary),
  literaryHuman(302, 'ヒューマンドラマ〔文芸〕', NarouBigGenre.literary),
  literaryHistory(303, '歴史〔文芸〕', NarouBigGenre.literary),
  literaryMystery(304, '推理〔文芸〕', NarouBigGenre.literary),
  literaryHorror(305, 'ホラー〔文芸〕', NarouBigGenre.literary),
  literaryAction(306, 'アクション〔文芸〕', NarouBigGenre.literary),
  literaryComedy(307, 'コメディー〔文芸〕', NarouBigGenre.literary),
  // 大ジャンル 4: SF
  sfVrGame(401, 'VRゲーム〔SF〕', NarouBigGenre.scifi),
  sfSpace(402, '宇宙〔SF〕', NarouBigGenre.scifi),
  sfScience(403, '空想科学〔SF〕', NarouBigGenre.scifi),
  sfPanic(404, 'パニック〔SF〕', NarouBigGenre.scifi),
  // 大ジャンル 99: その他
  otherFairy(9901, '童話〔その他〕', NarouBigGenre.other),
  otherPoem(9902, '詩〔その他〕', NarouBigGenre.other),
  otherEssay(9903, 'エッセイ〔その他〕', NarouBigGenre.other),
  otherReplay(9904, 'リプレイ〔その他〕', NarouBigGenre.other),
  otherOther(9999, 'その他〔その他〕', NarouBigGenre.other),
  // 大ジャンル 98: ノンジャンル
  nonGenre(9801, 'ノンジャンル〔ノンジャンル〕', NarouBigGenre.nonGenre);

  const NarouGenre(this.code, this.label, this.bigGenre);

  /// なろう API `genre=` パラメタに渡す数値コード。
  final int code;

  /// 日本語表示ラベル。
  final String label;

  /// 大ジャンル分類（`biggenre=` パラメタ用）。
  final NarouBigGenre bigGenre;
}

/// なろう API `biggenre` の値。`NarouGenre` の親グルーピング。
enum NarouBigGenre {
  love(1, '恋愛'),
  fantasy(2, 'ファンタジー'),
  literary(3, '文芸'),
  scifi(4, 'SF'),
  other(99, 'その他'),
  nonGenre(98, 'ノンジャンル');

  const NarouBigGenre(this.code, this.label);

  final int code;
  final String label;
}

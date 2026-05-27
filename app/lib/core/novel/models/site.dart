/// Online novel source enumeration.
///
/// v0.1 covers exactly three sites:
///   - `narou`     — 小説家になろう (general-audience)
///   - `noc`       — ノクターン系 (R18 family: novel18.syosetu.com)
///   - `kakuyomu`  — カクヨム
///
/// Per ADR-0001 / ADR-0003, the `code` value is what we persist in
/// `novel_works.site`, `novel_episodes.site`, `site_consents.site` etc.
/// We keep it as a stable string (NOT the enum index) so adding future
/// sources (e.g. ハーメルン, アルファポリス) is a code-only change with
/// no DB migration.
enum Site {
  narou,
  noc,
  kakuyomu;

  /// Stable string identifier used in drift columns and provider keys.
  String get code => switch (this) {
        Site.narou => 'narou',
        Site.noc => 'noc',
        Site.kakuyomu => 'kakuyomu',
      };

  /// Origin/base used by `NovelRepository` implementations and by the
  /// `robots.txt` cache (we may fetch `/robots.txt` from this host).
  ///
  /// Note: なろう has multiple origins (`api.syosetu.com` for metadata
  /// API, `ncode.syosetu.com` for general body, `novel18.syosetu.com`
  /// for R18 body). [baseUrl] returns the body-page origin per ADR-0003
  /// — metadata-API origins are handled by site-specific Dios that the
  /// narou change will wire up. The `responsible-fetching` layer
  /// shares a single RateLimiter across `*.syosetu.com`.
  Uri get baseUrl => switch (this) {
        Site.narou => Uri.parse('https://ncode.syosetu.com'),
        Site.noc => Uri.parse('https://novel18.syosetu.com'),
        Site.kakuyomu => Uri.parse('https://kakuyomu.jp'),
      };

  /// Parse a [code] back to a [Site]. Returns `null` for unknown
  /// codes (e.g. when reading rows persisted by a future version of
  /// the app that knows additional sites).
  static Site? fromCode(String code) {
    return switch (code) {
      'narou' => Site.narou,
      'noc' => Site.noc,
      'kakuyomu' => Site.kakuyomu,
      _ => null,
    };
  }

  /// Display label (ja). Used by [SiteConsentDialog] and
  /// [NovelHomeSection] filter chips.
  String get displayName => switch (this) {
        Site.narou => '小説家になろう',
        Site.noc => 'ノクターン系',
        Site.kakuyomu => 'カクヨム',
      };
}

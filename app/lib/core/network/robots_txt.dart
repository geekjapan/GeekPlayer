/// Minimal `robots.txt` parser and lookup.
///
/// **Specification limits** — this implementation intentionally supports
/// only the subset required by ADR-0001 §取得方針-5:
///
///   - Only directives under the `User-agent: *` group are honored.
///   - Only `Disallow:` directives are interpreted.
///   - `Allow:`, `Crawl-delay:`, `Sitemap:`, host-specific groups, and
///     wildcard / regex patterns are IGNORED.
///   - A `Disallow:` prefix match is applied to the full path (including
///     leading `/`).
///   - An empty `Disallow:` value means "nothing disallowed" (allow all).
///
/// If a site needs more nuanced rules (e.g. `Allow:` overrides), we'll
/// extend this and update the `responsible-fetching` capability spec.
library;

import 'errors.dart';

/// Immutable parsed representation of a host's `robots.txt` (under the
/// `User-agent: *` group).
class RobotsRules {
  RobotsRules({
    required List<String> disallowedPrefixes,
    DateTime? fetchedAt,
  })  : _disallowed = List<String>.unmodifiable(disallowedPrefixes),
        fetchedAt = fetchedAt ?? DateTime.now().toUtc();

  /// "Allow everything" sentinel — used when no relevant rules were
  /// found and the host did not return an error.
  factory RobotsRules.allowAll({DateTime? fetchedAt}) =>
      RobotsRules(disallowedPrefixes: const <String>[], fetchedAt: fetchedAt);

  /// "Deny everything" sentinel — installed for fail-closed behavior
  /// when `/robots.txt` itself failed to fetch (ADR-0001 §取得方針-5
  /// requires we respect robots.txt; if we can't read it we err on the
  /// safe side).
  factory RobotsRules.denyAll({DateTime? fetchedAt}) =>
      RobotsRules(disallowedPrefixes: const <String>['/'], fetchedAt: fetchedAt);

  /// Parse a `robots.txt` document. Lines outside the `User-agent: *`
  /// group, comments (`#`), blank lines, and unsupported directives are
  /// silently dropped.
  factory RobotsRules.parse(String body, {DateTime? fetchedAt}) {
    final List<String> disallow = <String>[];
    bool inWildcardGroup = false;
    for (String rawLine in body.split('\n')) {
      String line = rawLine;
      final int hash = line.indexOf('#');
      if (hash >= 0) line = line.substring(0, hash);
      line = line.trim();
      if (line.isEmpty) continue;
      final int colon = line.indexOf(':');
      if (colon < 0) continue;
      final String field = line.substring(0, colon).trim().toLowerCase();
      final String value = line.substring(colon + 1).trim();
      switch (field) {
        case 'user-agent':
          inWildcardGroup = value == '*';
        case 'disallow':
          if (inWildcardGroup && value.isNotEmpty) {
            disallow.add(value);
          }
        // Allow, Crawl-delay, Sitemap, etc — ignored by design.
      }
    }
    return RobotsRules(
      disallowedPrefixes: disallow,
      fetchedAt: fetchedAt,
    );
  }

  final List<String> _disallowed;

  /// When these rules were obtained. Used by [RobotsCache] to decide if
  /// the 24h TTL has elapsed.
  final DateTime fetchedAt;

  /// `true` if [path] is permitted under the parsed rules. A path is
  /// disallowed if any `Disallow:` prefix matches.
  ///
  /// [path] is matched as-is (must start with `/`). Callers should pass
  /// the request's path portion only (no scheme/host/query).
  bool allows(String path) {
    for (final String prefix in _disallowed) {
      if (path.startsWith(prefix)) return false;
    }
    return true;
  }

  /// Number of `Disallow:` rules in the wildcard group. Useful for
  /// tests / diagnostics.
  int get disallowedCount => _disallowed.length;

  /// Iterable of parsed disallow prefixes. Read-only.
  Iterable<String> get disallowedPrefixes => _disallowed;
}

/// In-memory cache of `RobotsRules` keyed by host with a 24h TTL.
///
/// Fetching is delegated to a caller-supplied function so the cache is
/// HTTP-client agnostic (and trivial to test). When fetching fails the
/// cache installs [RobotsRules.denyAll] for the host so subsequent
/// requests fail closed until the TTL elapses and a new attempt is made.
class RobotsCache {
  // ignore_for_file: prefer_initializing_formals
  RobotsCache({
    required Future<String> Function(String host) fetcher,
    Duration ttl = const Duration(hours: 24),
    DateTime Function()? now,
  })  : _fetcher = fetcher,
        _ttl = ttl,
        _now = now ?? (() => DateTime.now().toUtc());

  final Future<String> Function(String host) _fetcher;
  final Duration _ttl;
  final DateTime Function() _now;
  final Map<String, RobotsRules> _byHost = <String, RobotsRules>{};

  /// Return cached rules for [host] (fetching once if not cached or if
  /// the TTL has elapsed).
  Future<RobotsRules> rulesFor(String host) async {
    final RobotsRules? existing = _byHost[host];
    if (existing != null &&
        _now().difference(existing.fetchedAt) < _ttl) {
      return existing;
    }
    try {
      final String body = await _fetcher(host);
      final RobotsRules parsed = RobotsRules.parse(body, fetchedAt: _now());
      _byHost[host] = parsed;
      return parsed;
    } catch (_) {
      // Fail-closed: install deny-all for the TTL window so subsequent
      // requests are rejected synchronously without retrying the fetch.
      final RobotsRules deny = RobotsRules.denyAll(fetchedAt: _now());
      _byHost[host] = deny;
      return deny;
    }
  }

  /// Throws [RobotsDisallowedError] if [path] is denied for [host]
  /// under the cached (or freshly-fetched) rules.
  Future<void> assertAllowed(String host, String path) async {
    final RobotsRules rules = await rulesFor(host);
    if (!rules.allows(path)) {
      throw RobotsDisallowedError(
        'robots.txt disallows $path on $host',
        host: host,
        path: path,
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/novel/models/site.dart';
import '../../../core/novel/policy_version.dart';
import '../../../core/storage/database.dart';
import '../data/consent_repository.dart';

/// Permanent disclosure + per-site consent toggles for
/// `Settings > オンライン小説`.
///
/// Spec `site-consent` "Settings screen permanent disclosure":
///   - first widget on the screen
///   - mentions ADR-0001, "1 req / 2 s" (kakuyomu), "能動キャッシュ"
///   - visible regardless of current consent state
///
/// Spec `site-consent` "Consent revocation and re-grant from settings":
///   - each site togglable independently
///   - revocation MUST NOT delete Library entries or cached episodes
///   - re-grant resumes fetches without re-prompting the dialog
class NovelSettingsSection extends ConsumerStatefulWidget {
  const NovelSettingsSection({super.key});

  @override
  ConsumerState<NovelSettingsSection> createState() =>
      _NovelSettingsSectionState();
}

class _NovelSettingsSectionState extends ConsumerState<NovelSettingsSection> {
  late Future<Map<Site, SiteConsentRow>> _futureConsents;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _futureConsents = ref.read(consentRepositoryProvider).getAll();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Permanent disclosure — must always be the first element on
          // the screen, regardless of consent state (spec scenario
          // "Disclosure is always visible").
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'オンライン小説の取り扱い (ADR-0001)',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '本アプリは以下の方針でオンライン小説サイトと通信します:\n'
                    ' ・能動キャッシュのみ。利用者が「ライブラリに追加」を'
                    '選んだ作品の本文のみ取得・保存します。\n'
                    ' ・カクヨムは 1 req / 2 s、並列度 1 でアクセスします。'
                    'なろう / ノクターン系はやや緩く設定 (公式 API 想定)。\n'
                    ' ・robots.txt の Disallow を尊重します。\n'
                    ' ・User-Agent に GeekPlayer のバージョンと連絡先 URL を'
                    '明示します。',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '同意ポリシーバージョン: $kPolicyVersion',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('サイトごとの同意', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<Map<Site, SiteConsentRow>>(
            future: _futureConsents,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<Map<Site, SiteConsentRow>> snap,
                ) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final Map<Site, SiteConsentRow> consents = snap.data!;
                  return Column(
                    children: <Widget>[
                      for (final Site s in Site.values)
                        SwitchListTile(
                          key: ValueKey<String>('settings-consent-${s.code}'),
                          title: Text(s.displayName),
                          subtitle: Text(s.baseUrl.host),
                          value: consents[s]?.granted ?? false,
                          onChanged: (bool v) => _toggle(s, v),
                        ),
                    ],
                  );
                },
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(Site site, bool granted) async {
    final ConsentRepository repo = ref.read(consentRepositoryProvider);
    if (granted) {
      await repo.grant(site);
    } else {
      await repo.revoke(site);
    }
    if (mounted) {
      setState(_refresh);
    }
  }
}

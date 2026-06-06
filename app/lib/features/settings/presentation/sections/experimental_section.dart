import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ml/ml_model_state.dart';
import '../../../../core/ml/model_repository.dart';
import '../../../../core/ml/providers.dart';
import '../../../../core/ml/upscale_model_catalog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../app_settings_notifier.dart';
import '../settings_screen.dart';

/// 実験的機能 (Experimental) section — gates AI image upscaling (ADR-0007).
///
/// Provides the enable toggle (default OFF), the default scale (2x/4x), and
/// model management (state / size / download with progress / delete). All AI
/// upscaling is experimental and unguaranteed; while the toggle is OFF the
/// effective backend stays on the bicubic CPU floor.
class ExperimentalSection extends ConsumerStatefulWidget {
  const ExperimentalSection({super.key});

  @override
  ConsumerState<ExperimentalSection> createState() =>
      _ExperimentalSectionState();
}

class _ExperimentalSectionState extends ConsumerState<ExperimentalSection> {
  /// In-flight download progress in [0, 1], or null when not downloading.
  double? _progress;

  /// Cached on-disk state of the currently-selected model entry.
  MlModelState _modelState = MlModelState.absent;
  int _modelSize = 0;
  int _loadedForScale = -1;

  Future<void> _refreshModelState(int scale) async {
    final UpscaleModelEntry? entry = UpscaleModelCatalog.forScale(scale);
    if (entry == null) return;
    final ModelRepository repo = ref.read(modelRepositoryProvider);
    final MlModelState state = await repo.stateOf(entry);
    final int size = await repo.sizeOf(entry);
    if (!mounted) return;
    setState(() {
      _modelState = state;
      _modelSize = size;
      _loadedForScale = scale;
    });
  }

  Future<void> _download(UpscaleModelEntry entry) async {
    setState(() => _progress = 0);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(modelRepositoryProvider)
          .ensureModel(
            entry,
            onProgress: (int received, int total) {
              if (!mounted || total <= 0) return;
              setState(() => _progress = received / total);
            },
          );
      await _refreshModelState(entry.scale);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsAiUpscaleModelError)),
        );
      }
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _delete(UpscaleModelEntry entry) async {
    await ref.read(modelRepositoryProvider).delete(entry);
    if (!mounted) return;
    await _refreshModelState(entry.scale);
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool enabled = ref.watch(
      appSettingsProvider.select(
        (AsyncValue<AppSettings> s) => s.value?.aiUpscaleEnabled ?? false,
      ),
    );
    final int scale = ref.watch(
      appSettingsProvider.select(
        (AsyncValue<AppSettings> s) => s.value?.aiUpscaleScale ?? 2,
      ),
    );
    if (scale != _loadedForScale) {
      // Lazy (re)load model state when the selected scale changes.
      // ignore: discarded_futures
      _refreshModelState(scale);
    }
    final UpscaleModelEntry? entry = UpscaleModelCatalog.forScale(scale);

    return SettingsSection(
      id: 'experimental',
      title: l10n.settingsSectionExperimental,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: <Widget>[
              const Icon(Icons.science_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.settingsExperimentalWarning,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        SwitchListTile(
          key: const Key('experimental-ai-upscale-enable'),
          title: Text(l10n.settingsAiUpscaleEnable),
          value: enabled,
          onChanged: (bool v) => ref
              .read(appSettingsProvider.notifier)
              .mutate((AppSettings s) => s.copyWith(aiUpscaleEnabled: v)),
        ),
        ListTile(
          key: const Key('experimental-ai-upscale-scale'),
          title: Text(l10n.settingsAiUpscaleScale),
          subtitle: Wrap(
            spacing: 8,
            children: <Widget>[
              for (final int s in UpscaleModelCatalog.supportedScales)
                ChoiceChip(
                  key: Key('experimental-ai-upscale-scale-$s'),
                  label: Text('${s}x'),
                  selected: scale == s,
                  onSelected: (bool sel) {
                    if (!sel) return;
                    ref
                        .read(appSettingsProvider.notifier)
                        .mutate(
                          (AppSettings st) => st.copyWith(aiUpscaleScale: s),
                        );
                  },
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.settingsAiUpscaleNextRunHelper,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
        if (entry != null)
          ListTile(
            key: const Key('experimental-ai-upscale-model'),
            title: Text(l10n.settingsAiUpscaleModelTitle),
            subtitle: _progress != null
                ? LinearProgressIndicator(value: _progress)
                : Text(
                    _modelState == MlModelState.present
                        ? l10n.settingsAiUpscaleModelPresent(
                            _formatBytes(_modelSize),
                          )
                        : l10n.settingsAiUpscaleModelAbsent,
                  ),
            trailing: _progress != null
                ? null
                : (_modelState == MlModelState.present
                      ? IconButton(
                          key: const Key('experimental-ai-upscale-delete'),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.settingsAiUpscaleDelete,
                          onPressed: () => _delete(entry),
                        )
                      : IconButton(
                          key: const Key('experimental-ai-upscale-download'),
                          icon: const Icon(Icons.download_outlined),
                          tooltip: l10n.settingsAiUpscaleDownload,
                          onPressed: () => _download(entry),
                        )),
          ),
      ],
    );
  }
}

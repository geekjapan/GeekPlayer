import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/manga/archive_inspector.dart';
import '../../../core/ml/image_upscaler.dart';
import '../../../core/ml/providers.dart';
import '../../../core/ml/upscale_request.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/app_settings_notifier.dart';
import '../data/manga_providers.dart';
import '../domain/manga_archive.dart';
import '../domain/manga_bookmark.dart';
import '../domain/manga_locator.dart';
import '../domain/manga_reading_direction.dart';
import '../domain/manga_spread_mode.dart';

part 'manga_viewer_screen.g.dart';

// ---------------------------------------------------------------------------
// Viewer state providers
// ---------------------------------------------------------------------------

/// Per-archive current page index (0-based, spread anchor).
@riverpod
class MangaPageIndex extends _$MangaPageIndex {
  @override
  int build(String mangaUri) => 0;

  void goTo(int index) => state = index;
}

/// Per-archive reading direction.
@riverpod
class MangaDirection extends _$MangaDirection {
  @override
  MangaReadingDirection build(String mangaUri) =>
      MangaReadingDirection.rightToLeft;

  void toggle() {
    state = state == MangaReadingDirection.rightToLeft
        ? MangaReadingDirection.leftToRight
        : MangaReadingDirection.rightToLeft;
  }
}

/// Per-archive spread mode.
@riverpod
class MangaSpread extends _$MangaSpread {
  @override
  MangaSpreadMode build(String mangaUri) => MangaSpreadMode.single;

  void toggle() {
    state = state == MangaSpreadMode.single
        ? MangaSpreadMode.spread
        : MangaSpreadMode.single;
  }
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

/// Full-screen manga page viewer.
///
/// Supports:
/// - Single-page and two-page spread layouts ([MangaSpreadMode]).
/// - Right-to-left and left-to-right navigation ([MangaReadingDirection]).
/// - Pinch zoom and pan (via [InteractiveViewer]).
/// - Bookmark create / list / jump / delete.
/// - Progress persist on pop.
class MangaViewerScreen extends ConsumerStatefulWidget {
  const MangaViewerScreen({super.key, required this.archive});

  final MangaArchive archive;

  @override
  ConsumerState<MangaViewerScreen> createState() => _MangaViewerScreenState();
}

class _MangaViewerScreenState extends ConsumerState<MangaViewerScreen> {
  final TransformationController _transformController =
      TransformationController();
  bool _controlsVisible = true;
  bool _upscaling = false;
  Uint8List? _upscaledBytes;

  @override
  void initState() {
    super.initState();
    // Restore last saved position.
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    final MangaLocator locator = await ref
        .read(mangaRepositoryProvider)
        .loadProgress(widget.archive.uri);
    if (!mounted) return;
    ref
        .read(mangaPageIndexProvider(widget.archive.uri).notifier)
        .goTo(locator.pageIndex);
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _saveProgress() {
    final int idx = ref.read(mangaPageIndexProvider(widget.archive.uri));
    ref
        .read(mangaRepositoryProvider)
        .saveProgress(widget.archive.uri, MangaLocator(pageIndex: idx));
  }

  void _navigate(int delta) {
    final int current = ref.read(mangaPageIndexProvider(widget.archive.uri));
    final MangaSpreadMode spread = ref.read(
      mangaSpreadProvider(widget.archive.uri),
    );
    final int step = spread == MangaSpreadMode.spread ? 2 : 1;
    final int next = (current + delta * step).clamp(
      0,
      widget.archive.pageCount - 1,
    );
    ref.read(mangaPageIndexProvider(widget.archive.uri).notifier).goTo(next);
    // Reset zoom and upscaled cache when page changes.
    _transformController.value = Matrix4.identity();
    setState(() => _upscaledBytes = null);
  }

  void _toggleControls() =>
      setState(() => _controlsVisible = !_controlsVisible);

  Future<void> _upscaleCurrentPage() async {
    if (_upscaling) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final int idx = ref.read(mangaPageIndexProvider(widget.archive.uri));
    if (idx >= widget.archive.pages.length) return;
    setState(() {
      _upscaling = true;
      _upscaledBytes = null;
    });
    try {
      const ArchiveInspector inspector = ArchiveInspector();
      final String entryName = widget.archive.pages[idx].entryName;
      final Uint8List raw = await inspector.readPageBytes(
        widget.archive.path,
        MangaArchiveEntry(name: entryName, uncompressedSize: 0),
      );
      // Decode to get actual dimensions before upscaling.
      final (int w, int h) = _decodeDimensions(raw);
      // Use the configured experimental scale (2x or 4x); defaults to 2x.
      final int scale =
          ref.read(appSettingsProvider).value?.aiUpscaleScale ?? 2;
      final UpscaleRequest sized = UpscaleRequest(
        bytes: raw,
        srcWidth: w,
        srcHeight: h,
        scaleFactor: scale,
      );
      // Resolve the effective upscaler asynchronously (ADR-0007 step 3): floors
      // to bicubic CPU unless experimental is ON and a model is present.
      final ImageUpscaler upscaler = await ref.read(
        imageUpscalerProvider.future,
      );
      final result = await upscaler.upscale(sized);
      if (mounted) {
        setState(() {
          _upscaledBytes = result.bytes;
          _upscaling = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _upscaling = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.mangaUpscaleError)));
      }
    }
  }

  (int, int) _decodeDimensions(Uint8List bytes) {
    // Best-effort width/height from PNG/JPEG headers without full decode.
    // Falls back to (1, 1) — CpuImageUpscaler reads actual dimensions itself.
    if (bytes.length > 24 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      // PNG: width at bytes 16-19, height at 20-23 (big-endian).
      final int w =
          (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final int h =
          (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      if (w > 0 && h > 0) return (w, h);
    }
    if (bytes.length > 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      // JPEG: scan for SOF0/SOF2 markers.
      int i = 2;
      while (i + 8 < bytes.length) {
        if (bytes[i] != 0xFF) break;
        final int marker = bytes[i + 1];
        final int segLen = (bytes[i + 2] << 8) | bytes[i + 3];
        if (marker == 0xC0 || marker == 0xC2) {
          final int h = (bytes[i + 5] << 8) | bytes[i + 6];
          final int w = (bytes[i + 7] << 8) | bytes[i + 8];
          if (w > 0 && h > 0) return (w, h);
        }
        i += 2 + segLen;
      }
    }
    return (1, 1);
  }

  Future<void> _showBookmarkDialog() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TextEditingController ctrl = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.mangaBookmarkAdd),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: l10n.mangaBookmarkLabelHint),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (confirmed != true || !mounted) return;
    final int idx = ref.read(mangaPageIndexProvider(widget.archive.uri));
    await ref
        .read(mangaRepositoryProvider)
        .addBookmark(
          mangaUri: widget.archive.uri,
          label: ctrl.text.trim().isEmpty ? 'p${idx + 1}' : ctrl.text.trim(),
          locator: MangaLocator(pageIndex: idx),
        );
  }

  Future<void> _showBookmarkList() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<MangaBookmark> marks = await ref
        .read(mangaRepositoryProvider)
        .listBookmarks(widget.archive.uri);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) {
        if (marks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.mangaBookmarkEmpty),
          );
        }
        return ListView.builder(
          itemCount: marks.length,
          itemBuilder: (BuildContext _, int i) {
            final MangaBookmark bm = marks[i];
            return ListTile(
              title: Text(bm.label),
              subtitle: Text('p${bm.locator.pageIndex + 1}'),
              onTap: () {
                Navigator.of(ctx).pop();
                ref
                    .read(mangaPageIndexProvider(widget.archive.uri).notifier)
                    .goTo(bm.locator.pageIndex);
                _transformController.value = Matrix4.identity();
              },
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                tooltip: l10n.mangaBookmarkDelete,
                onPressed: () async {
                  await ref.read(mangaRepositoryProvider).deleteBookmark(bm.id);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final int currentIdx = ref.watch(
      mangaPageIndexProvider(widget.archive.uri),
    );
    final MangaReadingDirection direction = ref.watch(
      mangaDirectionProvider(widget.archive.uri),
    );
    final MangaSpreadMode spread = ref.watch(
      mangaSpreadProvider(widget.archive.uri),
    );

    final bool isRtl = direction == MangaReadingDirection.rightToLeft;

    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) => _saveProgress(),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: _controlsVisible
            ? AppBar(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                title: Text(
                  widget.archive.title,
                  style: const TextStyle(fontSize: 14),
                ),
                actions: <Widget>[
                  IconButton(
                    icon: Icon(
                      isRtl
                          ? Icons.format_textdirection_r_to_l
                          : Icons.format_textdirection_l_to_r,
                    ),
                    tooltip: l10n.settingsMangaReadingDirection,
                    onPressed: () => ref
                        .read(
                          mangaDirectionProvider(widget.archive.uri).notifier,
                        )
                        .toggle(),
                  ),
                  IconButton(
                    icon: Icon(
                      spread == MangaSpreadMode.spread
                          ? Icons.book
                          : Icons.menu_book,
                    ),
                    tooltip: l10n.settingsMangaSpreadMode,
                    onPressed: () => ref
                        .read(mangaSpreadProvider(widget.archive.uri).notifier)
                        .toggle(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmark_add),
                    tooltip: l10n.mangaBookmarkAdd,
                    onPressed: _showBookmarkDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmarks),
                    tooltip: l10n.mangaBookmarkList,
                    onPressed: _showBookmarkList,
                  ),
                  IconButton(
                    icon: const Icon(Icons.auto_fix_high),
                    tooltip: l10n.mangaUpscaleAction,
                    onPressed: _upscaling ? null : _upscaleCurrentPage,
                  ),
                ],
              )
            : null,
        body: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: <Widget>[
              Center(
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.5,
                  maxScale: 8.0,
                  child: _upscaledBytes != null
                      ? Image.memory(
                          _upscaledBytes!,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (BuildContext ctx2, Object err, StackTrace? st) =>
                                  const Icon(
                                    Icons.broken_image,
                                    color: Colors.white54,
                                  ),
                        )
                      : spread == MangaSpreadMode.spread
                      ? _SpreadView(
                          archive: widget.archive,
                          anchorIndex: currentIdx,
                          isRtl: isRtl,
                        )
                      : _SinglePageView(
                          archive: widget.archive,
                          pageIndex: currentIdx,
                        ),
                ),
              ),
              if (_upscaling)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          l10n.mangaUpscaleInProgress,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              // Navigation tap zones.
              if (_controlsVisible) ...<Widget>[
                Positioned(
                  left: 0,
                  top: 80,
                  bottom: 80,
                  width: 60,
                  child: GestureDetector(
                    onTap: () => _navigate(isRtl ? 1 : -1),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 80,
                  bottom: 80,
                  width: 60,
                  child: GestureDetector(
                    onTap: () => _navigate(isRtl ? -1 : 1),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
              // Page indicator.
              if (_controlsVisible)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.mangaViewerPageOf(
                          currentIdx + 1,
                          widget.archive.pageCount,
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page widgets
// ---------------------------------------------------------------------------

class _SinglePageView extends ConsumerWidget {
  const _SinglePageView({required this.archive, required this.pageIndex});

  final MangaArchive archive;
  final int pageIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pageIndex >= archive.pages.length) {
      return const SizedBox.shrink();
    }
    final String entryName = archive.pages[pageIndex].entryName;
    return _PageImage(archivePath: archive.path, entryName: entryName);
  }
}

class _SpreadView extends ConsumerWidget {
  const _SpreadView({
    required this.archive,
    required this.anchorIndex,
    required this.isRtl,
  });

  final MangaArchive archive;
  final int anchorIndex;
  final bool isRtl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? leftEntry;
    final String? rightEntry;

    if (isRtl) {
      // Right page is anchor, left page is anchor+1.
      rightEntry = anchorIndex < archive.pages.length
          ? archive.pages[anchorIndex].entryName
          : null;
      leftEntry = (anchorIndex + 1) < archive.pages.length
          ? archive.pages[anchorIndex + 1].entryName
          : null;
    } else {
      // Left page is anchor, right page is anchor+1.
      leftEntry = anchorIndex < archive.pages.length
          ? archive.pages[anchorIndex].entryName
          : null;
      rightEntry = (anchorIndex + 1) < archive.pages.length
          ? archive.pages[anchorIndex + 1].entryName
          : null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (leftEntry != null)
          _PageImage(archivePath: archive.path, entryName: leftEntry),
        if (rightEntry != null)
          _PageImage(archivePath: archive.path, entryName: rightEntry),
      ],
    );
  }
}

/// Loads and displays a single archive page image lazily.
class _PageImage extends StatefulWidget {
  const _PageImage({required this.archivePath, required this.entryName});

  final String archivePath;
  final String entryName;

  @override
  State<_PageImage> createState() => _PageImageState();
}

class _PageImageState extends State<_PageImage> {
  static const ArchiveInspector _inspector = ArchiveInspector();
  Uint8List? _bytes;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_PageImage old) {
    super.didUpdateWidget(old);
    if (old.archivePath != widget.archivePath ||
        old.entryName != widget.entryName) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _bytes = null;
    });
    try {
      final MangaArchiveEntry entry = MangaArchiveEntry(
        name: widget.entryName,
        uncompressedSize: 0,
      );
      final Uint8List data = await _inspector.readPageBytes(
        widget.archivePath,
        entry,
      );
      if (mounted) {
        setState(() {
          _bytes = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 300,
        height: 400,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_error != null || _bytes == null) {
      return const SizedBox(
        width: 300,
        height: 400,
        child: Center(child: Icon(Icons.broken_image, color: Colors.white54)),
      );
    }
    return Image.memory(
      _bytes!,
      fit: BoxFit.contain,
      errorBuilder: (BuildContext ctx2, Object err, StackTrace? st) =>
          const Icon(Icons.broken_image, color: Colors.white54),
    );
  }
}

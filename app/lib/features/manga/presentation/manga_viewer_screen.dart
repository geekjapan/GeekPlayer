import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/manga/archive_inspector.dart';
import '../../../l10n/app_localizations.dart';
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
    // Reset zoom when page changes.
    _transformController.value = Matrix4.identity();
  }

  void _toggleControls() =>
      setState(() => _controlsVisible = !_controlsVisible);

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
                  child: spread == MangaSpreadMode.spread
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

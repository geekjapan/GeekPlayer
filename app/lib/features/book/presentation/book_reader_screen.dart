import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/errors/app_error.dart';
import '../../../l10n/app_localizations.dart';
import '../data/book_providers.dart';
import '../data/epub_document.dart';
import '../data/pdf_document.dart';
import '../domain/book_bookmark.dart';
import '../domain/book_document.dart';
import '../domain/book_locator.dart';

/// Entry-point screen for reading a PDF or EPUB file.
///
/// [filePath] is the absolute path to the local file. The repository handles
/// metadata persistence, format detection, and error mapping.
class BookReaderScreen extends ConsumerStatefulWidget {
  const BookReaderScreen({super.key, required this.filePath});
  final String filePath;

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  BookDocument? _doc;
  AppError? _error;
  bool _loading = true;
  final PdfViewerController _pdfController = PdfViewerController();
  final PageController _epubPageController = PageController();

  @override
  void initState() {
    super.initState();
    _openBook();
  }

  Future<void> _openBook() async {
    try {
      final BookDocument doc = await ref
          .read(bookRepositoryProvider)
          .openBook(widget.filePath);
      // Restore progress.
      final BookLocator saved = await ref
          .read(bookRepositoryProvider)
          .loadProgress(doc.metadata.uri);
      await doc.goToPage(saved.pageIndex);
      if (mounted) {
        setState(() {
          _doc = doc;
          _loading = false;
        });
      }
    } on AppError catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _error = UnknownError(e, stackTrace: st);
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Persist progress before screen exits.
    if (_doc != null) {
      ref
          .read(bookRepositoryProvider)
          .saveProgress(_doc!.metadata.uri, _doc!.currentLocator)
          .ignore();
      _doc!.dispose();
    }
    _epubPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String title = _doc?.metadata.title ?? l10n.bookReaderTitle;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          if (_doc != null)
            IconButton(
              icon: const Icon(Icons.bookmark_add),
              tooltip: l10n.bookBookmarkAdd,
              onPressed: () => _showAddBookmarkDialog(context),
            ),
          if (_doc != null)
            IconButton(
              icon: const Icon(Icons.bookmarks),
              tooltip: l10n.bookBookmarkList,
              onPressed: () => _showBookmarkList(context),
            ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(l10n);

    final BookDocument doc = _doc!;
    if (doc is PdfBookDocument) {
      return _buildPdfView(doc, l10n);
    } else if (doc is EpubBookDocument) {
      return _buildEpubView(doc, l10n);
    }
    return const SizedBox.shrink();
  }

  Widget _buildError(AppLocalizations l10n) {
    final String msg = switch (_error!) {
      FileNotFoundError() => l10n.bookFileNotFoundMessage,
      UnsupportedFormatError() => l10n.errorUnsupportedFormat,
      _ => l10n.errorUnknown,
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          Text(msg, textAlign: TextAlign.center),
          if (_error is FileNotFoundError) ...<Widget>[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.bookFileNotFoundReimport),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPdfView(PdfBookDocument doc, AppLocalizations l10n) {
    return Column(
      children: <Widget>[
        Expanded(
          child: PdfViewer.file(
            doc.metadata.path,
            controller: _pdfController,
            initialPageNumber: doc.currentLocator.pageIndex,
            params: PdfViewerParams(
              onPageChanged: (int? page) {
                if (page != null) doc.goToPage(page).ignore();
              },
            ),
          ),
        ),
        _buildNavBar(doc, l10n, isPdf: true),
      ],
    );
  }

  Widget _buildEpubView(EpubBookDocument doc, AppLocalizations l10n) {
    final int chapterIndex = doc.currentLocator.pageIndex - 1;
    final ScrollController scrollController = ScrollController(
      initialScrollOffset:
          0, // restored via loadProgress → goToPage already set pageIndex.
    );

    return Column(
      children: <Widget>[
        Expanded(
          child: PageView.builder(
            controller: _epubPageController,
            itemCount: doc.chapters.length,
            onPageChanged: (int idx) => doc.goToPage(idx + 1).ignore(),
            itemBuilder: (BuildContext ctx, int idx) {
              final EpubChapter chapter = doc.chapters[idx];
              return SingleChildScrollView(
                controller: idx == chapterIndex ? scrollController : null,
                padding: const EdgeInsets.all(16),
                child: Html(data: chapter.htmlContent),
              );
            },
          ),
        ),
        _buildNavBar(doc, l10n, isPdf: false),
      ],
    );
  }

  Widget _buildNavBar(
    BookDocument doc,
    AppLocalizations l10n, {
    required bool isPdf,
  }) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: doc.currentLocator.pageIndex > 1
                ? () async {
                    await doc.goToPage(doc.currentLocator.pageIndex - 1);
                    if (doc is PdfBookDocument) {
                      _pdfController.goToPage(
                        pageNumber: doc.currentLocator.pageIndex,
                      );
                    } else {
                      _epubPageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                    setState(() {});
                  }
                : null,
          ),
          Expanded(
            child: Text(
              isPdf
                  ? l10n.bookReaderPageOf(
                      doc.currentLocator.pageIndex,
                      doc.pageCount,
                    )
                  : l10n.bookReaderChapterOf(
                      doc.currentLocator.pageIndex,
                      doc.pageCount,
                    ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: doc.currentLocator.pageIndex < doc.pageCount
                ? () async {
                    await doc.goToPage(doc.currentLocator.pageIndex + 1);
                    if (doc is PdfBookDocument) {
                      _pdfController.goToPage(
                        pageNumber: doc.currentLocator.pageIndex,
                      );
                    } else {
                      _epubPageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                    setState(() {});
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddBookmarkDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController labelCtrl = TextEditingController();
    final String? label = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.bookBookmarkAdd),
        content: TextField(
          controller: labelCtrl,
          decoration: InputDecoration(hintText: l10n.bookBookmarkLabelHint),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              ctx,
            ).pop(labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (label == null || !mounted) return;
    await ref
        .read(bookRepositoryProvider)
        .addBookmark(
          bookUri: _doc!.metadata.uri,
          label: label,
          locator: _doc!.currentLocator,
        );
  }

  Future<void> _showBookmarkList(BuildContext context) async {
    if (_doc == null) return;
    // Capture l10n before the async gap so the context is not used after await.
    final l10n = AppLocalizations.of(context)!;

    final List<BookBookmark> marks = await ref
        .read(bookRepositoryProvider)
        .listBookmarks(_doc!.metadata.uri);

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: this.context,
      builder: (BuildContext ctx) => _BookmarkSheet(
        bookmarks: marks,
        l10n: l10n,
        onJump: (BookBookmark bm) async {
          Navigator.of(ctx).pop();
          await _doc!.goToPage(bm.locator.pageIndex);
          setState(() {});
        },
        onDelete: (BookBookmark bm) async {
          await ref.read(bookRepositoryProvider).deleteBookmark(bm.id);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _BookmarkSheet extends StatelessWidget {
  const _BookmarkSheet({
    required this.bookmarks,
    required this.l10n,
    required this.onJump,
    required this.onDelete,
  });

  final List<BookBookmark> bookmarks;
  final AppLocalizations l10n;
  final Future<void> Function(BookBookmark) onJump;
  final Future<void> Function(BookBookmark) onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.bookBookmarkList,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (bookmarks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.bookBookmarkEmpty),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: bookmarks.length,
                itemBuilder: (BuildContext ctx, int i) {
                  final BookBookmark bm = bookmarks[i];
                  return ListTile(
                    title: Text(bm.label),
                    subtitle: Text(bm.locator.toString()),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.bookBookmarkDelete,
                      onPressed: () => onDelete(bm),
                    ),
                    onTap: () => onJump(bm),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

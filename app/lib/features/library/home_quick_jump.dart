import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'home_section.dart';

class HomeQuickJumpBar extends StatelessWidget {
  const HomeQuickJumpBar({
    super.key,
    required this.sections,
    required this.onSelected,
  });

  final List<HomeSection> sections;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final destinations = <String, (String, IconData)>{
      'video': (l10n.homeQuickJumpVideo, Icons.movie_outlined),
      'audio': (l10n.homeQuickJumpAudio, Icons.music_note_outlined),
      'novel': (l10n.homeQuickJumpNovel, Icons.auto_stories_outlined),
      'book': (l10n.homeQuickJumpBook, Icons.menu_book_outlined),
      'manga': (l10n.homeQuickJumpManga, Icons.collections_bookmark_outlined),
      'media_library': (
        l10n.homeQuickJumpMediaLibrary,
        Icons.video_library_outlined,
      ),
    };

    return Semantics(
      container: true,
      label: l10n.homeQuickJumpSemanticLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Row(
            children: [
              for (final section in sections)
                if (destinations[section.id] case final destination?)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: AppSizes.minTouchTarget,
                        minHeight: AppSizes.minTouchTarget,
                      ),
                      child: ActionChip(
                        avatar: Icon(destination.$2),
                        label: Text(destination.$1),
                        tooltip: destination.$1,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        visualDensity: VisualDensity.standard,
                        onPressed: () => onSelected(section.id),
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

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get errorNetworkUnreachable =>
      'Cannot connect to the network. Please check your connection.';

  @override
  String errorRateLimit(int seconds) {
    return 'Too many requests. Please retry in $seconds seconds.';
  }

  @override
  String errorSiteConsentRequired(String site) {
    return 'Using $site requires site-specific consent. Please grant consent in Settings.';
  }

  @override
  String get errorRobotsDisallowed =>
      'Access to this page is disallowed by robots.txt.';

  @override
  String get errorHtmlParse =>
      'Failed to parse the page. The site structure may have changed.';

  @override
  String get errorFileNotFound =>
      'File not found. It may have been moved or deleted.';

  @override
  String get errorUnsupportedFormat => 'This file format is not supported.';

  @override
  String get errorUpstreamUnavailable =>
      'Cannot reach the server. Please try again later.';

  @override
  String get errorStorageQuota =>
      'Not enough storage space. Please free up some space.';

  @override
  String get errorUnknown => 'An unexpected error occurred.';

  @override
  String get actionRetry => 'Retry';

  @override
  String get errorBoundaryRestartPrompt => 'Please restart the app';

  @override
  String get settingsTitle => 'Settings';

  @override
  String settingsLoadError(Object error) {
    return 'Failed to load settings: $error';
  }

  @override
  String get settingsSectionDisplay => 'Display';

  @override
  String get settingsSectionPlayback => 'Playback';

  @override
  String get settingsSectionVideo => 'Video';

  @override
  String get settingsSectionAudio => 'Audio';

  @override
  String get settingsSectionNovel => 'Novel';

  @override
  String get settingsSectionLibrary => 'Library';

  @override
  String get settingsSectionCache => 'Cache';

  @override
  String get settingsSectionOnlineServices => 'Online Services';

  @override
  String get settingsSectionR18 => 'R18';

  @override
  String get settingsNextLaunchHelper => 'Changes take effect on next launch';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsAccentColorPlaceholder => 'Accent Color';

  @override
  String get settingsAccentColorComingSoon => 'Coming in v0.2';

  @override
  String get settingsDefaultPlaybackSpeed => 'Default Playback Speed';

  @override
  String get settingsSubtitlesByDefault => 'Show subtitles by default';

  @override
  String get settingsAudioBackgroundPlayback => 'Background Playback';

  @override
  String get settingsAudioNotificationPersistent => 'Keep notification visible';

  @override
  String get settingsNovelWritingMode => 'Writing Direction';

  @override
  String get settingsNovelWritingModeVertical => 'Vertical';

  @override
  String get settingsNovelWritingModeHorizontal => 'Horizontal';

  @override
  String settingsNovelFontSize(String size) {
    return 'Font size: $size sp';
  }

  @override
  String settingsNovelLineHeight(String height) {
    return 'Line height: $height';
  }

  @override
  String get settingsNovelFont => 'Font';

  @override
  String get settingsNovelBgLight => 'Background (Light)';

  @override
  String get settingsNovelBgDark => 'Background (Dark)';

  @override
  String get settingsRecentItemsCap => '\"Recent\" limit';

  @override
  String get settingsClearHistory => 'Clear all history';

  @override
  String get settingsClearHistoryConfirmTitle => 'Clear all history?';

  @override
  String get settingsClearHistoryIrreversible =>
      'This action cannot be undone.';

  @override
  String get settingsCacheSizeLabel => 'Cache size';

  @override
  String get settingsCacheCapMb => 'Cache limit (MB)';

  @override
  String get settingsCacheCapUnlimited => 'Unlimited';

  @override
  String get settingsCacheOverBanner => 'Cache exceeds the limit';

  @override
  String get settingsCacheDeleteOldest => 'Delete oldest';

  @override
  String settingsCacheClearSite(String site) {
    return 'Clear $site cache';
  }

  @override
  String settingsCacheClearSiteConfirmTitle(String site) {
    return 'Delete $site cache?';
  }

  @override
  String get settingsCacheClearAll => 'Clear all';

  @override
  String get settingsCacheClearAllConfirmTitle =>
      'Delete all novel body cache?';

  @override
  String get settingsOnlineServicesDisclosure =>
      'This app fetches novel content from Narou / Nocturne / Kakuyomu for personal use only. Use only within the scope of each site\'s terms of service.';

  @override
  String get settingsRevokeKeepCache => 'Keep';

  @override
  String get settingsRevokeDeleteCache => 'Delete';

  @override
  String settingsRevokeCachePrompt(String sizeMb) {
    return 'Also delete body cache ($sizeMb MB)?';
  }

  @override
  String get settingsR18Status => 'Age verification status';

  @override
  String get settingsR18StatusGranted => 'Consented';

  @override
  String get settingsR18StatusDenied => 'Not consented';

  @override
  String get settingsR18Reset => 'Reset age verification';

  @override
  String get settingsR18ResetConfirmTitle => 'Reset age verification?';

  @override
  String get settingsR18ResetConfirmBody =>
      'You will be prompted again the next time you open an R18 site.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionReset => 'Reset';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutBuildNumber => 'Build Number';

  @override
  String get aboutCommit => 'Commit';

  @override
  String get aboutApacheLicenseTitle => 'Apache-2.0 License';

  @override
  String get aboutLinkGithub => 'GitHub Repository';

  @override
  String get aboutLinkRoadmap => 'Roadmap';

  @override
  String get aboutLinkLicense => 'Full License';

  @override
  String get aboutOssLicenses => 'OSS Licenses';

  @override
  String get aboutLinkOpenError => 'Could not open link';

  @override
  String get aboutLicenseScreenTitle => 'GeekPlayer — Full License';

  @override
  String get aboutSettingsLicense => 'License';

  @override
  String get aboutSettingsOssNotices => 'OSS Notices';

  @override
  String get ossLicensesScreenTitle => 'OSS Licenses';

  @override
  String get ossLicensesApacheNoticeBody =>
      'GeekPlayer is distributed under the Apache License 2.0.';

  @override
  String get lgplNoticeTitle => 'LGPL-2.1+ Notice (libmpv)';

  @override
  String get lgplNoticeBody =>
      'GeekPlayer uses libmpv as its video playback engine, dynamically linked via media_kit. libmpv is distributed under LGPL-2.1+.';

  @override
  String get lgplNoticeRights =>
      'Under the terms of LGPL-2.1+, you have the right to independently modify and rebuild only the libmpv portion and replace it without rebuilding GeekPlayer itself. The replaced libmpv may be redistributed under the terms of LGPL.';

  @override
  String get lgplNoticeReplacementTitle =>
      'Replacement instructions (overview)';

  @override
  String get lgplNoticeReplacementBody =>
      '· macOS: Replace Mpv.framework / libmpv.dylib under Contents/Frameworks/ in the app bundle\n· Windows: Replace mpv-2.dll in the same directory as GeekPlayer.exe\n· Android: Replace lib/<abi>/libmpv.so inside the APK and re-sign it';

  @override
  String get lgplUpstreamLink => 'Upstream source (mpv-player/mpv)';

  @override
  String get lgplThirdPartyLink => 'See THIRD_PARTY_NOTICES for details';

  @override
  String get lgplFullTextLink => 'LGPL-2.1 full text';

  @override
  String get lgplLicenseScreenTitle => 'LGPL-2.1 Full Text';

  @override
  String get consentDialogTitle => 'Consent for Online Novel Sites';

  @override
  String get consentDialogBody =>
      'This app communicates with the following sites to fetch novels. Following ADR-0001 / ADR-0003, it performs active caching (only works the user selects \"Add to Library\") and respects each site\'s rate limits (Kakuyomu: 1 req / 2 s) and robots.txt.\n\nKakuyomu content is fetched by parsing HTML. Fetching may fail if the site structure changes.';

  @override
  String get consentPolicyUpdatedBanner => 'Policy has been updated';

  @override
  String get consentDenyAll => 'Deny all';

  @override
  String get consentConfirm => 'Confirm';

  @override
  String get kakuyomuConsentDialogTitle => 'Consent for Kakuyomu';

  @override
  String get kakuyomuConsentDialogIntro =>
      'This app communicates with the official Kakuyomu site with your consent to fetch novel information and content. It operates according to the following guidelines:';

  @override
  String get kakuyomuConsentBullet1 =>
      'Personal use only. No large-scale crawling or passive mirroring.';

  @override
  String get kakuyomuConsentBullet2 =>
      'Active caching only. Only content from works the user adds to the Library is saved.';

  @override
  String get kakuyomuConsentBullet3 =>
      'Access to Kakuyomu is limited to 1 request / 2 seconds, concurrency 1.';

  @override
  String get kakuyomuConsentBullet4 =>
      'robots.txt Disallow entries are respected with a 24-hour cache.';

  @override
  String get kakuyomuConsentBullet5 =>
      'GeekPlayer\'s version and contact URL are included in the User-Agent.';

  @override
  String get kakuyomuConsentBullet6 =>
      'On receiving 429 / 503, retries with exponential backoff (max 5 min), giving up after 6 attempts.';

  @override
  String get kakuyomuConsentFooter =>
      'See ADR-0001 / README Kakuyomu feature notes for details. If Kakuyomu\'s official ToS explicitly prohibits automated collection in the future, this feature will be immediately disabled.';

  @override
  String get kakuyomuConsentDecline => 'Decline';

  @override
  String get kakuyomuConsentAccept => 'Accept';

  @override
  String get kakuyomuConsentRequiredTitle => 'Kakuyomu';

  @override
  String get kakuyomuConsentRequiredMessage =>
      'Consent for Kakuyomu is required.';

  @override
  String get kakuyomuConsentRequiredShowDialog => 'Show consent dialog';

  @override
  String get kakuyomuConsentRequiredOpenSettings => 'Open Settings';

  @override
  String get novelHomeSectionTitle => 'Online Novel Library';

  @override
  String get novelHomeSectionSettingsTooltip => 'Online Novel Settings';

  @override
  String get novelLibraryEmpty => 'No novels in Library yet.';

  @override
  String get novelConsentDisabledBanner =>
      'Consent disabled — re-consent in Settings';

  @override
  String get siteFilterAll => 'All';

  @override
  String get bookHomeSectionTitle => 'Local Books';

  @override
  String get bookHomeSectionEmpty =>
      'No books yet. Tap + to open a PDF or EPUB.';

  @override
  String get bookHomeSectionAddTooltip => 'Add book';

  @override
  String get bookReaderTitle => 'Book Reader';

  @override
  String bookReaderPageOf(int current, int total) {
    return '$current / $total pages';
  }

  @override
  String bookReaderChapterOf(int current, int total) {
    return '$current / $total chapters';
  }

  @override
  String get bookBookmarkAdd => 'Add bookmark';

  @override
  String get bookBookmarkList => 'Bookmarks';

  @override
  String get bookBookmarkEmpty => 'No bookmarks yet.';

  @override
  String get bookBookmarkDelete => 'Delete';

  @override
  String get bookBookmarkLabelHint => 'Bookmark name';

  @override
  String get bookOpenPickerTitle => 'Select a book';

  @override
  String get bookFileNotFoundMessage =>
      'File not found. It may have been moved or deleted.';

  @override
  String get bookFileNotFoundReimport => 'Re-import';

  @override
  String get bookDeleteConfirmTitle => 'Delete book?';

  @override
  String get bookDeleteConfirmBody =>
      'All reading progress and bookmarks will be removed. The file itself will not be deleted.';

  @override
  String get mangaHomeSectionTitle => 'Local Manga';

  @override
  String get mangaHomeSectionEmpty =>
      'No manga yet. Tap + to open a ZIP or CBZ archive.';

  @override
  String get mangaHomeSectionAddTooltip => 'Add manga';

  @override
  String get mangaViewerTitle => 'Manga Viewer';

  @override
  String mangaViewerPageOf(int current, int total) {
    return '$current / $total pages';
  }

  @override
  String get mangaBookmarkAdd => 'Add bookmark';

  @override
  String get mangaBookmarkList => 'Bookmarks';

  @override
  String get mangaBookmarkEmpty => 'No bookmarks yet.';

  @override
  String get mangaBookmarkDelete => 'Delete';

  @override
  String get mangaBookmarkLabelHint => 'Bookmark name';

  @override
  String get mangaOpenPickerTitle => 'Select a manga archive';

  @override
  String get mangaFileNotFoundMessage =>
      'File not found. It may have been moved or deleted.';

  @override
  String get mangaDeleteConfirmTitle => 'Delete manga?';

  @override
  String get mangaDeleteConfirmBody =>
      'All reading progress and bookmarks will be removed. The file itself will not be deleted.';

  @override
  String get mangaErrorCorruptArchive =>
      'Could not read the archive. The file may be corrupt.';

  @override
  String get mangaErrorNoPages =>
      'This archive contains no supported image pages.';

  @override
  String get mangaErrorOversized => 'The archive exceeds the size limit.';

  @override
  String get settingsSectionManga => 'Manga';

  @override
  String get settingsMangaReadingDirection => 'Reading direction';

  @override
  String get settingsMangaReadingDirectionRtl =>
      'Right to left (Japanese manga)';

  @override
  String get settingsMangaReadingDirectionLtr =>
      'Left to right (Western comics)';

  @override
  String get settingsMangaSpreadMode => 'Spread layout';

  @override
  String get settingsMangaSpreadModeSingle => 'Single page';

  @override
  String get settingsMangaSpreadModeSpread => 'Two-page spread';

  @override
  String get settingsMangaZoomReset => 'Reset zoom on page change';
}

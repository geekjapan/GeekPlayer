import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// Shown when a network call fails because the device is offline or the host is unreachable.
  ///
  /// In ja, this message translates to:
  /// **'ネットワークに接続できません。接続を確認してください。'**
  String get errorNetworkUnreachable;

  /// Shown when an upstream returns 429 / Retry-After. Interpolates seconds remaining before retry.
  ///
  /// In ja, this message translates to:
  /// **'リクエストが多すぎます。{seconds}秒後に再試行してください。'**
  String errorRateLimit(int seconds);

  /// Shown when a site requires the user to grant explicit consent (e.g. kakuyomu).
  ///
  /// In ja, this message translates to:
  /// **'{site}の利用にはサイト固有の同意が必要です。設定から同意してください。'**
  String errorSiteConsentRequired(String site);

  /// Shown when robots.txt forbids fetching the requested path.
  ///
  /// In ja, this message translates to:
  /// **'このページは robots.txt によりアクセスが禁止されています。'**
  String get errorRobotsDisallowed;

  /// Shown when an HTML parser cannot extract the expected fields.
  ///
  /// In ja, this message translates to:
  /// **'ページの解析に失敗しました。サイト構造が変わった可能性があります。'**
  String get errorHtmlParse;

  /// Shown when a local file referenced by the app no longer exists.
  ///
  /// In ja, this message translates to:
  /// **'ファイルが見つかりません。移動・削除された可能性があります。'**
  String get errorFileNotFound;

  /// Shown when the user opens a file whose format the app cannot decode.
  ///
  /// In ja, this message translates to:
  /// **'このファイル形式には対応していません。'**
  String get errorUnsupportedFormat;

  /// Shown when an upstream API returns 5xx or otherwise fails.
  ///
  /// In ja, this message translates to:
  /// **'サーバーに接続できません。時間をおいて再度お試しください。'**
  String get errorUpstreamUnavailable;

  /// Shown when local storage cannot accommodate a write (e.g. drift DB / cache).
  ///
  /// In ja, this message translates to:
  /// **'ストレージ容量が不足しています。空き容量を確保してください。'**
  String get errorStorageQuota;

  /// Generic fallback for errors that do not match any specific variant.
  ///
  /// In ja, this message translates to:
  /// **'予期しないエラーが発生しました。'**
  String get errorUnknown;

  /// Button / SnackBarAction label asking the user to retry the failed operation.
  ///
  /// In ja, this message translates to:
  /// **'再試行'**
  String get actionRetry;

  /// Shown by the release-mode ErrorBoundary fallback when widget build fails.
  ///
  /// In ja, this message translates to:
  /// **'アプリを再起動してください'**
  String get errorBoundaryRestartPrompt;

  /// Title of the Settings screen app bar.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settingsTitle;

  /// Shown in the Settings screen body when AppSettings fails to load.
  ///
  /// In ja, this message translates to:
  /// **'設定の読み込みに失敗しました: {error}'**
  String settingsLoadError(Object error);

  /// Section title for the Display settings section.
  ///
  /// In ja, this message translates to:
  /// **'表示'**
  String get settingsSectionDisplay;

  /// Section title for the Playback settings section.
  ///
  /// In ja, this message translates to:
  /// **'再生'**
  String get settingsSectionPlayback;

  /// Section title for the Video settings section.
  ///
  /// In ja, this message translates to:
  /// **'動画'**
  String get settingsSectionVideo;

  /// Section title for the Audio settings section.
  ///
  /// In ja, this message translates to:
  /// **'音楽'**
  String get settingsSectionAudio;

  /// Section title for the Novel settings section.
  ///
  /// In ja, this message translates to:
  /// **'小説'**
  String get settingsSectionNovel;

  /// Section title for the Library settings section.
  ///
  /// In ja, this message translates to:
  /// **'ライブラリ'**
  String get settingsSectionLibrary;

  /// Section title for the Cache settings section.
  ///
  /// In ja, this message translates to:
  /// **'キャッシュ'**
  String get settingsSectionCache;

  /// Section title for the Online Services settings section.
  ///
  /// In ja, this message translates to:
  /// **'オンラインサービス'**
  String get settingsSectionOnlineServices;

  /// Section title for the R18 settings section.
  ///
  /// In ja, this message translates to:
  /// **'R18'**
  String get settingsSectionR18;

  /// Hint text shown under settings tiles whose change takes effect only on next launch.
  ///
  /// In ja, this message translates to:
  /// **'変更は次回起動から有効になります'**
  String get settingsNextLaunchHelper;

  /// Label for the system/auto theme mode option.
  ///
  /// In ja, this message translates to:
  /// **'システム'**
  String get settingsThemeSystem;

  /// Label for the light theme mode option.
  ///
  /// In ja, this message translates to:
  /// **'ライト'**
  String get settingsThemeLight;

  /// Label for the dark theme mode option.
  ///
  /// In ja, this message translates to:
  /// **'ダーク'**
  String get settingsThemeDark;

  /// Label for the accent color setting (not yet implemented).
  ///
  /// In ja, this message translates to:
  /// **'アクセントカラー'**
  String get settingsAccentColorPlaceholder;

  /// Chip label indicating the accent color setting is coming in v0.2.
  ///
  /// In ja, this message translates to:
  /// **'v0.2 で対応'**
  String get settingsAccentColorComingSoon;

  /// Label for the default playback speed setting tile.
  ///
  /// In ja, this message translates to:
  /// **'デフォルト再生速度'**
  String get settingsDefaultPlaybackSpeed;

  /// Label for the subtitles-by-default switch.
  ///
  /// In ja, this message translates to:
  /// **'字幕を最初から表示する'**
  String get settingsSubtitlesByDefault;

  /// Label for the audio background playback switch.
  ///
  /// In ja, this message translates to:
  /// **'バックグラウンド再生'**
  String get settingsAudioBackgroundPlayback;

  /// Label for the audio notification persistent switch.
  ///
  /// In ja, this message translates to:
  /// **'通知を継続表示'**
  String get settingsAudioNotificationPersistent;

  /// Label for the novel writing mode (vertical/horizontal) setting tile.
  ///
  /// In ja, this message translates to:
  /// **'書字方向'**
  String get settingsNovelWritingMode;

  /// Label for the vertical writing mode option.
  ///
  /// In ja, this message translates to:
  /// **'縦書き'**
  String get settingsNovelWritingModeVertical;

  /// Label for the horizontal writing mode option.
  ///
  /// In ja, this message translates to:
  /// **'横書き'**
  String get settingsNovelWritingModeHorizontal;

  /// Label for the novel font size tile, interpolating the current size.
  ///
  /// In ja, this message translates to:
  /// **'文字サイズ: {size} sp'**
  String settingsNovelFontSize(String size);

  /// Label for the novel line height tile, interpolating the current value.
  ///
  /// In ja, this message translates to:
  /// **'行間: {height}'**
  String settingsNovelLineHeight(String height);

  /// Label for the novel font family setting tile.
  ///
  /// In ja, this message translates to:
  /// **'フォント'**
  String get settingsNovelFont;

  /// Label for the novel background color (light mode) setting tile.
  ///
  /// In ja, this message translates to:
  /// **'背景色 (ライト)'**
  String get settingsNovelBgLight;

  /// Label for the novel background color (dark mode) setting tile.
  ///
  /// In ja, this message translates to:
  /// **'背景色 (ダーク)'**
  String get settingsNovelBgDark;

  /// Label for the recent items cap setting tile.
  ///
  /// In ja, this message translates to:
  /// **'\"最近開いた\" の上限'**
  String get settingsRecentItemsCap;

  /// Label for the clear-all-history settings tile.
  ///
  /// In ja, this message translates to:
  /// **'履歴をすべてクリア'**
  String get settingsClearHistory;

  /// Title of the confirmation dialog for clearing all history.
  ///
  /// In ja, this message translates to:
  /// **'履歴をすべて削除しますか?'**
  String get settingsClearHistoryConfirmTitle;

  /// Body text in destructive confirmation dialogs stating the action cannot be undone.
  ///
  /// In ja, this message translates to:
  /// **'この操作は取り消せません。'**
  String get settingsClearHistoryIrreversible;

  /// Label for the cache size display tile.
  ///
  /// In ja, this message translates to:
  /// **'キャッシュサイズ'**
  String get settingsCacheSizeLabel;

  /// Label for the cache cap in MB setting tile.
  ///
  /// In ja, this message translates to:
  /// **'キャッシュ上限 (MB)'**
  String get settingsCacheCapMb;

  /// Label for the unlimited cache cap choice chip.
  ///
  /// In ja, this message translates to:
  /// **'無制限'**
  String get settingsCacheCapUnlimited;

  /// Banner text shown when novel cache exceeds the configured cap.
  ///
  /// In ja, this message translates to:
  /// **'キャッシュが上限を超えています'**
  String get settingsCacheOverBanner;

  /// Button label to delete oldest cache entries until under the cap.
  ///
  /// In ja, this message translates to:
  /// **'古い順に削除'**
  String get settingsCacheDeleteOldest;

  /// Label for the per-site cache clear tile.
  ///
  /// In ja, this message translates to:
  /// **'{site} のキャッシュをクリア'**
  String settingsCacheClearSite(String site);

  /// Title of the confirmation dialog for clearing a site's cache.
  ///
  /// In ja, this message translates to:
  /// **'{site} のキャッシュを削除しますか?'**
  String settingsCacheClearSiteConfirmTitle(String site);

  /// Label for the clear-all-cache tile.
  ///
  /// In ja, this message translates to:
  /// **'すべてクリア'**
  String get settingsCacheClearAll;

  /// Title of the confirmation dialog for clearing all novel body cache.
  ///
  /// In ja, this message translates to:
  /// **'すべての本文キャッシュを削除しますか?'**
  String get settingsCacheClearAllConfirmTitle;

  /// ADR-0001 permanent disclosure text shown at the top of the Online Services section.
  ///
  /// In ja, this message translates to:
  /// **'本アプリは個人利用目的でなろう / ノクターン系 / カクヨムから 本文を取得します。各サイトの利用規約に同意した範囲でのみ 利用してください。'**
  String get settingsOnlineServicesDisclosure;

  /// Button label to keep the cache when revoking site consent.
  ///
  /// In ja, this message translates to:
  /// **'残す'**
  String get settingsRevokeKeepCache;

  /// Button label to delete the cache when revoking site consent.
  ///
  /// In ja, this message translates to:
  /// **'削除する'**
  String get settingsRevokeDeleteCache;

  /// Body of the dialog asking whether to delete cache when revoking consent.
  ///
  /// In ja, this message translates to:
  /// **'本文キャッシュ ({sizeMb} MB) も削除しますか?'**
  String settingsRevokeCachePrompt(String sizeMb);

  /// Label for the R18 age-gate status display tile.
  ///
  /// In ja, this message translates to:
  /// **'年齢確認の状態'**
  String get settingsR18Status;

  /// R18 age-gate status when consent has been granted.
  ///
  /// In ja, this message translates to:
  /// **'同意済み'**
  String get settingsR18StatusGranted;

  /// R18 age-gate status when consent has not been granted.
  ///
  /// In ja, this message translates to:
  /// **'未同意'**
  String get settingsR18StatusDenied;

  /// Label for the R18 age-gate reset tile.
  ///
  /// In ja, this message translates to:
  /// **'年齢確認をやり直す'**
  String get settingsR18Reset;

  /// Title of the confirmation dialog for resetting R18 age-gate consent.
  ///
  /// In ja, this message translates to:
  /// **'年齢確認をやり直しますか?'**
  String get settingsR18ResetConfirmTitle;

  /// Body of the R18 age-gate reset confirmation dialog.
  ///
  /// In ja, this message translates to:
  /// **'次回 R18 サイトを開く際に確認画面が表示されます。'**
  String get settingsR18ResetConfirmBody;

  /// Generic cancel button label used in confirmation dialogs.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get actionCancel;

  /// Generic destructive confirm button label used in confirmation dialogs.
  ///
  /// In ja, this message translates to:
  /// **'削除する'**
  String get actionDelete;

  /// Button label used in the R18 reset confirmation dialog.
  ///
  /// In ja, this message translates to:
  /// **'リセットする'**
  String get actionReset;

  /// Title of the About screen app bar.
  ///
  /// In ja, this message translates to:
  /// **'アプリ情報'**
  String get aboutTitle;

  /// Label for the version row in the About / Settings About section.
  ///
  /// In ja, this message translates to:
  /// **'バージョン'**
  String get aboutVersion;

  /// Label for the build number row in the About screen.
  ///
  /// In ja, this message translates to:
  /// **'ビルド番号'**
  String get aboutBuildNumber;

  /// Label for the commit SHA row in the About screen.
  ///
  /// In ja, this message translates to:
  /// **'コミット'**
  String get aboutCommit;

  /// Title text for the Apache-2.0 license notice card in the About screen.
  ///
  /// In ja, this message translates to:
  /// **'Apache-2.0 ライセンス'**
  String get aboutApacheLicenseTitle;

  /// List tile label for the GitHub repository link.
  ///
  /// In ja, this message translates to:
  /// **'GitHub リポジトリ'**
  String get aboutLinkGithub;

  /// List tile label for the roadmap link.
  ///
  /// In ja, this message translates to:
  /// **'ロードマップ'**
  String get aboutLinkRoadmap;

  /// List tile label for the full license text link.
  ///
  /// In ja, this message translates to:
  /// **'ライセンス全文'**
  String get aboutLinkLicense;

  /// List tile label for the OSS licenses screen entry.
  ///
  /// In ja, this message translates to:
  /// **'OSS ライセンス'**
  String get aboutOssLicenses;

  /// SnackBar message shown when a URL cannot be launched.
  ///
  /// In ja, this message translates to:
  /// **'リンクを開けませんでした'**
  String get aboutLinkOpenError;

  /// App bar title for the bundled full-license detail screen.
  ///
  /// In ja, this message translates to:
  /// **'GeekPlayer — ライセンス全文'**
  String get aboutLicenseScreenTitle;

  /// Label for the license tile in the Settings About section.
  ///
  /// In ja, this message translates to:
  /// **'ライセンス'**
  String get aboutSettingsLicense;

  /// Label for the OSS Notices tile in the Settings About section.
  ///
  /// In ja, this message translates to:
  /// **'OSS Notices'**
  String get aboutSettingsOssNotices;

  /// App bar title for the OSS license list screen.
  ///
  /// In ja, this message translates to:
  /// **'OSS ライセンス'**
  String get ossLicensesScreenTitle;

  /// Body text in the Apache-2.0 NOTICE card on the OSS licenses screen.
  ///
  /// In ja, this message translates to:
  /// **'GeekPlayer 本体は Apache License 2.0 で配布されています。'**
  String get ossLicensesApacheNoticeBody;

  /// Card title for the LGPL notice section on the OSS licenses screen.
  ///
  /// In ja, this message translates to:
  /// **'LGPL-2.1+ 通知 (libmpv)'**
  String get lgplNoticeTitle;

  /// First paragraph of the LGPL notice explaining how libmpv is used.
  ///
  /// In ja, this message translates to:
  /// **'GeekPlayer は動画再生エンジンとして libmpv を採用しており、media_kit を介して 動的リンク で利用しています。libmpv は LGPL-2.1+ で配布されています。'**
  String get lgplNoticeBody;

  /// Second paragraph of the LGPL notice explaining user replacement rights.
  ///
  /// In ja, this message translates to:
  /// **'利用者は LGPL-2.1+ の規定により、libmpv 部分のみを独立に修正・再構築 し、GeekPlayer 本体を再ビルドせずに 差し替える権利 を持ちます。差し替えた libmpv は LGPL の条件下で再配布できます。'**
  String get lgplNoticeRights;

  /// Sub-title for the replacement instructions in the LGPL notice.
  ///
  /// In ja, this message translates to:
  /// **'差し替え手順 (概要)'**
  String get lgplNoticeReplacementTitle;

  /// Per-platform replacement instructions for libmpv.
  ///
  /// In ja, this message translates to:
  /// **'・macOS: アプリバンドル内 Contents/Frameworks/ 配下の Mpv.framework / libmpv.dylib を差し替え\n・Windows: GeekPlayer.exe と同じディレクトリの mpv-2.dll を差し替え\n・Android: APK 内 lib/<abi>/libmpv.so を差し替えた上で APK を再署名'**
  String get lgplNoticeReplacementBody;

  /// Link label for the libmpv upstream source.
  ///
  /// In ja, this message translates to:
  /// **'上流ソース (mpv-player/mpv)'**
  String get lgplUpstreamLink;

  /// Link label for THIRD_PARTY_NOTICES document.
  ///
  /// In ja, this message translates to:
  /// **'詳細は THIRD_PARTY_NOTICES を参照'**
  String get lgplThirdPartyLink;

  /// Link label for the bundled LGPL-2.1 full text.
  ///
  /// In ja, this message translates to:
  /// **'LGPL-2.1 全文'**
  String get lgplFullTextLink;

  /// App bar title for the LGPL-2.1 full-text license detail screen.
  ///
  /// In ja, this message translates to:
  /// **'LGPL-2.1 全文'**
  String get lgplLicenseScreenTitle;

  /// Title of the first-launch multi-site consent dialog.
  ///
  /// In ja, this message translates to:
  /// **'オンライン小説サイトへの同意'**
  String get consentDialogTitle;

  /// Body of the first-launch consent dialog explaining data access policy.
  ///
  /// In ja, this message translates to:
  /// **'本アプリは以下のサイトと通信して小説を取得します。ADR-0001 / ADR-0003 に従い、能動キャッシュ (利用者が「ライブラリに追加」を選択した作品のみ) を行い、各サイトのレート制限 (カクヨムは 1 req / 2 s) と robots.txt を尊重します。\n\nカクヨム本文は HTML をパースして取得します。サイト構造の変更で取得が失敗することがあります。'**
  String get consentDialogBody;

  /// Banner shown in the consent dialog when re-prompted due to a policy update.
  ///
  /// In ja, this message translates to:
  /// **'ポリシーが更新されました'**
  String get consentPolicyUpdatedBanner;

  /// Button label to deny consent for all sites in the consent dialog.
  ///
  /// In ja, this message translates to:
  /// **'すべて拒否'**
  String get consentDenyAll;

  /// Button label to confirm the consent choices in the consent dialog.
  ///
  /// In ja, this message translates to:
  /// **'決定'**
  String get consentConfirm;

  /// Title of the Kakuyomu-specific consent dialog.
  ///
  /// In ja, this message translates to:
  /// **'カクヨムへの同意'**
  String get kakuyomuConsentDialogTitle;

  /// Introductory sentence in the Kakuyomu consent dialog.
  ///
  /// In ja, this message translates to:
  /// **'本アプリは、利用者の同意のもとでカクヨム公式サイトと通信して小説情報および本文を取得します。下記の運用規範に沿って動作します:'**
  String get kakuyomuConsentDialogIntro;

  /// First bullet point in the Kakuyomu consent dialog.
  ///
  /// In ja, this message translates to:
  /// **'個人利用に限定。大規模クロール / 受動的ミラーリングは行いません。'**
  String get kakuyomuConsentBullet1;

  /// Second bullet point in the Kakuyomu consent dialog.
  ///
  /// In ja, this message translates to:
  /// **'能動キャッシュのみ。ユーザーが「Library に追加」した作品の本文だけを保存します。'**
  String get kakuyomuConsentBullet2;

  /// Third bullet point in the Kakuyomu consent dialog.
  ///
  /// In ja, this message translates to:
  /// **'カクヨムへのアクセスは 1 リクエスト / 2 秒、並列度 1 に制限されます。'**
  String get kakuyomuConsentBullet3;

  /// Fourth bullet point in the Kakuyomu consent dialog.
  ///
  /// In ja, this message translates to:
  /// **'robots.txt の Disallow を 24 時間キャッシュ付きで尊重します。'**
  String get kakuyomuConsentBullet4;

  /// Fifth bullet point in the Kakuyomu consent dialog.
  ///
  /// In ja, this message translates to:
  /// **'User-Agent に GeekPlayer のバージョンと連絡先 URL を明示します。'**
  String get kakuyomuConsentBullet5;

  /// Sixth bullet point in the Kakuyomu consent dialog.
  ///
  /// In ja, this message translates to:
  /// **'429 / 503 を受けたら指数バックオフ (最大 5 分) で再試行し、6 回で諦めます。'**
  String get kakuyomuConsentBullet6;

  /// Footer text in the Kakuyomu consent dialog.
  ///
  /// In ja, this message translates to:
  /// **'詳細は ADR-0001 / README のカクヨム機能の注意事項を参照してください。将来、カクヨム公式 ToS が自動収集を明示禁止した場合は、本機能を即座に停止する方針です。'**
  String get kakuyomuConsentFooter;

  /// Button label to decline Kakuyomu consent.
  ///
  /// In ja, this message translates to:
  /// **'同意しない'**
  String get kakuyomuConsentDecline;

  /// Button label to accept Kakuyomu consent.
  ///
  /// In ja, this message translates to:
  /// **'同意する'**
  String get kakuyomuConsentAccept;

  /// App bar title for the KakuyomuConsentRequiredScreen.
  ///
  /// In ja, this message translates to:
  /// **'カクヨム'**
  String get kakuyomuConsentRequiredTitle;

  /// Message on the KakuyomuConsentRequiredScreen.
  ///
  /// In ja, this message translates to:
  /// **'カクヨムへの同意が必要です。'**
  String get kakuyomuConsentRequiredMessage;

  /// Button label to show the consent dialog from the consent required screen.
  ///
  /// In ja, this message translates to:
  /// **'同意ダイアログを表示'**
  String get kakuyomuConsentRequiredShowDialog;

  /// Button label to open settings from the consent required screen.
  ///
  /// In ja, this message translates to:
  /// **'設定を開く'**
  String get kakuyomuConsentRequiredOpenSettings;

  /// Title heading for the online novel library home section.
  ///
  /// In ja, this message translates to:
  /// **'オンライン小説 Library'**
  String get novelHomeSectionTitle;

  /// Tooltip for the settings icon button in the novel home section.
  ///
  /// In ja, this message translates to:
  /// **'オンライン小説設定'**
  String get novelHomeSectionSettingsTooltip;

  /// Placeholder text shown when the novel library is empty.
  ///
  /// In ja, this message translates to:
  /// **'Library に小説はまだありません。'**
  String get novelLibraryEmpty;

  /// Chip label shown in the library grid when consent for a site is disabled.
  ///
  /// In ja, this message translates to:
  /// **'同意が無効化されています — 設定で再同意'**
  String get novelConsentDisabledBanner;

  /// Label for the 'All sites' filter chip in the novel library.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get siteFilterAll;

  /// Title heading for the local book library home section.
  ///
  /// In ja, this message translates to:
  /// **'ローカル書籍'**
  String get bookHomeSectionTitle;

  /// Placeholder shown in the book home section when no books have been imported.
  ///
  /// In ja, this message translates to:
  /// **'書籍はまだありません。「追加」から PDF または EPUB を開いてください。'**
  String get bookHomeSectionEmpty;

  /// Tooltip for the add-book icon button in the book home section.
  ///
  /// In ja, this message translates to:
  /// **'書籍を追加'**
  String get bookHomeSectionAddTooltip;

  /// App bar title for the book reader screen when no specific title is available.
  ///
  /// In ja, this message translates to:
  /// **'書籍リーダー'**
  String get bookReaderTitle;

  /// Page indicator shown in the book reader. Interpolates current page and total pages.
  ///
  /// In ja, this message translates to:
  /// **'{current} / {total} ページ'**
  String bookReaderPageOf(int current, int total);

  /// Chapter indicator shown in the EPUB reader.
  ///
  /// In ja, this message translates to:
  /// **'{current} / {total} 章'**
  String bookReaderChapterOf(int current, int total);

  /// Tooltip / label for the add-bookmark button in the book reader.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク追加'**
  String get bookBookmarkAdd;

  /// Title of the bookmark list sheet/screen.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク一覧'**
  String get bookBookmarkList;

  /// Placeholder shown when the bookmark list is empty.
  ///
  /// In ja, this message translates to:
  /// **'ブックマークはありません。'**
  String get bookBookmarkEmpty;

  /// Label for the delete button on a bookmark tile.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get bookBookmarkDelete;

  /// Hint text for the bookmark label input field.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク名'**
  String get bookBookmarkLabelHint;

  /// Title of the file picker dialog for selecting a book file.
  ///
  /// In ja, this message translates to:
  /// **'書籍を選択'**
  String get bookOpenPickerTitle;

  /// Message shown when a book file is no longer reachable.
  ///
  /// In ja, this message translates to:
  /// **'ファイルが見つかりません。移動・削除された可能性があります。'**
  String get bookFileNotFoundMessage;

  /// Button label to re-import a missing book file.
  ///
  /// In ja, this message translates to:
  /// **'再インポート'**
  String get bookFileNotFoundReimport;

  /// Title of the confirmation dialog for deleting a book record.
  ///
  /// In ja, this message translates to:
  /// **'書籍を削除しますか?'**
  String get bookDeleteConfirmTitle;

  /// Body of the book-delete confirmation dialog.
  ///
  /// In ja, this message translates to:
  /// **'読書の記録とブックマークがすべて削除されます。ファイル本体は削除されません。'**
  String get bookDeleteConfirmBody;

  /// Title heading for the local manga library home section.
  ///
  /// In ja, this message translates to:
  /// **'ローカルマンガ'**
  String get mangaHomeSectionTitle;

  /// Placeholder shown in the manga home section when no archives have been imported.
  ///
  /// In ja, this message translates to:
  /// **'マンガはまだありません。「追加」から ZIP または CBZ を開いてください。'**
  String get mangaHomeSectionEmpty;

  /// Tooltip for the add-manga icon button in the manga home section.
  ///
  /// In ja, this message translates to:
  /// **'マンガを追加'**
  String get mangaHomeSectionAddTooltip;

  /// App bar title for the manga viewer screen when no specific title is available.
  ///
  /// In ja, this message translates to:
  /// **'マンガビューア'**
  String get mangaViewerTitle;

  /// Page indicator shown in the manga viewer. Interpolates current page and total pages.
  ///
  /// In ja, this message translates to:
  /// **'{current} / {total} ページ'**
  String mangaViewerPageOf(int current, int total);

  /// Tooltip / label for the add-bookmark button in the manga viewer.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク追加'**
  String get mangaBookmarkAdd;

  /// Title of the bookmark list sheet/screen in the manga viewer.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク一覧'**
  String get mangaBookmarkList;

  /// Placeholder shown when the manga bookmark list is empty.
  ///
  /// In ja, this message translates to:
  /// **'ブックマークはありません。'**
  String get mangaBookmarkEmpty;

  /// Label for the delete button on a manga bookmark tile.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get mangaBookmarkDelete;

  /// Hint text for the manga bookmark label input field.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク名'**
  String get mangaBookmarkLabelHint;

  /// Title of the file picker dialog for selecting a manga archive.
  ///
  /// In ja, this message translates to:
  /// **'マンガを選択'**
  String get mangaOpenPickerTitle;

  /// Message shown when a manga archive is no longer reachable.
  ///
  /// In ja, this message translates to:
  /// **'ファイルが見つかりません。移動・削除された可能性があります。'**
  String get mangaFileNotFoundMessage;

  /// Title of the confirmation dialog for deleting a manga record.
  ///
  /// In ja, this message translates to:
  /// **'マンガを削除しますか?'**
  String get mangaDeleteConfirmTitle;

  /// Body of the manga-delete confirmation dialog.
  ///
  /// In ja, this message translates to:
  /// **'読書の記録とブックマークがすべて削除されます。ファイル本体は削除されません。'**
  String get mangaDeleteConfirmBody;

  /// Shown when the manga archive cannot be parsed (corrupt ZIP/CBZ).
  ///
  /// In ja, this message translates to:
  /// **'アーカイブを読み込めませんでした。ファイルが破損している可能性があります。'**
  String get mangaErrorCorruptArchive;

  /// Shown when the archive contains no supported image entries.
  ///
  /// In ja, this message translates to:
  /// **'このアーカイブには対応する画像ページがありません。'**
  String get mangaErrorNoPages;

  /// Shown when the archive exceeds the configured size limit.
  ///
  /// In ja, this message translates to:
  /// **'アーカイブのサイズが上限を超えています。'**
  String get mangaErrorOversized;

  /// Section title for the Manga settings section.
  ///
  /// In ja, this message translates to:
  /// **'マンガ'**
  String get settingsSectionManga;

  /// Label for the manga reading direction setting tile.
  ///
  /// In ja, this message translates to:
  /// **'読み方向'**
  String get settingsMangaReadingDirection;

  /// Label for the right-to-left manga reading direction option.
  ///
  /// In ja, this message translates to:
  /// **'右から左 (日本語マンガ)'**
  String get settingsMangaReadingDirectionRtl;

  /// Label for the left-to-right manga reading direction option.
  ///
  /// In ja, this message translates to:
  /// **'左から右 (洋書コミック)'**
  String get settingsMangaReadingDirectionLtr;

  /// Label for the manga spread mode setting tile.
  ///
  /// In ja, this message translates to:
  /// **'見開き表示'**
  String get settingsMangaSpreadMode;

  /// Label for the single-page manga layout option.
  ///
  /// In ja, this message translates to:
  /// **'1ページ'**
  String get settingsMangaSpreadModeSingle;

  /// Label for the two-page spread manga layout option.
  ///
  /// In ja, this message translates to:
  /// **'見開き (2ページ)'**
  String get settingsMangaSpreadModeSpread;

  /// Label for the manga zoom-reset-on-page-change switch.
  ///
  /// In ja, this message translates to:
  /// **'ページ移動時にズームをリセット'**
  String get settingsMangaZoomReset;

  /// Title heading for the local media library home section.
  ///
  /// In ja, this message translates to:
  /// **'メディアライブラリ'**
  String get mediaLibrarySectionTitle;

  /// Placeholder shown in the media library home section when no items have been scanned.
  ///
  /// In ja, this message translates to:
  /// **'メディアファイルがまだありません。「フォルダスキャン」からフォルダを追加してください。'**
  String get mediaLibrarySectionEmpty;

  /// Tooltip for the folder-scan icon button in the media library home section.
  ///
  /// In ja, this message translates to:
  /// **'フォルダをスキャン'**
  String get mediaLibraryScanTooltip;

  /// Title of the folder-path input dialog.
  ///
  /// In ja, this message translates to:
  /// **'フォルダパスを入力'**
  String get mediaLibraryScanDialogTitle;

  /// Hint text for the folder-path text field in the scan dialog.
  ///
  /// In ja, this message translates to:
  /// **'例: /Users/you/Movies'**
  String get mediaLibraryScanDialogHint;

  /// Confirm button label in the folder-scan dialog.
  ///
  /// In ja, this message translates to:
  /// **'スキャン'**
  String get mediaLibraryScanDialogConfirm;

  /// SnackBar message shown after a folder scan completes. Interpolates the number of indexed files.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件のファイルをインデックスしました'**
  String mediaLibraryScanResult(int count);

  /// Label for the favorites badge or section in the media library.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り'**
  String get mediaLibraryFavoritesLabel;

  /// Label for the playlists entry in the media library.
  ///
  /// In ja, this message translates to:
  /// **'プレイリスト'**
  String get mediaLibraryPlaylistsLabel;

  /// Tooltip / menu label to add an item to favorites.
  ///
  /// In ja, this message translates to:
  /// **'お気に入りに追加'**
  String get mediaLibraryAddFavorite;

  /// Tooltip / menu label to remove an item from favorites.
  ///
  /// In ja, this message translates to:
  /// **'お気に入りから削除'**
  String get mediaLibraryRemoveFavorite;

  /// Label for the create-playlist button.
  ///
  /// In ja, this message translates to:
  /// **'プレイリストを作成'**
  String get mediaLibraryCreatePlaylist;

  /// Title of the confirmation dialog for deleting a playlist.
  ///
  /// In ja, this message translates to:
  /// **'プレイリストを削除しますか?'**
  String get mediaLibraryDeletePlaylistConfirmTitle;

  /// Body of the playlist-delete confirmation dialog.
  ///
  /// In ja, this message translates to:
  /// **'プレイリスト内のすべての項目が削除されます。メディアファイル本体は削除されません。'**
  String get mediaLibraryDeletePlaylistConfirmBody;

  /// Title of the update available banner in the Settings About section.
  ///
  /// In ja, this message translates to:
  /// **'アップデートあり'**
  String get updateAvailableBannerTitle;

  /// Body text of the update available banner, interpolating the latest version string.
  ///
  /// In ja, this message translates to:
  /// **'新しいバージョン {version} が利用可能です。'**
  String updateAvailableBannerBody(String version);

  /// Action button label on the update banner that opens the GitHub release page.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード'**
  String get updateAvailableDownload;

  /// Action button label on the update banner that dismisses it for the current session.
  ///
  /// In ja, this message translates to:
  /// **'後で'**
  String get updateAvailableDismiss;

  /// Progress label shown while the update asset is being downloaded. Interpolates the integer percent complete.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード中… {percent}%'**
  String updateDownloading(int percent);

  /// SnackBar message shown when the update download fails.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロードに失敗しました'**
  String get updateDownloadFailed;

  /// Button label shown after the update file has been downloaded, to hand it off to the OS.
  ///
  /// In ja, this message translates to:
  /// **'インストール / 開く'**
  String get updateInstall;

  /// SnackBar message shown when no release asset matches the running platform.
  ///
  /// In ja, this message translates to:
  /// **'対応アセットが見つかりません'**
  String get updateNoCompatibleAsset;

  /// Tooltip / label for the upscale icon button in the manga viewer AppBar.
  ///
  /// In ja, this message translates to:
  /// **'高画質化'**
  String get mangaUpscaleAction;

  /// Label shown while upscaling is in progress in the manga viewer.
  ///
  /// In ja, this message translates to:
  /// **'高画質化処理中…'**
  String get mangaUpscaleInProgress;

  /// SnackBar message shown when upscaling fails in the manga viewer.
  ///
  /// In ja, this message translates to:
  /// **'高画質化に失敗しました'**
  String get mangaUpscaleError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

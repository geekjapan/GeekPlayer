import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[Locale('ja')];

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
      <String>['ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
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

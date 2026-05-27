// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get errorNetworkUnreachable => 'ネットワークに接続できません。接続を確認してください。';

  @override
  String errorRateLimit(int seconds) {
    return 'リクエストが多すぎます。$seconds秒後に再試行してください。';
  }

  @override
  String errorSiteConsentRequired(String site) {
    return '$siteの利用にはサイト固有の同意が必要です。設定から同意してください。';
  }

  @override
  String get errorRobotsDisallowed => 'このページは robots.txt によりアクセスが禁止されています。';

  @override
  String get errorHtmlParse => 'ページの解析に失敗しました。サイト構造が変わった可能性があります。';

  @override
  String get errorFileNotFound => 'ファイルが見つかりません。移動・削除された可能性があります。';

  @override
  String get errorUnsupportedFormat => 'このファイル形式には対応していません。';

  @override
  String get errorUpstreamUnavailable => 'サーバーに接続できません。時間をおいて再度お試しください。';

  @override
  String get errorStorageQuota => 'ストレージ容量が不足しています。空き容量を確保してください。';

  @override
  String get errorUnknown => '予期しないエラーが発生しました。';

  @override
  String get actionRetry => '再試行';

  @override
  String get errorBoundaryRestartPrompt => 'アプリを再起動してください';
}

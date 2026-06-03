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

  @override
  String get settingsTitle => '設定';

  @override
  String settingsLoadError(Object error) {
    return '設定の読み込みに失敗しました: $error';
  }

  @override
  String get settingsSectionDisplay => '表示';

  @override
  String get settingsSectionPlayback => '再生';

  @override
  String get settingsSectionVideo => '動画';

  @override
  String get settingsSectionAudio => '音楽';

  @override
  String get settingsSectionNovel => '小説';

  @override
  String get settingsSectionLibrary => 'ライブラリ';

  @override
  String get settingsSectionCache => 'キャッシュ';

  @override
  String get settingsSectionOnlineServices => 'オンラインサービス';

  @override
  String get settingsSectionR18 => 'R18';

  @override
  String get settingsNextLaunchHelper => '変更は次回起動から有効になります';

  @override
  String get settingsThemeSystem => 'システム';

  @override
  String get settingsThemeLight => 'ライト';

  @override
  String get settingsThemeDark => 'ダーク';

  @override
  String get settingsAccentColorPlaceholder => 'アクセントカラー';

  @override
  String get settingsAccentColorComingSoon => 'v0.2 で対応';

  @override
  String get settingsDefaultPlaybackSpeed => 'デフォルト再生速度';

  @override
  String get settingsSubtitlesByDefault => '字幕を最初から表示する';

  @override
  String get settingsAudioBackgroundPlayback => 'バックグラウンド再生';

  @override
  String get settingsAudioNotificationPersistent => '通知を継続表示';

  @override
  String get settingsNovelWritingMode => '書字方向';

  @override
  String get settingsNovelWritingModeVertical => '縦書き';

  @override
  String get settingsNovelWritingModeHorizontal => '横書き';

  @override
  String settingsNovelFontSize(String size) {
    return '文字サイズ: $size sp';
  }

  @override
  String settingsNovelLineHeight(String height) {
    return '行間: $height';
  }

  @override
  String get settingsNovelFont => 'フォント';

  @override
  String get settingsNovelBgLight => '背景色 (ライト)';

  @override
  String get settingsNovelBgDark => '背景色 (ダーク)';

  @override
  String get settingsRecentItemsCap => '\"最近開いた\" の上限';

  @override
  String get settingsClearHistory => '履歴をすべてクリア';

  @override
  String get settingsClearHistoryConfirmTitle => '履歴をすべて削除しますか?';

  @override
  String get settingsClearHistoryIrreversible => 'この操作は取り消せません。';

  @override
  String get settingsCacheSizeLabel => 'キャッシュサイズ';

  @override
  String get settingsCacheCapMb => 'キャッシュ上限 (MB)';

  @override
  String get settingsCacheCapUnlimited => '無制限';

  @override
  String get settingsCacheOverBanner => 'キャッシュが上限を超えています';

  @override
  String get settingsCacheDeleteOldest => '古い順に削除';

  @override
  String settingsCacheClearSite(String site) {
    return '$site のキャッシュをクリア';
  }

  @override
  String settingsCacheClearSiteConfirmTitle(String site) {
    return '$site のキャッシュを削除しますか?';
  }

  @override
  String get settingsCacheClearAll => 'すべてクリア';

  @override
  String get settingsCacheClearAllConfirmTitle => 'すべての本文キャッシュを削除しますか?';

  @override
  String get settingsOnlineServicesDisclosure =>
      '本アプリは個人利用目的でなろう / ノクターン系 / カクヨムから 本文を取得します。各サイトの利用規約に同意した範囲でのみ 利用してください。';

  @override
  String get settingsRevokeKeepCache => '残す';

  @override
  String get settingsRevokeDeleteCache => '削除する';

  @override
  String settingsRevokeCachePrompt(String sizeMb) {
    return '本文キャッシュ ($sizeMb MB) も削除しますか?';
  }

  @override
  String get settingsR18Status => '年齢確認の状態';

  @override
  String get settingsR18StatusGranted => '同意済み';

  @override
  String get settingsR18StatusDenied => '未同意';

  @override
  String get settingsR18Reset => '年齢確認をやり直す';

  @override
  String get settingsR18ResetConfirmTitle => '年齢確認をやり直しますか?';

  @override
  String get settingsR18ResetConfirmBody => '次回 R18 サイトを開く際に確認画面が表示されます。';

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionDelete => '削除する';

  @override
  String get actionReset => 'リセットする';

  @override
  String get aboutTitle => 'アプリ情報';

  @override
  String get aboutVersion => 'バージョン';

  @override
  String get aboutBuildNumber => 'ビルド番号';

  @override
  String get aboutCommit => 'コミット';

  @override
  String get aboutApacheLicenseTitle => 'Apache-2.0 ライセンス';

  @override
  String get aboutLinkGithub => 'GitHub リポジトリ';

  @override
  String get aboutLinkRoadmap => 'ロードマップ';

  @override
  String get aboutLinkLicense => 'ライセンス全文';

  @override
  String get aboutOssLicenses => 'OSS ライセンス';

  @override
  String get aboutLinkOpenError => 'リンクを開けませんでした';

  @override
  String get aboutLicenseScreenTitle => 'GeekPlayer — ライセンス全文';

  @override
  String get aboutSettingsLicense => 'ライセンス';

  @override
  String get aboutSettingsOssNotices => 'OSS Notices';

  @override
  String get ossLicensesScreenTitle => 'OSS ライセンス';

  @override
  String get ossLicensesApacheNoticeBody =>
      'GeekPlayer 本体は Apache License 2.0 で配布されています。';

  @override
  String get lgplNoticeTitle => 'LGPL-2.1+ 通知 (libmpv)';

  @override
  String get lgplNoticeBody =>
      'GeekPlayer は動画再生エンジンとして libmpv を採用しており、media_kit を介して 動的リンク で利用しています。libmpv は LGPL-2.1+ で配布されています。';

  @override
  String get lgplNoticeRights =>
      '利用者は LGPL-2.1+ の規定により、libmpv 部分のみを独立に修正・再構築 し、GeekPlayer 本体を再ビルドせずに 差し替える権利 を持ちます。差し替えた libmpv は LGPL の条件下で再配布できます。';

  @override
  String get lgplNoticeReplacementTitle => '差し替え手順 (概要)';

  @override
  String get lgplNoticeReplacementBody =>
      '・macOS: アプリバンドル内 Contents/Frameworks/ 配下の Mpv.framework / libmpv.dylib を差し替え\n・Windows: GeekPlayer.exe と同じディレクトリの mpv-2.dll を差し替え\n・Android: APK 内 lib/<abi>/libmpv.so を差し替えた上で APK を再署名\n・iOS: .app バンドル内 Frameworks/ 配下の libmpv フレームワークを差し替え、再署名 (Ad Hoc / 開発者署名) が必要';

  @override
  String get lgplUpstreamLink => '上流ソース (mpv-player/mpv)';

  @override
  String get lgplThirdPartyLink => '詳細は THIRD_PARTY_NOTICES を参照';

  @override
  String get lgplFullTextLink => 'LGPL-2.1 全文';

  @override
  String get lgplLicenseScreenTitle => 'LGPL-2.1 全文';

  @override
  String get consentDialogTitle => 'オンライン小説サイトへの同意';

  @override
  String get consentDialogBody =>
      '本アプリは以下のサイトと通信して小説を取得します。ADR-0001 / ADR-0003 に従い、能動キャッシュ (利用者が「ライブラリに追加」を選択した作品のみ) を行い、各サイトのレート制限 (カクヨムは 1 req / 2 s) と robots.txt を尊重します。\n\nカクヨム本文は HTML をパースして取得します。サイト構造の変更で取得が失敗することがあります。';

  @override
  String get consentPolicyUpdatedBanner => 'ポリシーが更新されました';

  @override
  String get consentDenyAll => 'すべて拒否';

  @override
  String get consentConfirm => '決定';

  @override
  String get kakuyomuConsentDialogTitle => 'カクヨムへの同意';

  @override
  String get kakuyomuConsentDialogIntro =>
      '本アプリは、利用者の同意のもとでカクヨム公式サイトと通信して小説情報および本文を取得します。下記の運用規範に沿って動作します:';

  @override
  String get kakuyomuConsentBullet1 => '個人利用に限定。大規模クロール / 受動的ミラーリングは行いません。';

  @override
  String get kakuyomuConsentBullet2 =>
      '能動キャッシュのみ。ユーザーが「Library に追加」した作品の本文だけを保存します。';

  @override
  String get kakuyomuConsentBullet3 =>
      'カクヨムへのアクセスは 1 リクエスト / 2 秒、並列度 1 に制限されます。';

  @override
  String get kakuyomuConsentBullet4 =>
      'robots.txt の Disallow を 24 時間キャッシュ付きで尊重します。';

  @override
  String get kakuyomuConsentBullet5 =>
      'User-Agent に GeekPlayer のバージョンと連絡先 URL を明示します。';

  @override
  String get kakuyomuConsentBullet6 =>
      '429 / 503 を受けたら指数バックオフ (最大 5 分) で再試行し、6 回で諦めます。';

  @override
  String get kakuyomuConsentFooter =>
      '詳細は ADR-0001 / README のカクヨム機能の注意事項を参照してください。将来、カクヨム公式 ToS が自動収集を明示禁止した場合は、本機能を即座に停止する方針です。';

  @override
  String get kakuyomuConsentDecline => '同意しない';

  @override
  String get kakuyomuConsentAccept => '同意する';

  @override
  String get kakuyomuConsentRequiredTitle => 'カクヨム';

  @override
  String get kakuyomuConsentRequiredMessage => 'カクヨムへの同意が必要です。';

  @override
  String get kakuyomuConsentRequiredShowDialog => '同意ダイアログを表示';

  @override
  String get kakuyomuConsentRequiredOpenSettings => '設定を開く';

  @override
  String get novelHomeSectionTitle => 'オンライン小説 Library';

  @override
  String get novelHomeSectionSettingsTooltip => 'オンライン小説設定';

  @override
  String get novelLibraryEmpty => 'Library に小説はまだありません。';

  @override
  String get novelConsentDisabledBanner => '同意が無効化されています — 設定で再同意';

  @override
  String get siteFilterAll => 'すべて';

  @override
  String get bookHomeSectionTitle => 'ローカル書籍';

  @override
  String get bookHomeSectionEmpty => '書籍はまだありません。「追加」から PDF または EPUB を開いてください。';

  @override
  String get bookHomeSectionAddTooltip => '書籍を追加';

  @override
  String get bookReaderTitle => '書籍リーダー';

  @override
  String bookReaderPageOf(int current, int total) {
    return '$current / $total ページ';
  }

  @override
  String bookReaderChapterOf(int current, int total) {
    return '$current / $total 章';
  }

  @override
  String get bookBookmarkAdd => 'ブックマーク追加';

  @override
  String get bookBookmarkList => 'ブックマーク一覧';

  @override
  String get bookBookmarkEmpty => 'ブックマークはありません。';

  @override
  String get bookBookmarkDelete => '削除';

  @override
  String get bookBookmarkLabelHint => 'ブックマーク名';

  @override
  String get bookOpenPickerTitle => '書籍を選択';

  @override
  String get bookFileNotFoundMessage => 'ファイルが見つかりません。移動・削除された可能性があります。';

  @override
  String get bookFileNotFoundReimport => '再インポート';

  @override
  String get bookDeleteConfirmTitle => '書籍を削除しますか?';

  @override
  String get bookDeleteConfirmBody => '読書の記録とブックマークがすべて削除されます。ファイル本体は削除されません。';

  @override
  String get mangaHomeSectionTitle => 'ローカルマンガ';

  @override
  String get mangaHomeSectionEmpty =>
      'マンガはまだありません。「追加」から ZIP または CBZ を開いてください。';

  @override
  String get mangaHomeSectionAddTooltip => 'マンガを追加';

  @override
  String get mangaViewerTitle => 'マンガビューア';

  @override
  String mangaViewerPageOf(int current, int total) {
    return '$current / $total ページ';
  }

  @override
  String get mangaBookmarkAdd => 'ブックマーク追加';

  @override
  String get mangaBookmarkList => 'ブックマーク一覧';

  @override
  String get mangaBookmarkEmpty => 'ブックマークはありません。';

  @override
  String get mangaBookmarkDelete => '削除';

  @override
  String get mangaBookmarkLabelHint => 'ブックマーク名';

  @override
  String get mangaOpenPickerTitle => 'マンガを選択';

  @override
  String get mangaFileNotFoundMessage => 'ファイルが見つかりません。移動・削除された可能性があります。';

  @override
  String get mangaDeleteConfirmTitle => 'マンガを削除しますか?';

  @override
  String get mangaDeleteConfirmBody => '読書の記録とブックマークがすべて削除されます。ファイル本体は削除されません。';

  @override
  String get mangaErrorCorruptArchive =>
      'アーカイブを読み込めませんでした。ファイルが破損している可能性があります。';

  @override
  String get mangaErrorNoPages => 'このアーカイブには対応する画像ページがありません。';

  @override
  String get mangaErrorOversized => 'アーカイブのサイズが上限を超えています。';

  @override
  String get settingsSectionManga => 'マンガ';

  @override
  String get settingsMangaReadingDirection => '読み方向';

  @override
  String get settingsMangaReadingDirectionRtl => '右から左 (日本語マンガ)';

  @override
  String get settingsMangaReadingDirectionLtr => '左から右 (洋書コミック)';

  @override
  String get settingsMangaSpreadMode => '見開き表示';

  @override
  String get settingsMangaSpreadModeSingle => '1ページ';

  @override
  String get settingsMangaSpreadModeSpread => '見開き (2ページ)';

  @override
  String get settingsMangaZoomReset => 'ページ移動時にズームをリセット';

  @override
  String get mediaLibrarySectionTitle => 'メディアライブラリ';

  @override
  String get mediaLibrarySectionEmpty =>
      'メディアファイルがまだありません。「フォルダスキャン」からフォルダを追加してください。';

  @override
  String get mediaLibraryScanTooltip => 'フォルダをスキャン';

  @override
  String get mediaLibraryScanDialogTitle => 'フォルダパスを入力';

  @override
  String get mediaLibraryScanDialogHint => '例: /Users/you/Movies';

  @override
  String get mediaLibraryScanDialogConfirm => 'スキャン';

  @override
  String mediaLibraryScanResult(int count) {
    return '$count 件のファイルをインデックスしました';
  }

  @override
  String get mediaLibraryFavoritesLabel => 'お気に入り';

  @override
  String get mediaLibraryPlaylistsLabel => 'プレイリスト';

  @override
  String get mediaLibraryAddFavorite => 'お気に入りに追加';

  @override
  String get mediaLibraryRemoveFavorite => 'お気に入りから削除';

  @override
  String get mediaLibraryCreatePlaylist => 'プレイリストを作成';

  @override
  String get mediaLibraryDeletePlaylistConfirmTitle => 'プレイリストを削除しますか?';

  @override
  String get mediaLibraryDeletePlaylistConfirmBody =>
      'プレイリスト内のすべての項目が削除されます。メディアファイル本体は削除されません。';

  @override
  String get updateAvailableBannerTitle => 'アップデートあり';

  @override
  String updateAvailableBannerBody(String version) {
    return '新しいバージョン $version が利用可能です。';
  }

  @override
  String get updateAvailableDownload => 'ダウンロード';

  @override
  String get updateAvailableDismiss => '後で';

  @override
  String updateDownloading(int percent) {
    return 'ダウンロード中… $percent%';
  }

  @override
  String get updateDownloadFailed => 'ダウンロードに失敗しました';

  @override
  String get updateInstall => 'インストール / 開く';

  @override
  String get updateNoCompatibleAsset => '対応アセットが見つかりません';

  @override
  String get mangaUpscaleAction => '高画質化';

  @override
  String get mangaUpscaleInProgress => '高画質化処理中…';

  @override
  String get mangaUpscaleError => '高画質化に失敗しました';
}

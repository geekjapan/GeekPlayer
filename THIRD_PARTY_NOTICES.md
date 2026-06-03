# Third-Party Notices

GeekPlayer は以下のサードパーティライブラリを利用しています。各ライブラリの完全な
ライセンス条文はリンク先を参照してください。

## ランタイム依存

| ライブラリ | ライセンス | 用途 |
|---|---|---|
| [Flutter SDK](https://github.com/flutter/flutter) | BSD-3-Clause | UI フレームワーク |
| [media_kit](https://github.com/media-kit/media-kit) | MIT | 動画再生のラッパー |
| [libmpv](https://github.com/mpv-player/mpv) (via media_kit) | LGPL-2.1+ | 動画デコード/再生エンジン（**動的リンク**） |
| [just_audio](https://github.com/ryanheise/just_audio) | MIT | 音楽再生 |
| [audio_service](https://github.com/ryanheise/audio_service) | MIT | OS の MediaSession 統合 |
| [drift](https://github.com/simolus3/drift) | MIT | SQLite ORM |
| [dio](https://github.com/cfug/dio) | MIT | HTTP クライアント |
| [riverpod](https://github.com/rrousselGit/riverpod) | MIT | 状態管理 |
| [html](https://github.com/dart-lang/html) | BSD-3-Clause | HTML パース |
| [webfeed_revised](https://pub.dev/packages/webfeed_revised) | MIT | RSS/Atom パース（webfeed のメンテ fork） |
| [url_launcher](https://pub.dev/packages/url_launcher) | BSD-3-Clause | 外部ブラウザ起動（パーサ失敗時の公式ビューアフォールバック） |
| [package_info_plus](https://pub.dev/packages/package_info_plus) | BSD-3-Clause | アプリバージョン取得（User-Agent 構築） |

## libmpv (LGPL) について

libmpv は LGPL-2.1+ で配布されており、本アプリでは media_kit を介して **動的
リンク** で利用しています。LGPL の条件を満たすため:

- GeekPlayer 本体は **Apache-2.0** で配布される
- libmpv のソースコードは [上流リポジトリ](https://github.com/mpv-player/mpv) で
  入手可能
- 本アプリは **App Store / Play Store 等の閉鎖型ストア配布を行わない**（OSS / GitHub
  Releases ベースの直接配布のみ）

iOS / iPadOS 対応（v0.2）では [ADR-0006](docs/adr/0006-ios-media-engine-distribution-policy.md) に従い、
**非 App Store 配布（Ad Hoc / 開発者直配布）** を前提として libmpv を動的リンクで利用します。
App Store 配布は行いません（ADR-0006 参照）。

### プラットフォーム別 libmpv 差し替え手順

LGPL-2.1+ の条件により、ユーザーは本アプリに同梱された libmpv を自身でビルドしたものに差し替える権利を持ちます。

| プラットフォーム | バイナリの場所 | 備考 |
|---|---|---|
| macOS | `GeekPlayer.app/Contents/Frameworks/Mpv.framework/` および `libmpv.dylib` | `.app` バンドル内 |
| Windows | `GeekPlayer.exe` と同じディレクトリの `mpv-2.dll` | インストールディレクトリ直下 |
| Android | APK / App Bundle 内 `lib/<abi>/libmpv.so` | 差し替え後に APK を再署名すること |
| iOS | `.app` バンドル内 `Frameworks/` 配下の libmpv フレームワーク | Ad Hoc / 開発者署名で再署名が必要。App Store 配布は行いません（ADR-0006） |

詳細な差し替え手順はアプリ内「アプリ情報 → OSS ライセンス」の LGPL 通知セクションも参照してください。

## 完全なライセンス情報

依存ライブラリのバージョン別ライセンス情報は、ビルド時に `flutter pub deps
--style=tree` で生成される依存ツリーと、各パッケージの `LICENSE` ファイルを
合わせて参照してください。

エンドユーザー向けには、アプリ内 **「アプリ情報」→「OSS ライセンス」** から
すべての依存ライセンス本文と libmpv の LGPL-2.1+ 通知を確認できます
(`add-about-and-licenses` change)。ライセンスデータは `app/lib/oss_licenses.dart`
にビルド時生成 (`dart run flutter_oss_licenses:generate -o lib/oss_licenses.dart -i flutter`)
され、CI で `pubspec.yaml` との整合性が検証されます。

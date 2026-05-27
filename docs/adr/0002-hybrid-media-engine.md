# 0002 — メディア再生エンジンのハイブリッド構成

**Status**: accepted (2026-05-27)

## Context

動画・音楽を 1 つのプレイヤーアプリで扱う際、メディア再生エンジンの選択肢は主に
以下の 3 つ:

- **media_kit (libmpv ベース)** — 動画/音楽を統合、MKV/HEVC/ASS 字幕/HLS/DASH を網羅
- **video_player + just_audio** — Flutter 公式系、安定だが動画のコーデック/字幕網羅性が弱い
- **ハイブリッド (動画 = media_kit, 音楽 = just_audio + audio_service)**

「動画は網羅性」「音楽は OS 統合」という、異なる優先順位が混在する。media_kit は
動画では圧倒的だが、音楽の OS 統合（ロック画面・ヘッドホンボタン・CarPlay 等）が
手薄。`just_audio + audio_service` はその真逆。

## Decision

**ハイブリッド構成を採用する。**

- 動画再生は `media_kit`（および `media_kit_libs_video` / `media_kit_video`）
- 音楽再生は `just_audio` + `audio_service`
- 共通の domain 抽象として `MediaSession` を `app/lib/core/media/media_session.dart`
  に定義し、`VideoSession`（media_kit 実装）と `AudioSession`（just_audio 実装）の
  2 実装を持たせる
- 漫画/書籍が v0.2 で追加された際は `PageSession` を同じ抽象に乗せる

## Considered Options

- **media_kit 一本**: 一貫性は高いが、音楽の OS 統合機能を自前で MethodChannel 実装する必要があり、UX に妥協が出る。
- **video_player + just_audio**: 動画の MKV/ASS/HLS 網羅性が「あらゆる動画」の謳い文句に届かない。

## Consequences

- 依存ライブラリが 2 系統になりバイナリサイズが増える（libmpv ~10-30MB + just_audio ~数MB）。OSS / 非ストア配布なので許容。
- UI 層では `MediaSession` interface を通じて操作するため、Player と UI の結合は緩い。
- 動画と音楽で内部実装が異なるため、進捗 / 速度変更などのモデルを統一する設計が必要（共通モデル `MediaPosition`, `MediaSpeed`, `MediaPlayState`）。
- libmpv は LGPL。App Store 配布はしないので動的リンク条件は OSS 配布で満たせる。iOS/iPadOS v0.2 対応時にこの方針が変わったら再評価する。

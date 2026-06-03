# 0006 — iOS / iPadOS メディアエンジンと配布方針

**Status**: accepted (2026-06-03)

> **ADR 番号について**: 0005 は過去の監査メモ上に存在する可能性があり、別ブランチから
> 戻ってきた場合の番号衝突を避けるため、本 ADR は 0006 を採番した（既存 ADR の再採番はしない）。
> 関連: [ADR-0002](0002-hybrid-media-engine.md)（ハイブリッドメディアエンジン）。

## Context

GeekPlayer の動画再生は `media_kit`（libmpv ベース）に依存している（[ADR-0002](0002-hybrid-media-engine.md)）。
libmpv は **LGPL** であり、v0.1 では macOS / Windows / Android を **GitHub Releases 直配布（非ストア）**
することで、LGPL の動的リンク条件（ユーザーがライブラリを差し替えられること）を OSS 配布の形で満たしてきた。

v0.2 で iOS / iPadOS 対応を検討するが、ここで方針判断が必要になる:

- **App Store 配布と LGPL の相性が悪い**。App Store の DRM/署名・サンドボックスは、エンドユーザーが
  動的リンクライブラリを差し替える LGPL の権利と整合しにくく、libmpv を含むアプリの App Store 配布は
  実務上リスクが高い（GPL/LGPL アプリが App Store から削除された前例がある）。
- iOS は **公式には非ストア配布の手段が限られる**（Apple Developer Enterprise Program、Ad Hoc/TestFlight の
  人数・期限制約、EU の代替マーケットプレイス/サイドローディング等）。OSS の自由配布という前提と噛み合わない。
- iOS では `media_kit` / libmpv の動作実績・ビルド導線が macOS ほど枯れていない。

`add-platform-ios`（および iPadOS）を実装する前に、メディアエンジンと配布の方針を確定しておかないと、
実装後に配布できない/ライセンス違反になる手戻りが発生する。`lgpl-compliance` capability は本 ADR を
iOS 着手の前提条件として要求する。

## Decision

**iOS / iPadOS では「LGPL を維持したまま、非 App Store 配布を前提とする」方針を第一候補として採択する。**
具体的には:

1. **媒体エンジンはプラットフォームで分岐する**。iOS/iPadOS では動画再生に **libmpv/media_kit を必須としない**
   設計を許容し、必要に応じて iOS では別エンジン（後述「Considered Options」の B）へフォールバックできる
   抽象境界を `MediaSession`（[ADR-0002](0002-hybrid-media-engine.md)）の内側に閉じ込める。
2. **App Store 配布は当面行わない**。iOS でも非ストア配布（Apple Developer Program 署名による Ad Hoc /
   開発者直配布、将来的に EU 代替マーケット等）を前提とし、LGPL 動的リンク条件を OSS 配布で満たす方針を維持する。
3. **iOS で libmpv を載せる場合は動的リンク**とし、再リンク手順を `THIRD_PARTY_NOTICES` / `lgpl-compliance`
   の通知に含める。静的リンクにする場合は LGPL の例外条項（object 提供等）を満たす配布物を別途用意する。
4. `add-platform-ios` の proposal は本 ADR を参照し、(a) どのエンジンを使うか、(b) どの配布チャネルか、
   (c) LGPL 通知をどう満たすか、を design で明記してから実装に入る。

最終的なエンジン選択（libmpv 継続か iOS 専用エンジンか）は `add-platform-ios` の依存スパイク結果で
確定してよいが、**「App Store 配布のために LGPL を捨てる / プロプライエタリ化する」選択は本 ADR では採らない**。

## Considered Options

### A. iOS でも libmpv/media_kit を継続、非ストア配布

- ✅ 全 OS でコードベース・字幕/コーデック網羅性が一貫する。
- ✅ LGPL を動的リンク + OSS 配布で満たせる（v0.1 と同じ枠組み）。
- ⚠️ iOS の非ストア配布は導線が限られる（署名・人数制限・EU 限定の代替マーケット等）。
- ⚠️ iOS での libmpv ビルド/動作実績が macOS より薄く、検証コストが高い。

### B. iOS だけ別の再生エンジンに切替（例: AVPlayer / video_player 系）、App Store 配布も可能に

- ✅ App Store 配布の選択肢が開ける（LGPL 依存を iOS から外せる）。
- ⚠️ iOS だけ動画コーデック/字幕網羅性が落ちる（MKV/ASS/HEVC 等で macOS と非対称な UX）。
- ⚠️ `MediaSession` 抽象の下に iOS 専用実装が増え、テスト面が広がる。
- ⚠️ 「あらゆる動画」という製品方針と iOS だけ機能差が出る。

### C. App Store 配布のために libmpv を静的リンク / プロプライエタリ化

- ❌ LGPL の動的リンク/再リンク権の要件を満たさず、ライセンス違反リスクが高い。**不採択**。

## Decision の位置づけ

- 第一候補は **A（libmpv 継続 + 非ストア配布）**。OSS / 個人利用という製品前提と最も整合する。
- iOS の配布・ビルド検証が現実的でないと判明した場合に限り、**B（iOS のみ別エンジン）** へ
  プラットフォーム分岐でフォールバックする。その判断は `add-platform-ios` のスパイクで行い、
  本 ADR を supersede するのではなく design で選択肢を確定する。
- **C は採らない。**

## Consequences

- `add-platform-ios` / iPadOS の proposal は、本 ADR を Related ADR として参照し、エンジン・配布チャネル・
  LGPL 通知の 3 点を design に明記することが **着手の前提条件**（`lgpl-compliance` capability で要件化）。
- `MediaSession` 抽象は iOS でエンジンを差し替えられるよう、libmpv 固有 API を UI 層に漏らさない設計を維持する。
- iOS で B を選んだ場合、動画機能の OS 間非対称（コーデック/字幕網羅性）を README / ヘルプで明示する。
- App Store 配布を将来どうしても行う場合は、本 ADR を supersede する新 ADR を立て、LGPL 整合性を
  改めて評価する（本 ADR の射程外）。

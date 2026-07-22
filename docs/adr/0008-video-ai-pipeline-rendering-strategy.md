# 0008 — 動画 AI パイプラインのレンダリング／バッチ処理方式

**Status**: proposed (2026-07-07) — Decision は本 ADR では未確定。後続 change の design 段階で確定する
（[ADR-0006](0006-ios-media-engine-distribution-policy.md) と同様に、方針の骨子のみ本 ADR で示す）。

> 関連: [ADR-0002](0002-hybrid-media-engine.md)（hybrid media engine）、
> [ADR-0007](0007-ai-upscaling-runtime-strategy.md)（AI upscaling runtime strategy）。
> 本 ADR は GitHub Issue #48 / OpenSpec change `decompose-v1x-video-ai-pipeline` の成果物として起票する。
> 既存 capability: `media-session`（`MediaSession`/`VideoSession`）、`ml-runtime`（`ImageUpscaler` 抽象）。

## Context

`docs/roadmap.md` の v1.0 セクションは、画像アップスケーリング（ADR-0007 で基盤確定済み）に続く
v1.x の「動画 AI パイプライン」として次の 3 項目を挙げている:

1. **動画リアルタイム**: Anime4K をレンダリングパスに組み込む（GPU シェーダ）
2. **動画オフライン書き出し**: Real-ESRGAN 動画版でファイル変換
3. **フレーム補間**: RIFE による補間（オフライン書き出し）

既存の基盤は画像 1 枚を前提にしている:

- `ml-runtime`（`app/lib/core/ml/`）: `ImageUpscaler` / `MlRuntime` / `MlBackend`。ADR-0007 が
  preferred/effective backend 分離とモデル配布方針を規定。ただし「1 枚の画像を推論する」ことしか
  想定していない。
- `media-session`（`app/lib/core/media/`）: `MediaSession` sealed 型、`VideoSession` は media_kit/libmpv
  ベース（ADR-0002）。**現時点で再生中の描画バッファにフックしてポストプロセス（GPU シェーダ）を
  差し込む拡張点は存在しない。**

動画 AI パイプラインの 3 項目は処理形態が大きく異なる:

| 項目 | 処理形態 | 既存基盤との関係 |
|---|---|---|
| Anime4K | リアルタイム（毎フレーム、GPU シェーダ） | `ml-runtime` の ONNX 推論とは別系統。`VideoSession` の描画経路への新規フックが必要。 |
| Real-ESRGAN 動画 | オフラインバッチ（動画ファイル→動画ファイル） | `ImageUpscaler` をフレーム単位で再利用できる可能性が高い。 |
| RIFE | オフラインバッチ（フレーム補間） | 時間軸方向の新規モデル種別。Real-ESRGAN 動画と実行基盤（進捗 UI・エンコード）を共有できる可能性。 |

`add-anime4k-realtime-shader` 等の後続 change に進む前に、(a) リアルタイムシェーダをどこにどう
差し込むか、(b) オフラインバッチ 2 項目を共通の「変換ジョブ」として扱うか、を先に決めておかないと、
実装後に手戻り（`VideoSession` の再設計、ジョブ基盤の二重実装）が発生するリスクが高い。

## Decision（暫定・確定は後続 change で行う）

現時点で見えている方向性を記録し、確定は各後続 change の design 段階に委ねる:

1. **リアルタイムシェーダ（Anime4K）は `MediaSession`/`VideoSession` の内側（libmpv 側）の
   フックとして追加する候補を第一候補とする。** libmpv 自体のシェーダフック（`vf`/GLSL shader オプション等）が
   使えるかを `add-anime4k-realtime-shader` の設計スパイクで先に検証し、使えない場合は
   Flutter 側のテクスチャポストプロセスにフォールバックする。
2. **オフラインバッチ 2 項目（Real-ESRGAN 動画・RIFE）は共通の「オフライン変換ジョブ」概念
   （入力ファイル・進捗・キャンセル・出力先・エンコード設定）を共有できるかを検討する。**
   ただし共通抽象を独立 change として先出しするか、`add-realesrgan-video-export` の実装の中で
   作り RIFE 側が再利用するかは未確定（過剰設計を避けるため、後者を暫定の既定路線とする）。
3. **リアルタイム経路とオフライン経路は異なる ADR 前提を持つため、無理に単一の抽象に統合しない。**
   Anime4K はシェーダ、Real-ESRGAN 動画/RIFE はモデル推論であり、`ml-runtime` の `MlBackend` 抽象を
   共有できるのはオフライン 2 項目のみと見込む。

## Considered Options

### A. リアルタイムシェーダを `VideoSession` 内部（libmpv 側）のフックで実現

- ✅ プレイヤー本体の GPU パイプラインを直接使えるため性能面で有利な可能性。
- ⚠️ media_kit/libmpv がシェーダ差し込み API をどこまで公開しているか未検証（スパイクが必要）。
- ⚠️ プラットフォームごとにフックの実現可否が異なる可能性（macOS/Windows/Linux/Android/iOS）。

### B. リアルタイムシェーダを Flutter 側のテクスチャポストプロセスとして実現

- ✅ `MediaSession` 抽象の外側で完結し、libmpv 側の制約に左右されない。
- ⚠️ フレームごとにテクスチャを Flutter 側へコピーするオーバーヘッドが性能要件を満たせない懸念。
- ⚠️ 実装が複雑になりやすい（プラットフォームごとのテクスチャ共有機構に依存）。

### C. オフライン 2 項目を最初から共通ジョブ抽象として独立 change で切り出す

- ✅ 設計の一貫性が最初から担保される。
- ⚠️ Real-ESRGAN 動画の実装より先に抽象を確定させるため、過剰設計になるリスクがある
  （RIFE 特有の要件が読めない段階での抽象化）。

### D. 共通ジョブ基盤を Real-ESRGAN 動画 change 内で実装し、RIFE で再利用する

- ✅ 実要件を確認してから最小限の共通基盤を抽出できる。
- ⚠️ RIFE change が Real-ESRGAN 動画 change の実装順序に依存する可能性。

## Decision の位置づけ

- A/B の選択は `add-anime4k-realtime-shader` の設計スパイク結果に委ねる。本 ADR ではどちらか
  一方を確定しない。
- C/D の選択は `add-realesrgan-video-export` の design 段階で判断する。暫定の既定路線は D
  （Real-ESRGAN 動画 change 内で実装して再利用）とする。
- 本 ADR は「動画 AI パイプラインは画像アップスケーリング（ADR-0007）とは別の設計軸を持つ」
  ことの確認と、各後続 change が着手前に解くべき問いを明文化することが目的であり、
  Decision の最終確定は後続 change の design.md で行う。

## Consequences

- `add-anime4k-realtime-shader` / `add-realesrgan-video-export` / `add-rife-frame-interpolation` の
  proposal は本 ADR を Related ADR として参照し、それぞれの design.md で上記の未確定事項
  （シェーダフック方式、共通ジョブ抽象の要否）を確定させることが着手の前提条件となる。
- 後続 change で方針を確定した時点で、本 ADR の Decision を確定内容に更新し、Status を accepted にする。
  新しい ADR で方針を確定した場合は、本 ADR を superseded にして新しい ADR へリンクする。
- モデルライセンス（RIFE の実装によっては非商用/研究ライセンス由来のものがある）は
  本 ADR の射程外とし、`add-rife-frame-interpolation` の proposal 段階で確認する。

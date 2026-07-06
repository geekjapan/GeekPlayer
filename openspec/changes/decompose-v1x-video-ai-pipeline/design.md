## Context

`docs/roadmap.md:113-118` は v1.0 の「動画リアルタイム / 動画オフライン書き出し / フレーム補間」を
以下のように列挙している（未着手）:

1. **動画リアルタイム**: Anime4K をレンダリングパスに組み込む（GPU シェーダ）
2. **動画オフライン書き出し**: Real-ESRGAN 動画版でファイル変換
3. **フレーム補間**: RIFE による補間（オフライン書き出し）

既存の基盤は画像アップスケーリングに閉じている:

- `ml-runtime` capability（`app/lib/core/ml/`）: `ImageUpscaler` / `MlRuntime` / `MlBackend` の抽象。
  ADR-0007（`docs/adr/0007-ai-upscaling-runtime-strategy.md`）が preferred/effective backend 分離、
  Experimental 既定 OFF、モデル配布方針を規定。
- `onnx-upscaler-runtime` / `gpu-execution-providers` / `upscale-model-distribution` /
  `upscale-image-tiling`: ORT CPU/CoreML/NNAPI EP、初回モデル DL・検証・キャッシュ、固定形状タイリング。
- `media-session` capability（`app/lib/core/media/`）: `MediaSession` sealed 抽象、`VideoSession` は
  media_kit/libmpv ベース（ADR-0002）。**現時点でレンダリングパスへのフック（シェーダ差し込み点）は
  存在しない** — Anime4K 統合にはここに新しい拡張点が必要になる。

3 項目は次の軸で性質が大きく異なる:

| 項目 | 処理形態 | 入出力 | 既存基盤との関係 |
|---|---|---|---|
| Anime4K | リアルタイム（毎フレーム、GPU シェーダ） | `VideoSession` 再生中の描画バッファ | `ml-runtime` の ONNX 推論とは別系統（シェーダ、モデル推論ではない） |
| Real-ESRGAN 動画 | オフラインバッチ（1 回変換） | 動画ファイル → 動画ファイル | `ml-runtime` の `ImageUpscaler` をフレーム単位で再利用できる可能性が高い |
| RIFE | オフラインバッチ（1 回変換） | 動画ファイル → 動画ファイル（フレーム補間） | 時間軸方向の新規モデル種別。Real-ESRGAN 動画と実行基盤（進捗 UI・エンコード）を共有できる可能性 |

## Goals / Non-Goals

**Goals:**
- 3 項目それぞれについて、実装着手前に必要な設計判断（ADR 要否）を明確にする。
- 後続 OpenSpec change への分割単位・順序・依存関係を確定する。
- 各後続 change が着手前に埋めるべき調査項目（プラットフォーム、GPU/ランタイム依存、ライセンス、
  バイナリサイズ、検証ハードウェア）を洗い出す。

**Non-Goals:**
- Anime4K / Real-ESRGAN 動画 / RIFE の実装、モデル選定、性能検証。
- ADR-0008 の Decision 内容を本 change 内で最終確定すること（ドラフトの起票まで）。
- 既存の画像アップスケーリング capability（`ai-image-upscaler` 系）の変更。

## Decisions

### D1. ADR-0008 を新規起票する（Decision 確定は後続作業）

**選択**: 動画リアルタイム（シェーダ）とオフラインバッチ（Real-ESRGAN 動画・RIFE）の
アーキテクチャ方針は、既存 ADR-0002 / ADR-0007 の射程外（前者はシェーダパイプライン、
後者は画像 1 枚の推論を前提にしている）であるため、新しい ADR-0008 を起票する。

**検討した代替案**:
- (a) ADR-0007 を amendment で拡張する: 却下。ADR-0007 は「on-device 画像推論のランタイム戦略
  （backend 選択・モデル配布）」に主題が閉じており、GPU シェーダパイプラインへの統合や
  動画ファイルバッチ処理のジョブモデルは別の関心事。amendment で無理に詰め込むと ADR が肥大化する。
- (b) ADR を起票せず、各後続 change の design.md で個別に判断する: 却下。3 change が独立に
  レンダリングフック／ジョブ抽象を設計すると、後から統合できない実装が並立するリスクが高い
  （特に Anime4K の `VideoSession` 拡張点は 1 箇所に決め打ちすべき）。
- (c) 本 change 内で ADR-0008 の Decision まで確定する: 却下（Non-goals 参照）。
  Issue #48 は「分解」を依頼しており、シェーダ統合方式の技術検証（GPU シェーダ言語の選定、
  media_kit/libmpv 側のフック有無の調査）は本 change の調査範囲を超える。ADR はドラフトとして
  起票し、Decision の確定は ADR レビュー、または最初の後続 change（Anime4K）の design 段階で行う。

ADR-0008 は `docs/adr/0006-ios-media-engine-distribution-policy.md` に倣い、Context に
「0005 は欠番（過去の監査メモ由来、既存 ADR は再採番しない）」のような番号注記は不要（0008 は
単純に次の連番）。

### D2. 後続 change を 3 本 + 共通基盤 1 本（暫定）に分割する

**選択**: 以下の順序・依存関係で後続 change を計画する。

1. `add-anime4k-realtime-shader`（仮称）
   - 依存: ADR-0008 の Decision（`VideoSession` へのシェーダフック方式）
   - スコープ: GPU シェーダによるリアルタイムアップスケーリングを再生パイプラインに統合
2. `add-realesrgan-video-export`（仮称）
   - 依存: ADR-0008（オフラインジョブ方式の合意）、既存 `ml-runtime`/`ai-image-upscaler` の再利用可否調査
   - スコープ: 動画ファイルをフレーム単位で Real-ESRGAN 推論し、再エンコードして書き出す
3. `add-rife-frame-interpolation`（仮称）
   - 依存: `add-realesrgan-video-export` のオフラインジョブ基盤（進捗 UI・エンコードパイプライン）を
     再利用できるなら後続、独立モデルとして先行させても良い（強い依存はない）
   - スコープ: フレーム補間モデルによる動画書き出し
4. 共通基盤 change（例: `add-offline-media-conversion-job`）の要否
   - Real-ESRGAN 動画と RIFE がどちらも「動画ファイル → 変換 → 動画ファイル」という
     オフラインジョブ（進捗表示・キャンセル・出力先選択・エンコード設定）を必要とするため、
     共通の「オフライン変換ジョブ」抽象を先に切り出すか、2 番目の change (`add-realesrgan-video-export`)
     の中で実装し RIFE change がそれを再利用するかは、**2 番目の change の design 段階で判断する**
     （現時点では過剰設計を避けるため、独立 change として切り出さない）。

**検討した代替案**:
- 3 項目を 1 本の巨大 change にまとめる: 却下（Issue #48 の意図・レビュー可能性に反する）。
- 4 change すべてを同時に起票する: 却下。共通基盤の要否は Real-ESRGAN 動画 change の実装過程でしか
  判断できないため、先取りして change を切ると仕様先行になりやすい。

### D3. 動画 AI パイプライン自体の capability spec delta は作成せず、計画専用の delta のみ追加する

`openspec/specs/` を確認したところ、既存の画像系 capability（`ml-runtime`, `ai-image-upscaler`,
`onnx-upscaler-runtime`, `gpu-execution-providers`, `upscale-model-distribution`,
`upscale-image-tiling`）はいずれも「画像 1 枚」を前提にしており、本 change はそれらの要件を
変更しない。動画 AI パイプラインの実行時 capability（Anime4K シェーダ／Real-ESRGAN 動画／RIFE）は
後続の各 change が実装時に提案するべきもので、本 change（計画のみ）で先取りして spec を書くと、
後続 change 着手時点の技術検証結果と齟齬が生じるリスクがある。

一方で、OpenSpec ツール（`@fission-ai/openspec` 1.5.0）の `spec-driven` schema は
「change には少なくとも 1 つの delta（requirement + scenario を含む spec ファイル）が必要」という
検証ルールをハード制約として持つ（`openspec validate --strict` は delta 0 件を ERROR にする）。
計画のみで実行時挙動を持たない change であっても、この制約を回避する schema オプションは存在しない。

そのため、動画 AI パイプラインそのものではなく、**本 change の成果物（ADR の起票内容・後続分割計画・
roadmap への反映）を検証可能な要件として記述する計画専用 capability
`video-ai-pipeline-decomposition`** を新規追加した（`specs/video-ai-pipeline-decomposition/spec.md`）。
これは実行時のアプリ挙動を持たないドキュメント成果物の検証用 delta であり、`lgpl-compliance` 等の
既存 capability が「アプリが特定の通知文言・リンクをレンダリングすること」を要件化しているのと
同じ発想を、「リポジトリが特定の ADR・roadmap 記述を含むこと」に適用したものである。将来この
capability が実装フェーズを持つことはなく、archive 後も `openspec/specs/video-ai-pipeline-decomposition/`
としてドキュメント整合性チェックの記録用に残る想定。

## Risks / Trade-offs

- [Risk] ADR-0008 をドラフトのまま起票すると、後続 change 側で Decision が固まらず手戻りが起きる
  → Mitigation: ADR-0008 の Context/Considered Options までは本 change で十分に書き、
  Decision 確定を明示的に「`add-anime4k-realtime-shader` の design 段階で行う」条件と明記する
  （ADR-0006 が `add-platform-ios` に対して行ったのと同じパターン）。
- [Risk] 共通基盤（オフライン変換ジョブ）の切り出し判断を先送りすると、RIFE change が
  Real-ESRGAN 動画 change の実装詳細に強く依存してしまう → Mitigation: D2 で依存関係を明示し、
  2 番目の change の design.md で共通化の可否を判断する義務を明記する。
- [Risk] Anime4K のシェーダ統合方式が media_kit/libmpv 側の制約で実現できない可能性がある
  （GPU シェーダフックの有無は未調査）→ Mitigation: ADR-0008 の Considered Options に
  「media_kit のシェーダフック調査」をスパイクタスクとして含め、実現困難な場合の代替
  （例: 出力フレームへのポストプロセスオーバーレイ）を選択肢として残す。

## Validation

- `openspec validate --all --strict` で本 change の proposal/design/tasks を検証する。
- Flutter/Dart のコード変更を伴わないため `flutter analyze` / `flutter test` は対象外
  （tasks.md に明記）。
- レビュー観点: (1) ADR-0008 ドラフトが ADR-0002/0007 と矛盾しないか、(2) 3〜4 本の後続 change
  分割が Issue #48 の Scope チェックリスト（プラットフォーム対応・GPU/ランタイム依存・ライセンス・
  バイナリサイズ・検証ハードウェアの識別）を満たしているか。

## Open Questions

- ADR-0008 の Decision（Anime4K のシェーダフック方式）を確定するまで `add-anime4k-realtime-shader`
  は着手できない。ADR レビューの担当・タイミングは GitHub management chat 側で Issue を切って調整する。
- 共通基盤 change（`add-offline-media-conversion-job` 仮称）を独立させるかどうかは、
  `add-realesrgan-video-export` の design 段階まで未確定。
- RIFE のモデルライセンス（原論文実装は主に非商用/研究ライセンスの派生が多い）は本 change では
  未調査。`add-rife-frame-interpolation` の proposal 段階で必ず確認する前提条件として残す。

# GeekPlayer Roadmap

GeekPlayer は段階的に対象プラットフォームとメディアの幅を広げ、最終的に AI による
高画質化を載せる。

## v0.1 (MVP)

**対象 OS**: macOS / Windows / Android

**機能スコープ** (thin + 小説のみリッチ寄り最小):

- **動画再生** (`media_kit` / libmpv): ファイルを開く → 再生、`ResumePoint` 保存、字幕、再生速度変更
- **音楽再生** (`just_audio` + `audio_service`): ファイル/フォルダを開く → 再生、`ResumePoint` 保存、OS 統合 (背景再生・ロック画面・ヘッドホン)
- **オンライン小説**:
  - 小説家になろう / ノクターン系: 公式 API で検索 / 一覧 / 本文取得
  - カクヨム: 公式 RSS + 本文 HTML パース（ADR-0001 参照）
  - `Library` 追加で本文ローカル保存（能動キャッシュ）
- **"最近開いた" リスト**
- **OS 通知 / Bluetooth リモコン**（音楽のみ）
- **同意ダイアログ**（サイト別）

**意図的に外す**:

- 動画/音楽のライブラリ管理（フォルダスキャン、視聴履歴、しおり、プレイリスト）
- 書籍 / 漫画 ZIP
- Linux / iOS / iPadOS
- 自動アップデート機構
- 英語 UI

## v0.2

**対象 OS 拡張**: Linux / iOS / iPadOS

**機能拡張**:

- **書籍リーダー**: PDF / EPUB
- **漫画 ZIP / CBZ ビューア**: 右綴じ・左綴じ、見開き、ピンチズーム
- **ライブラリ機能**:
  - フォルダスキャン → 動画/音楽のメタデータインデックス化
  - 視聴履歴
  - しおり / お気に入り
  - プレイリスト / 再生キュー
- **自動アップデート**: GitHub Releases ベースの in-app update（OS 別実装）
- **英語 UI**
- **CI 拡張**: macOS / Windows runner 追加、各 OS の build smoke test

> **状態 (2026-06-03)**: v0.2 の主要スコープは実装完了。下記 4 件の sequencing に加え、
> `add-media-library`（ライブラリ機能）/ `expand-ci-and-platforms`（CI macOS/Linux + Linux scaffolding）/
> `add-auto-update`（バナー版）を archive 済み。**残る v0.2 候補は `add-platform-ios`**（ADR-0006 accepted）
> と `expand-auto-update-delivery`（OS 別 in-app install）。詳細は `docs/HANDOFF.md` §6・§9。

### v0.2 sequencing（apply 推奨順 — すべて完了済み・履歴）

v0.2 の change は次の順に apply した。順序には実装上の依存があり、入れ替えると手戻りが出る。

1. **`prepare-v0-2-foundation`**（本整備）— ドキュメント整合性回復、ADR-0006、sequencing 確定。コード変更なし。
2. **`add-english-localization`** — `en` ロケールと ARB key parity test を先に入れる。これより後の
   book/manga UI はすべて `AppLocalizations` 経由で文字列を足す前提になるため、**大きな新規 UI surface の前に**置く。
3. **`add-pdf-epub-reader`** — 書籍リーダー。drift schema **v4** を所有し、`BookDocument` /
   `PageSession` のリーダー抽象を確立する。manga はこの抽象と schema 順序に乗る。
4. **`add-manga-zip-viewer`** — 漫画 ZIP/CBZ。drift schema **v5**（pdf-epub の v4 が入った後）。
   apply 順を入れ替える場合は schema 番号を latest+1 に rebase し `docs/CONVENTIONS.md` を更新すること。

その先の候補の placement（✅ = 完了済み）:

- ✅ **ライブラリ機能**（video/audio library, 視聴履歴, お気に入り, プレイリスト）— `add-media-library`（drift v6）として実装済み。
- ✅ **Linux 対応** — `expand-ci-and-platforms` で `app/linux/` CMake scaffolding + CI build-linux smoke を実装済み（`add-platform-linux` 相当）。
- ✅ **CI 拡張**（macOS/Windows/Linux runner, build smoke test）— `expand-ci-and-platforms` で実装済み（`setup-ci-macos-windows` 相当）。
- ✅ **`add-auto-update`**（バナー版）— GitHub Releases チェック + Settings About の更新バナーを実装済み。
- ✅ **`expand-auto-update-delivery`** — バナー版から OS 別の実ダウンロード（dio）+ `file://` での in-app install/handoff を実装済み（Android は file-provider 宣言が残課題、HANDOFF §7 参照）。
- ✅ **`add-ml-runtime-abstraction`** — v1.0 AI 高画質化の seam（`core/ml/`：MlBackend / ImageUpscaler / MlRuntime / PassthroughUpscaler + Riverpod）を実装済み。
- ✅ **`add-platform-ios` / iPadOS** — ADR-0006 Option A（libmpv/media_kit 継続 + 非ストア配布）で実装済み。iOS は SPM を無効化して CocoaPods で libmpv をビルド、deployment target 14.0、`build-ios` CI smoke ジョブ追加。配布の本番化（署名/プロビジョニング）は follow-up。

### v0.2 proposal readiness checklist

新しい v0.2 proposal を起こす前に、以下を proposal/design で満たすこと。満たせない項目は
「未決」「将来 change にルーティング」「ADR で決定」のいずれかを明記する。

- [ ] **影響 capability** を列挙し、新規 / 変更 / 非該当を区別している
- [ ] **ADR 前提** を確認している（特に iOS/iPadOS は ADR-0006 を参照しているか）
- [ ] **対象プラットフォーム** を明示し、未対応 OS の follow-up 制約を書いている
- [ ] **依存パッケージ / ライセンス影響** を評価している（新規依存は LGPL/GPL でないか、全対象 OS をサポートするか）
- [ ] **drift schema versioning** を確認している（schema を触る場合 latest+1 を取り、migration テストと前段 change との順序を明記）
- [ ] **localization**：新規ユーザー可視文字列はすべて `AppLocalizations` 経由（日英）で、生リテラルを置かない
- [ ] **settings 伝播モデル**：`AppSettings` 値を追加/参照する場合、新規セッションのみ反映か、アクティブセッションへ即時反映かを明記
- [ ] **R18 / consent**：R18 やサイト同意の挙動を変える場合、consent の所有先（`site_consents` か別永続化か）・policyVersion・取消時のキャッシュ方針を参照
- [ ] **検証コマンド**：`dart format` / `flutter analyze --fatal-infos` / `flutter test` / `openspec validate --all --strict` / `git diff --check` を tasks に含めている

## v1.0

**AI 高画質化** 機能を段階導入する。

> **状態 (2026-06-06)**: ランタイム戦略 **[ADR-0007](adr/0007-ai-upscaling-runtime-strategy.md)**
> （accepted: ONNX Runtime + Execution Provider 一本化、preferred/effective backend 分離、bicubic CPU を floor、
> **画像のみ・当面 Experimental 既定 OFF**、モデルは opt-in 初回 DL）のシーケンスを step3 まで実装:
> step1 ✅ `refactor-ml-runtime-effective-backend`（preferred/effective + 非同期 probe + フォールバック）/
> step2 ✅ `add-onnx-upscaler-runtime`（ORT CPU EP の `OnnxImageUpscaler`）/
> step3 ✅ `add-upscale-model-distribution`（`ModelRepository` で初回 DL/SHA-256 検証/キャッシュ、Experimental 設定 UI で
> 有効化トグル既定 OFF・2x/4x・モデル管理、async `imageUpscalerProvider` 配線、manga viewer 移行。フィクスチャモデルで
> 配線完成・実モデル選定は follow-up）。残りは step4（GPU EP 有効化）。

1. **画像系**（漫画 / 書籍）:
   - ✅ 抽象化レイヤを `core/ml/` に配置（`ImageUpscaler` / `MlRuntime` / `MlBackend`、CoreML/NNAPI/ONNX/TensorRT を OS で切替）
   - ✅ CPU bicubic アップスケーラ（`CpuImageUpscaler`、`image` パッケージ）を既定実装として提供
   - ✅ ORT CPU EP の `OnnxImageUpscaler` + `ModelRepository`（初回 DL/検証/キャッシュ）+ Experimental 設定 UI（既定 OFF・2x/4x）
   - ⏳ Real-ESRGAN / waifu2x の実モデル選定・配置（follow-up）と、GPU EP（CoreML/NNAPI/DirectML）での推論（step4 `enable-gpu-execution-providers`）
2. **動画リアルタイム**:
   - Anime4K をレンダリングパスに組み込む（GPU シェーダ）
3. **動画オフライン書き出し**:
   - Real-ESRGAN 動画版でファイル変換
4. **フレーム補間**:
   - RIFE による補間（オフライン書き出し）

**運用方針**:

- AI 機能は **opt-in モジュール**として配布（バイナリサイズが膨らむため）
- モデルは初回利用時にダウンロード（GitHub Releases 添付）
- on-device 推論優先。クラウド推論は v1.x 以降の検討事項

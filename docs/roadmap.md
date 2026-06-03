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

### v0.2 sequencing（apply 推奨順）

v0.2 の change は次の順に apply する。順序には実装上の依存があり、入れ替えると手戻りが出る。

1. **`prepare-v0-2-foundation`**（本整備）— ドキュメント整合性回復、ADR-0006、sequencing 確定。コード変更なし。
2. **`add-english-localization`** — `en` ロケールと ARB key parity test を先に入れる。これより後の
   book/manga UI はすべて `AppLocalizations` 経由で文字列を足す前提になるため、**大きな新規 UI surface の前に**置く。
3. **`add-pdf-epub-reader`** — 書籍リーダー。drift schema **v4** を所有し、`BookDocument` /
   `PageSession` のリーダー抽象を確立する。manga はこの抽象と schema 順序に乗る。
4. **`add-manga-zip-viewer`** — 漫画 ZIP/CBZ。drift schema **v5**（pdf-epub の v4 が入った後）。
   apply 順を入れ替える場合は schema 番号を latest+1 に rebase し `docs/CONVENTIONS.md` を更新すること。

その先の候補の placement:

- **ライブラリ機能**（video/audio library, 視聴履歴, プレイリスト）— 上記リーダーの後。フォルダスキャンは
  reader のメタデータ/recent モデルが固まってから着手する。
- **`add-platform-linux`** — リーダー実装が依存パッケージの Linux 対応を確認した後に着手すると手戻りが少ない。
- **`add-platform-ios` / iPadOS** — **[ADR-0006](adr/0006-ios-media-engine-distribution-policy.md) の決定が前提条件**。
  libmpv/media_kit の LGPL 動的リンクと非ストア配布の整合がとれてから。
- **`add-auto-update`** — 配布物が安定し、対象 OS が出揃ってから（GitHub Releases ベース、OS 別実装）。
- **CI 拡張**（macOS runner 追加, build smoke test）— 新しい OS ターゲット（Linux/iOS）を追加する change と並走させる。
- **`setup-ci-macos-windows`** 相当の追加は、各 reader/platform change が必要とするビルド検証に合わせて随時。

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

1. **画像系**（漫画 / 書籍）:
   - Real-ESRGAN / waifu2x モデルを on-device GPU で推論
   - 抽象化レイヤを `core/ml/` に置く（CoreML / NNAPI / ONNX Runtime / TensorRT を OS で切り替え）
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

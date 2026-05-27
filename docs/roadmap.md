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

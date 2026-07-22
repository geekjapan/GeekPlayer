## 1. 現状調査

- [ ] 1.1 `docs/roadmap.md:113-118` の動画 AI パイプライン記述と、milestone #4 / Issue #48 の Scope
      チェックリストを突き合わせ、齟齬がないか確認する。
- [ ] 1.2 既存 ADR（`docs/adr/0002-hybrid-media-engine.md`, `docs/adr/0007-ai-upscaling-runtime-strategy.md`）
      および既存 capability（`ml-runtime`, `ai-image-upscaler`, `onnx-upscaler-runtime`,
      `gpu-execution-providers`, `upscale-model-distribution`, `upscale-image-tiling`,
      `media-session`）を読み、動画 AI パイプラインとの関係・再利用可否を整理する。

## 2. ADR-0008 ドラフト

- [ ] 2.1 `docs/adr/0008-video-ai-pipeline-rendering-strategy.md` を起票する（Context / Considered
      Options まで記述、Decision は「後続 change の design 段階で確定」と明記）。
- [ ] 2.2 ADR-0008 が ADR-0002 / ADR-0007 と矛盾しないかレビューする。

## 3. 後続 change 分割案の確定

- [ ] 3.1 `add-anime4k-realtime-shader`（仮称）の依存関係・調査項目（GPU シェーダフックの有無、
      対応プラットフォーム）を design.md に記載済みであることを確認する。
- [ ] 3.2 `add-realesrgan-video-export`（仮称）の依存関係・調査項目（`ImageUpscaler` 再利用可否、
      エンコード方式、バイナリサイズ影響）を design.md に記載済みであることを確認する。
- [ ] 3.3 `add-rife-frame-interpolation`（仮称）の依存関係・調査項目（モデルライセンス、
      Real-ESRGAN 動画 change との共通基盤再利用可否）を design.md に記載済みであることを確認する。
- [ ] 3.4 共通基盤 change（`add-offline-media-conversion-job` 仮称）を独立させるかどうかの判断基準を
      design.md に明記済みであることを確認する。

## 4. 検証

- [ ] 4.1 `openspec validate --all --strict` を実行し、エラーがないことを確認する。
- [ ] 4.2 `git diff --check` を実行し、空白エラーがないことを確認する。
- [ ] 4.3 Flutter/Dart コード変更を伴わないため `flutter analyze` / `flutter test` は対象外（本 change は
      ドキュメント/計画のみ）。ローカル実行は不要とし、GitHub Actions の結果を正として PR 説明に記載する。

## 5. GitHub 連携

- [ ] 5.1 PR に Issue #48 へのリンクを記載する。
- [ ] 5.2 分解案（後続 3〜4 change）に対応する GitHub Issue 起票を GitHub management chat 側に依頼する
      旨を PR 説明に記す（本 change 自体は Issue を新規作成しない）。

## 1. プラットフォーム別方針決定

- [ ] 1.1 iOS/iPadOS の署名・プロビジョニング戦略（design.md D1）を確定する。特に Apple Developer Program 年会費の負担主体と Ad Hoc 端末登録上限への対応方針を人間/プロダクトオーナーに確認し、design.md の Open Questions を解消する。
- [ ] 1.2 macOS notarization 導入（design.md D2）の要否と導入タイミングを確定し、結果を design.md の Decisions / Open Questions に記録する。
- [ ] 1.3 Android 本番 keystore 移行方針（design.md D3）と keystore バックアップ保管者・保管場所を確定し、結果を design.md の Decisions / Open Questions に記録する。
- [ ] 1.4 横断的な secrets 一覧・CI 権限・ローテーション責任（design.md D4）を確定して design.md に記録し、`docs/release.md` に追記する下書きを用意する。

## 2. 後続 OpenSpec change への分割

- [ ] 2.1 `harden-ios-distribution-signing`: D1/1.1 の go 判断後、登録端末向け `.ipa` の署名・プロビジョニングと CI 配布を実装する change のスコープを確定する。
- [ ] 2.2 `harden-macos-signing-notarization`: D2/1.2 で導入決定後、Developer ID 署名・`notarytool` 公証と CI secrets を実装する change のスコープを確定する。
- [ ] 2.3 `harden-android-production-signing`: D3/1.3 の決定後、本番 keystore 署名・CI secrets・バックアップ運用を実装する change のスコープを確定する。
- [ ] 2.4 上記の分割案を GitHub Issue #49 の子 Issue またはコメントとして記録し、各 task 2.1〜2.3 にリンクを追記する（GitHub 管理チャットに引き継ぎ）。

## 3. ドキュメント整合性

- [ ] 3.1 `docs/roadmap.md` に配布 hardening の方針決定と後続 change 一覧を反映する。
- [ ] 3.2 `docs/HANDOFF.md` に本 change の決定サマリと未決事項を追記する。
- [ ] 3.3 D1/D2 の決定内容に応じて、新規 ADR（例: iOS 証明書運用ポリシー、または既存 ADR-0006 への追記で足りるか）の要否を判断する。

## 4. 検証

- [ ] 4.1 `openspec validate --all --strict` を実行しパスすることを確認する。
- [ ] 4.2 `git diff --check` を実行する。
- [ ] 4.3 本 change はコード変更を伴わないため、`dart format` / `flutter analyze` / `flutter test` は対象外であることを PR 説明に明記する（Flutter/Dart 環境が無い場合も同様）。

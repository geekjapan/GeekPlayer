## ADDED Requirements

### Requirement: プレゼンテーション層はユーザー向けエラー文字列を必ず ErrorMessages.localize 経由で表示する

The system SHALL ensure that no widget in `app/lib/features/*/presentation/` displays an error to the user by directly interpolating a caught exception into a string literal (e.g., `'エラー: $e'`, `'失敗しました: $err'`). Every user-facing error string MUST be produced via `ErrorMessages.localize(AppError, BuildContext)`. When the caught value is not already an `AppError`, it MUST be wrapped in `UnknownError(e)` before passing to `ErrorMessages.localize`.

#### Scenario: video home_section がエラーを ErrorMessages.localize 経由で表示する

- **GIVEN** `localVideoProvider` がエラーを投げた場合
- **WHEN** `app/lib/features/video/presentation/home_section.dart` がエラー状態をレンダリングする
- **THEN** 表示文字列は `ErrorMessages.localize(UnknownError(e), context)` の戻り値であり、`'読み込みに失敗しました: $e'` のような生文字列展開は含まれない

#### Scenario: audio home_section がエラーを ErrorMessages.localize 経由で表示する

- **GIVEN** `localAudioProvider` がエラーを投げた場合
- **WHEN** `app/lib/features/audio/presentation/home_section.dart` がエラー状態をレンダリングする
- **THEN** 表示文字列は `ErrorMessages.localize(UnknownError(e), context)` の戻り値であり、`'読み込みに失敗しました: $e'` のような生文字列展開は含まれない

#### Scenario: narou work_detail_screen がエラーを SnackBar で正しく表示する

- **GIVEN** なろうライブラリへの追加操作が例外を投げた場合
- **WHEN** `app/lib/features/novel_narou/presentation/work_detail_screen.dart` のエラーハンドラが実行される
- **THEN** SnackBar のテキストは `ErrorMessages.localize(UnknownError(e), context)` の戻り値であり、`'追加に失敗しました: $e'` のような生文字列展開は含まれない

#### Scenario: kakuyomu work_detail_screen がエラーを ErrorMessages.localize 経由で表示する

- **GIVEN** カクヨムライブラリへの追加またはエピソード取得が例外を投げた場合
- **WHEN** `app/lib/features/novel_kakuyomu/presentation/work_detail_screen.dart` がエラー状態を表示する
- **THEN** 表示文字列は `ErrorMessages.localize` を経由しており、`'追加に失敗: $e'` や `'エラー: $err'` のような生文字列展開は含まれない

#### Scenario: kakuyomu reader_screen がエラーを ErrorMessages.localize 経由で表示する

- **GIVEN** カクヨムエピソード取得が例外を投げた場合
- **WHEN** `app/lib/features/novel_kakuyomu/presentation/reader_screen.dart` がエラー状態をレンダリングする
- **THEN** 表示文字列は `ErrorMessages.localize` を経由しており、`'エラー: $err'` のような生文字列展開は含まれない

#### Scenario: kakuyomu search_screen がエラーを ErrorMessages.localize 経由で表示する

- **GIVEN** カクヨム検索が例外を投げた場合
- **WHEN** `app/lib/features/novel_kakuyomu/presentation/search_screen.dart` がエラー状態をレンダリングする
- **THEN** 表示文字列は `ErrorMessages.localize` を経由しており、`'エラーが発生しました: $err'` のような生文字列展開は含まれない

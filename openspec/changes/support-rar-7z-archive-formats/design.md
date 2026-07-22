## Context

現在の実装は `pubspec.yaml:65` の `archive: ^4.0.9`（純 Dart 実装）に依存し、`ArchiveInspector`（`app/lib/core/manga/archive_inspector.dart`）が唯一の解凍経路を担う。

- `inspect()`（`archive_inspector.dart:71-172`）: 拡張子を `.zip`/`.cbz` に限定（`:84-89`）→ `ZipDecoder().decodeBytes(bytes)`（`:100`）でヘッダのみ解析 → エントリごとにパストラバーサル拒否（`:124`, `_hasPathTraversal` `:216-221`）、隠しメタデータ除外（`:127`, `_isHiddenOrMetadata` `:223-233`）、対応画像拡張子フィルタ（`:130-134`, `kSupportedImageExtensions` `:16-22`）、単一エントリ上限（`kMaxSingleEntryBytes` `:13`）、総展開バイト数上限（`kMaxTotalUncompressedBytes` `:12`）、エントリ数上限（`kMaxEntryCount` `:11`）を適用し、自然順ソート（`_naturalCompare` `:237-257`）で確定順に整列する。
- `readPageBytes()`（`:177-210`）: 該当エントリの `content` を都度取得（`archive` パッケージは central directory のみ先に解析し、`.content` アクセス時に遅延展開するため、`inspect()` はページ内容を実際には展開しない＝爆弾対策として機能している）。
- 呼び出し側: `MangaRepositoryImpl.openArchive()`（`app/lib/features/manga/data/manga_repository_impl.dart:64-100`）が `_inspector.inspect(filePath)` を呼び、拡張子から `format` 列（`:72-75`）を導出して drift に保存（`manga_metadata.dart:16` の `format` 列コメントで `'cbz'`/`'zip'` と明記）。UI 側のファイルピッカーは `allowedExtensions: ['zip', 'cbz']`（`manga_home_section.dart:43`）でこれ以外を選択不可にしている。
- 仕様上の制約: `openspec/specs/local-manga-zip-viewer/spec.md` の「Unsupported archive extension is rejected」シナリオは `.rar` を明示例として ZIP/CBZ 限定を検証しており、`openspec/specs/manga-archive-safety/spec.md` は上記の安全性不変条件を規定している。

7z/RAR は `archive` パッケージがネイティブに対応していない（ZIP/TAR/GZip/BZip2/XZ 系のみ）。7z は LZMA/LZMA2 ベース、RAR は RARLab 独自方式であり、いずれも Dart 純正実装が実用段階にない。

## Goals / Non-Goals

**Goals:**
- 7z/CB7 アーカイブを ZIP/CBZ と同等の安全性・体験（ページ順序、エラーメッセージ、保存位置の再開）で開けるようにする。
- 新形式追加にあたり、`manga-archive-safety` の不変条件（パストラバーサル拒否、隠しファイル除外、サイズ上限、決定的順序）を形式非依存の共通レイヤーで再利用し、形式ごとの実装漏れを防ぐ。
- Apache-2.0 の OSS プロジェクトとして再配布可能なライセンスの解凍ライブラリのみを採用する。
- RAR/CBR について、ライセンス上安全に実装できる方式が定まるまでは実装を保留し、利用者には「未対応」だと明確に伝える。

**Non-Goals:**
- 本 change で RAR/CBR の解凍を実装すること（評価結果に基づき、フォローアップ GitHub Issue に委ねる）。
- Android/iOS/iPadOS 向けの `libarchive` ネイティブバイナリ配布パイプラインを本 change で完成させること（フィージビリティ検討のみ行う）。
- `archive` パッケージ（ZIP 経路）の置き換え。

## Decisions

### D1: 7z バックエンドに `libarchive`（BSD-3-Clause）を FFI 経由で採用する

- **選択肢と比較**:
  - **`libarchive`（C, BSD-3-Clause）**: 7z/RAR/TAR/ISO 等を単一の寛容ライセンスライブラリで読み取り可能。RAR リーダーは RARLab の unrar ソースを流用せず libarchive プロジェクトが独自実装したもので、BSD ライセンスの範囲に収まる（RARLab 公式 unrar の「UnRAR ライセンス」— 改変・再配布制限、RAR 互換アーカイバへの利用禁止条項 — を回避できる）。ただし Dart/Flutter 向けの成熟した FFI バインディングは現状存在しないため、`dart:ffi` で薄いバインディングを自作し、プラットフォームごとにプリビルドの `libarchive` 共有ライブラリ（macOS: dylib、Windows: dll、Android: so）を同梱する必要がある。
  - **7-Zip 公式バイナリ（`7z`/`7za`）をサブプロセスとして呼び出す**: 7-Zip コア（LZMA SDK）はパブリックドメイン、7-Zip 本体は LGPL + BSD 3-Clause（UnRAR 制限は RAR 圧縮コードにのみ適用され、7z 展開には無関係）。実装は容易だが、プラットフォームごとに公式バイナリを同梱・実行権限管理する必要があり、モバイル（Android/iOS）ではサブプロセス起動が事実上不可能なため v0.2 のクロスプラットフォーム方針と相性が悪い。
  - **`unrar-free`（GPLv2/3）を静的/動的リンク**: 7z 非対応（RAR 専用）。GPL コードをアプリに直接リンクすると結合著作物として GPL 適用範囲が広がる懸念があり、Apache-2.0 配布方針と衝突するため不採用。
  - **決定**: `libarchive`（BSD-3-Clause）への FFI バインディングを採用する。理由は (1) 7z と将来的な RAR 読み取りを単一ライブラリで扱え設計を一本化できる、(2) ライセンスが寛容で Apache-2.0 と完全に両立する、(3) サブプロセス起動が不可能なモバイルでも FFI 経由の共有ライブラリなら動作しうる。ただし FFI バインディング自作とプラットフォームごとのバイナリ同梱は工数が大きいため、本 change ではデスクトップ（macOS/Windows）を優先実装対象とし、Android は後続タスクでの検証事項とする。

### D2: RAR/CBR の完全実装は本 change では見送る

- Issue #52 は RAR 対応を明示的に要望しているが、以下の理由で本 change のスコープからは外し、評価結果を添えてフォローアップ GitHub Issue に切り出す:
  1. RARLab の公式 unrar は「UnRAR ライセンス」下で、ソース改変・再配布や RAR 互換アーカイバへの利用を制限しており、Apache-2.0 かつストア配布なし・GitHub Releases のみという OSS 配布方針と摩擦がある。
  2. `libarchive` の RAR リーダーは独自実装で BSD ライセンスだが、RAR5 の一部圧縮方式（特に最新の RAR5 高度モード）の網羅性・保守状況を実装前に検証する必要があり、本 change の調査だけでは確証が持てない。
  3. RAR/CBR はモバイル配布まで見据えると `libarchive` の Android/iOS 同梱という追加のフィージビリティ課題を抱えており、7z 単独導入より検証項目が多い。
- 対応: `.rar`/`.cbr` はファイルピッカーでは引き続き選択不可（`allowedExtensions` に追加しない）とし、`ArchiveInspector` 相当のフォーマット判定層で `.rar`/`.cbr` を検出した場合は汎用 `UnsupportedFormatError` ではなく「RAR/CBR は現時点で未対応（Issue #52 からリンクするフォローアップ Issue で検討中）」だと分かるメッセージ・エラーコードに更新する。本 change は評価結果をその Issue に引き継ぎ、RAR/CBR の解凍実装は行わない。

### D3: 安全性チェックを形式非依存の共通レイヤーに抽出する

- 現行の `ArchiveInspector.inspect()` は ZIP 専用の `ZipDecoder` 呼び出しと安全性チェックが同一メソッド内に混在している（`archive_inspector.dart:98-172`）。7z 追加にあたり、「アーカイブを開いてヘッダ相当の一覧を得る」処理をフォーマットごとのバックエンドに委譲し、パストラバーサル判定・隠しファイル除外・画像拡張子フィルタ・エントリ数/サイズ上限・自然順ソートは形式に依存しない共通関数として一本化する。これにより新形式追加時に安全性チェックの実装漏れ（コピペ漏れによる 7z だけパストラバーサル未対応、等）を防ぐ。
- 7z バックエンドはヘッダ列挙中にエントリ数を数え、`kMaxEntryCount` を超えた時点で列挙を中断する。全ヘッダの収集後に検査する方式にはせず、空エントリを大量に含むアーカイブによる CPU/メモリ枯渇を防ぐ。
- ZIP は既存の `archive` パッケージ実装をそのままバックエンドとして温存し、挙動・パフォーマンスを変えない。

### D4: 解凍爆弾対策は「宣言サイズ」と「実展開サイズ」の両方を検証する

- 現行 ZIP 経路は ZIP ローカルファイルヘッダの宣言サイズ（`entry.size`）のみを検査しており、`inspect()` 自体は実際に展開しない（`.content` 遅延評価）ため安全だが、ヘッダの宣言値が偽装されている場合の検証は行っていない。
- 7z/LZMA はきわめて高い圧縮率（例: 数 KB → 数 GB）を実現しうるため、ヘッダの宣言サイズを鵜呑みにするとヘッダ自体が偽装された場合に展開時点で暴走するリスクがある。`libarchive` はストリーミング API（`archive_read_data` を逐次呼び出す方式）を提供するため、7z バックエンドでは「宣言サイズでの事前チェック」に加えて「実際に展開しながら累積バイト数が `kMaxSingleEntryBytes`/`kMaxTotalUncompressedBytes` を超えた時点で即座に中断する」形式非依存の二段防御を必須要件とする。この要件は `manga-archive-safety` capability の MODIFIED spec に追加する。
- `kMaxTotalUncompressedBytes` の実展開値は、開いているアーカイブセッションごとに、初めて読み出した各エントリの実測サイズを累積する。同じページの再読込は二重計上せず、バックエンドセッションがエントリ別の検証済みサイズと累積値を保持する。これにより `readPageBytes()` がページを都度展開しても、複数ページにまたがる総量上限を適用できる。

## Risks / Trade-offs

- **[Risk] libarchive の FFI バインディングとプラットフォーム別バイナリ同梱の実装コストが見積もりより大きい** → Mitigation: 本 change ではデスクトップ（macOS/Windows）優先とし、Android 対応は後続 change でフィージビリティ検証してから着手する。既存の保守された Dart/Flutter 向け libarchive ラッパーが実装フェーズで見つかった場合はそちらを優先する。
- **[Risk] RAR 対応を見送ることで Issue #52 の主要な要望（RAR）が未達のまま close されるという印象を与える** → Mitigation: proposal.md に理由を明記し、評価結果を添えたフォローアップ GitHub Issue の起票と #52 からのリンクを tasks.md に含める。ユーザー向けメッセージで「検討中」であることを明示する。
- **[Risk] 7z の LZMA/LZMA2 展開は ZIP の deflate より CPU/メモリ負荷が高く、モバイル端末での展開時間・メモリ使用量が既存 UX 基準を悪化させる可能性** → Mitigation: design 検証時にベンチマーク（代表的なコミック 1 巻サイズ相当の 7z）を実施し、`kMaxTotalUncompressedBytes` 等の上限値がそのまま適用可能か再確認する。
- **[Risk] libarchive の RAR リーダーが将来的に RAR5 の一部圧縮方式を完全サポートしない場合、フォローアップ Issue でも同じライセンス制約に直面する** → Mitigation: フォローアップ Issue 起票時に libarchive の RAR5 対応状況を再調査し、対応不十分なら「RAR4 のみ対応」等の縮小スコープを検討する。

## Validation

- `cd app && dart format --output=none --set-exit-if-changed .`
- `cd app && flutter analyze --fatal-infos`
- `cd app && flutter test`（`archive_inspector_test.dart` に 7z フィクスチャケースを追加）
- `openspec validate --all --strict`
- `git diff --check`
- 手動検証: 代表的な 7z/CB7 コミックアーカイブ（正常系、パストラバーサル混入、隠しファイル混入、サイズ超過、破損アーカイブ）を macOS/Windows で開き、ZIP/CBZ と同等の挙動になることを確認する。`.rar`/`.cbr` ファイルをピッカーで選択できないこと、直接パス指定で開こうとした場合に更新後のエラーメッセージが表示されることを確認する。

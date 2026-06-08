# upscale-model-distribution Specification

## Purpose

Provides on-device distribution and lifecycle management for AI-upscaling models: a bundled static catalog of model metadata, first-run HTTPS download with SHA-256 verification, a versioned on-disk cache, and presence/size/delete operations. Supplies the `MlRuntime` seam with a `ModelStateResolver` and `OnnxModelSource` so the runtime can degrade to the bicubic CPU floor whenever a model is absent. Model binaries are never bundled in the app.

## Requirements

### Requirement: モデルカタログ

システムは、アプリに同梱された静的なモデルカタログを提供しなければならない (SHALL)。各エントリは少なくとも モデル ID、バージョン、ダウンロード URL (HTTPS)、期待される SHA-256 ハッシュ、スケール係数、ライセンス識別子を持つ。モデルバイナリはアプリ本体に同梱してはならない (MUST NOT)。

#### Scenario: カタログエントリが必須メタデータを持つ

- **WHEN** モデルカタログの任意のエントリを参照する
- **THEN** そのエントリは モデル ID・バージョン・HTTPS の URL・期待 SHA-256・スケール係数・ライセンス識別子を持つ

#### Scenario: モデルバイナリは同梱されない

- **WHEN** ビルド済みアプリのアセットを検査する
- **THEN** アップスケールモデル (.onnx) バイナリはアセットに含まれない

### Requirement: 初回ダウンロードと SHA-256 検証

`ModelRepository` は、選択されたカタログエントリのモデルを HTTPS で取得し、保存前に内容の SHA-256 を期待ハッシュと照合しなければならない (MUST)。ハッシュが一致した場合のみ、モデルをバージョン付きの最終キャッシュ位置に確定する。一致しない場合、部分ファイルを破棄し、catchable なエラーを返さなければならない (MUST)。

#### Scenario: ハッシュ一致でモデルが確定される

- **GIVEN** ダウンロード内容の SHA-256 がカタログの期待ハッシュと一致する
- **WHEN** `ModelRepository.ensureModel` がそのエントリに対して解決する
- **THEN** モデルはバージョン付きキャッシュ位置に保存され、そのファイルパスが返る

#### Scenario: ハッシュ不一致で破棄しエラーになる

- **GIVEN** ダウンロード内容の SHA-256 が期待ハッシュと一致しない
- **WHEN** `ModelRepository.ensureModel` が実行される
- **THEN** 部分ファイルはキャッシュに残らず、catchable なエラーが返り、プロセスはクラッシュしない

### Requirement: バージョン付き on-disk キャッシュ

`ModelRepository` は、検証済みモデルを `path_provider` のアプリサポートディレクトリ配下に、モデル ID とバージョンで一意に決まるパスでキャッシュしなければならない (MUST)。同一バージョンが既にキャッシュ済みのとき、再ダウンロードしてはならない (MUST NOT)。

#### Scenario: キャッシュ済みモデルは再ダウンロードしない

- **GIVEN** あるモデル ID・バージョンが検証済みでキャッシュに存在する
- **WHEN** 同じ モデル ID・バージョンに対して `ensureModel` が再度呼ばれる
- **THEN** ネットワーク取得は行われず、既存のキャッシュパスが返る

#### Scenario: バージョン差はパスを分離する

- **GIVEN** 同一モデル ID の異なる 2 バージョン
- **WHEN** それぞれが検証・キャッシュされる
- **THEN** 互いに異なる on-disk パスに保存され、一方の削除が他方に影響しない

### Requirement: モデルの状態照会・サイズ・削除

`ModelRepository` は、あるカタログエントリが端末に存在するか (present / absent)、その on-disk サイズ (バイト)、および削除を提供しなければならない (MUST)。削除後、その エントリは absent を報告し、占有サイズは 0 になる。

#### Scenario: 存在しないモデルは absent を報告する

- **WHEN** まだダウンロードしていないエントリの状態を照会する
- **THEN** 状態は absent で、報告サイズは 0 である

#### Scenario: 削除でモデルが absent に戻る

- **GIVEN** 検証・キャッシュ済みのモデル
- **WHEN** そのモデルを削除する
- **THEN** 状態は absent を報告し、再度の削除は安全な no-op である

### Requirement: `MlRuntime` 向けの ModelStateResolver と OnnxModelSource 供給

`upscale-model-distribution` は、選択中モデルの有無を `MlModelState` (present / absent) として返す `ModelStateResolver` を `MlRuntime` に供給しなければならない (MUST)。モデルが present のとき、そのファイルパスを `OnnxModelSource.file` として供給できなければならない (MUST)。

#### Scenario: present のとき file source を供給する

- **GIVEN** 選択中モデルが検証・キャッシュ済み
- **WHEN** upscaler 配線がモデル source を要求する
- **THEN** キャッシュパスを指す `OnnxModelSource.file` が供給され、`ModelStateResolver` は present を返す

#### Scenario: absent のとき floor 用に source を供給しない

- **GIVEN** 選択中モデルが未取得
- **WHEN** upscaler 配線がモデル source を要求する
- **THEN** モデル source は null で、`ModelStateResolver` は absent を返す

### Requirement: ダウンロード失敗は劣化し、クラッシュしない

ネットワーク失敗、HTTP エラー、I/O 失敗のいずれでも、`ModelRepository` は catchable なエラーを返し、キャッシュ状態を absent のまま保たなければならない (MUST)。これにより `MlRuntime` の選択 seam は bicubic CPU floor に劣化できる。

#### Scenario: ネットワーク失敗で absent を保つ

- **GIVEN** ダウンロードがネットワークエラーで失敗する
- **WHEN** `ensureModel` が実行される
- **THEN** catchable なエラーが返り、対象モデルは absent のまま、プロセスはクラッシュしない

### Requirement: ネットワーク取得テストは決定的なフェイクで行う

本 capability のテストは、実ネットワークや実 GitHub Releases に依存してはならない (MUST NOT)。HTTP クライアントを注入可能にし、固定バイト列を返すフェイクで DL・検証・キャッシュ・削除・失敗時フォールバックを検証する。これらのテストは `flutter test` でローカル・全 CI ジョブにおいて GPU やネットワークなしで通過しなければならない (MUST)。

#### Scenario: フェイククライアントで検証経路を網羅する

- **GIVEN** 固定バイト列と既知 SHA-256 を返す注入済みフェイク HTTP クライアント
- **WHEN** ハッシュ一致・不一致・ネットワーク失敗の各ケースを実行する
- **THEN** それぞれ 確定・破棄・劣化 が期待どおりに起き、実ネットワークアクセスは発生しない

### Requirement: 実モデル選定基準

配布カタログ (`UpscaleModelCatalog`) の各**恒久エントリ**は、次のすべてを満たす実モデルを指さなければならない (MUST): (1) 寛容ライセンス（BSD-3-Clause または MIT など、利用制限のないもの）、(2) 同梱ネイティブランタイム ONNX Runtime 1.15.1 が対応する opset（≤19、推奨エクスポート opset 17）、(3) アニメ/イラスト向けにチューニングされたモデル系統。nearest-neighbor 等の fixture/placeholder モデルを恒久エントリにしてはならない (MUST NOT)。Research-only RAIL など利用制限付きライセンスのモデルを採用してはならない (MUST NOT)。

#### Scenario: 恒久エントリが選定基準を満たす

- **WHEN** カタログの任意の恒久エントリ（2x / 4x）を参照する
- **THEN** そのエントリは寛容ライセンス・ORT 1.15.1 互換 opset・anime-tuned 系統の実モデルを指し、license フィールドが実際の weights ライセンスと一致する

#### Scenario: fixture は恒久エントリにしない

- **WHEN** 出荷ビルドのカタログを検査する
- **THEN** nearest-neighbor 等の placeholder/fixture モデルは恒久エントリに含まれない（テスト専用 fixture はテストコード側に限定する）

### Requirement: 採用モデルの出所とライセンスの追跡可能性

カタログの各恒久エントリについて、システムは採用モデルの**出所（upstream）とライセンス根拠**を変更成果物に記録しなければならない (MUST)。2x・4x の両スロットは **RealESRGAN_x4plus_anime_6B**（xinntao/Real-ESRGAN, BSD-3-Clause）を採用し、ホスト前に upstream リポジトリの LICENSE を直接確認しなければならない (MUST)。2x スロットは別モデルを持たず、4x モデルを native 4x で実行し ×0.5 縮小して得る（`modelScale`/`downscaleFactor`、design D8）。

#### Scenario: ライセンス根拠が確認済みである

- **GIVEN** カタログに登録予定の採用モデル
- **WHEN** GitHub Release にホストする前
- **THEN** upstream リポジトリの LICENSE を直接確認した記録があり、license フィールドがそれと一致する

#### Scenario: 2x は 4x モデルの downscale で供給する

- **WHEN** 2x スロットのエントリを参照する
- **THEN** `modelScale` は 4、`scale` は 2、`downscaleFactor` は 2 であり、4x スロットと同一のモデル（同一 URL・SHA-256）を指す

### Requirement: target scale への downscale

native scale（`modelScale`）が target `scale` を上回るエントリについて、システムは、モデルを native scale で実行した出力を `modelScale / scale` で縮小し、最終出力が入力 × `scale` の寸法になるようにしなければならない (MUST)。縮小はエイリアシングを抑える補間（average 等）で行う。

#### Scenario: 4x モデルで 2x 出力を得る

- **GIVEN** `modelScale=4`・`scale=2` のエントリと寸法 W×H の入力
- **WHEN** アップスケールを実行する
- **THEN** モデルは 4x で推論し、出力は ×0.5 縮小されて (W·2)×(H·2) になる

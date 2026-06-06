## ADDED Requirements

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

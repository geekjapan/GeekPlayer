## ADDED Requirements

### Requirement: 実アーキテクチャ・固定形状の CPU-EP smoke

既存の fixture smoke に加え、システムは、**採用モデルと同一の op 種別**（Conv / LeakyReLU / PixelShuffle / residual add / Resize 等）を含み、**同一 opset 17・固定タイル形状**で export した**縮小アーキ**の ONNX（block/channel を縮小した RRDBNet）が、同梱ネイティブ ONNX Runtime 1.15.1 の CPU EP でロードでき、1 タイルの推論を未対応 op なく完走できることを検証しなければならない (MUST)。採用モデルは 2x・4x いずれも Real-ESRGAN RRDBNet（design D8、2x は 4x の downscale）であり、RRDBNet の op 種別が対象である。検証目的は op 種別と opset の互換実証であり、パラメータ数の忠実性は要求しない。実モデルのフル重み（~18MB 等）をリポジトリに同梱してはならない (MUST NOT)。

#### Scenario: 縮小アーキ ONNX が CPU EP でロード・推論できる

- **GIVEN** 採用モデルと同一 op 種別・opset 17・固定タイル形状の縮小アーキ ONNX（数百 KB 以下）
- **WHEN** ORT 1.15.1 CPU EP でセッションを生成し 1 タイルを推論する
- **THEN** 未対応 op で失敗せず、scale 倍の出力タイルが得られる

#### Scenario: 実モデルのフル重みはリポジトリに同梱しない

- **WHEN** リポジトリのテストアセットを検査する
- **THEN** 採用モデルのフル重み（.onnx/.pth、~18MB 等）は含まれず、smoke は縮小アーキのランダム重み ONNX のみを使う

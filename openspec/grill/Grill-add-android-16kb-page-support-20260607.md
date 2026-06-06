## add-android-16kb-page-support — Grill残課題 (20260607)

### Q1. remediation 方針（A: 検査基盤＋待機 / B: AAR 差し替えで即 16KB化）
- **対象**: proposal「What Changes」/ design D1 / tasks 1.1
- **なぜ重要**: A と B で apply の作業量・侵襲度・回帰リスクが根本的に変わる（A=ツール+CI+docs、B=ネイティブ AAR 差し替え+実機推論回帰）
- **検討した選択肢**: A) 検査基盤を整え上流対応待機 / B) Microsoft ORT AAR を即差し替え / C) 別 binding 移行 / D) 不可（runtime トグルでは .so 除去不可）
- **推奨案**: A。AI upscale は Experimental・default-OFF・opt-in、配布は GitHub Releases（ストア非経由）で実害は警告のみ。B の侵襲・回帰コストは現リスクに見合わない
- **不足インプット**: 16 KB 必須デバイスで AI upscale を動かす必要性の見込み（ユーザー判断）
- **Status**: Resolved — 方針 A 採用（design.md Open Questions / tasks.md）

### Q2. CI 検査の初期厳格度
- **対象**: design D2 / specs/ci-build-matrix / tasks 2.2,3.x
- **なぜ重要**: 現状 libonnxruntime.so が非対応のため、例外なし厳格 fail だと CI が即赤になる
- **推奨案**: `libonnxruntime.so` のみ warning 例外、それ以外は fail。onnxruntime 解消時に例外撤去
- **不足インプット**: Q1 に従属
- **Status**: Resolved — warning 例外で開始（撤去条件をコード/コメントに明記）

### Q3. 監査スクリプト実装方式
- **対象**: design D2 / tasks 2.1
- **推奨案**: 純正 Python ELF パーサ（外部依存なし・CI 環境差に強い・ローカル流用可）
- **Status**: Resolved — `tool/check_so_alignment.py`（Python, NDK 非依存）

### Q4. 方針 B の ORT バージョン pin
- **対象**: design D1(B) / tasks 1.3,4.1
- **Status**: Resolved — N/A（方針 A 採用のため対象外。B 昇格時に再オープン）

# 0003 — 小説家になろう / R18 系統の本文取得方針

**Status**: accepted (2026-05-27)

## Context

[ADR-0001](0001-online-novel-fetch-policy.md) はオンライン小説 3 サイトの取得方針を
定めたが、当初の前提は「なろう / ノクターン系は公式 API、カクヨムのみ HTML パース」
だった。実装計画段階で再確認した結果、**小説家になろう / ノクターン系の "本文取得"
は公式 API が提供しておらず**、検索 / 一覧 / 作品メタデータのみが API でカバーされる
ことが判明した（[GRILL-REPORT Q-NAR-002](../GRILL-REPORT.md) 参照）。

具体的には:

| エンドポイント | 用途 | 公式 API |
|---|---|---|
| `https://api.syosetu.com/novelapi/api/` | 検索 / メタデータ | ✅ |
| `https://api.syosetu.com/novel18api/api/` | R18 検索 / メタデータ | ✅ |
| `https://api.syosetu.com/rank/rankget/` | ランキング | ✅ |
| `https://ncode.syosetu.com/<ncode>/<n>/` | **本文ページ** | ❌（HTML のみ） |
| `https://novel18.syosetu.com/<ncode>/<n>/` | **R18 本文ページ** | ❌（HTML のみ） |

本文表示はアプリ体験の核なので「諦める」選択肢は取らず、ADR-0001 と同等の責任ある
スクレイピング規範を **なろう / ノクターン系にも適用** することにする。

## Decision

**ADR-0001 と等価の運用規範をなろう / ノクターン系の本文取得にも適用する。**
カクヨムのみが特別扱いではなく、「公式 API がない部分は HTML パース」という共通
原則のもとに 3 サイトすべてを位置付ける。ADR-0001 を拡張するのではなく、本 ADR
を独立に立てるのは、なろう特有の事情（R18 年齢確認、ルビ記法、ncode 体系）を
個別に記録するため。

### 取得方針（ADR-0001 を継承）

1. **能動キャッシュのみ**: ユーザーが `Library` に追加した `Work` の本文だけがローカル DB に保存される。受動的なクロール / ミラーリングは行わない。
2. **TTL なし** / ユーザー手動削除。
3. **レート制限（なろう/ノクターン系の origin 単位）**:
   - 検索 / メタデータ API (`api.syosetu.com`): **1 req / sec / 並列 2**
   - 本文ページ (`ncode.syosetu.com` および `novel18.syosetu.com`): **1 req / sec / 並列 1**
   - 検索系と本文系は別 origin だが、サーバー側の体感負荷を抑えるため `RateLimiter` の bucket は **`*.syosetu.com` で共通化**
4. **User-Agent**: `GeekPlayer/<version> (+https://github.com/geekjapan/GeekPlayer; personal-use)` — ADR-0001 と同一文字列
5. **`robots.txt` 尊重**（`api.syosetu.com` / `ncode.syosetu.com` / `novel18.syosetu.com` の 3 origin それぞれを取得・キャッシュ TTL 24h）
6. **429 / 503 で指数バックオフ**（最大 5 分、最大 6 回リトライ）
7. **R18 同意ダイアログ**: ノクターン系（`novel18api` および `novel18.syosetu.com`）にアクセスする前に `Site.noc` の `SiteConsent` を取得（年齢確認、`policyVersion: 'age-verified'`）

### 注意書きの掲示場所（4 箇所）

ADR-0001 と同じ 4 箇所に **なろう用** の注意書きも追加する:

1. `README.md`: 「小説家になろう / ノクターン系の本文取得は HTML パースを含む」の節
2. アプリ初回起動: 同意ダイアログにカクヨムと並べて narou / noc のチェックボックスを表示（ノクターン系は別途年齢確認）
3. `Settings > オンライン小説` 画面: 各サイトのレート制限値と運用規範を常時表示
4. `NarouEpisodeFetcher` / `NarouR18EpisodeFetcher` クラスの docstring

### サイト別の差別化要素

- **小説家になろう** (`Site.narou`): 同意は「責任あるスクレイピング規範への同意」（カクヨムと同じ枠組み）。`policyVersion` は ADR バージョン文字列。
- **ノクターン系** (`Site.noc`): 同意は **(a) 年齢確認（18 歳以上）** + **(b) 責任あるスクレイピング規範** の 2 段階。同じ `site_consents` 行に格納するが、`policyVersion` 値で意味論を分けるか別行を立てるかは実装段階で決定（GRILL-REPORT Q-NAR-001 のフォローアップ）。
- **カクヨム** (`Site.kakuyomu`): ADR-0001 既定通り。

## Considered Options

- **(a) ADR-0001 に追記して 1 つにまとめる**: 簡潔だが、ADR-0001 が「責任あるスクレイピング全般」になり、本来の動機（カクヨム特有の懸念）が薄まる。
- **(b) ADR-0003 を新規に起こす（採用）**: なろう / ノクターン系の事情を個別に記録できる。後年 R18 検証が法務的に変わった時、本 ADR 単位で superseded にできる。
- **(c) なろう本文取得を諦めて WebView / 外部ブラウザに倒す**: アプリ内オフライン読書という体験価値が消える。3 サイト統合体験の旗印を維持できない。

## Consequences

- `NarouEpisodeFetcher` / `NarouR18EpisodeFetcher` の保守コストは、なろう側 HTML 構造変更に応じて発生する。スナップショットテスト + 統合テストで早期検知する（カクヨムと同じ運用）。
- `add-online-novel-library` の `responsible-fetching` capability に `Site.narou` / `Site.noc` も含めて適用する（カクヨム専用ではなくなる）。
- 将来なろう側が本文取得 API を提供した場合、本 ADR は新 ADR で superseded する。
- 将来なろう側が ToS で明示的に自動収集を禁止した場合、本機能は速やかに無効化し、WebView / 外部ブラウザに切り替える（ADR-0001 と同じフォールバック方針）。
- `add-narou-novel-reader` change の `narou-novel-source` capability spec は本 ADR への参照を含むこと（design.md と spec.md の冒頭で `[ADR-0003]` リンク）。

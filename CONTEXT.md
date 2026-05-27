# GeekPlayer

クロスプラットフォーム・マルチメディアプレイヤー。動画/音楽/小説/書籍/漫画 を 1
アプリで扱う統合体験を提供する。

## Language

**Work**:
ユーザーが視聴/閲覧する単位のコンテンツ。動画 1 本、アルバム 1 つ、小説 1 作品。
_Avoid_: Title, Item, Content

**Episode**:
**Work** を構成する 1 つの視聴単位。動画 1 ファイル / 楽曲 1 トラック / 小説 1 話 / 漫画 1 巻。
_Avoid_: Chapter, Track, Part

**Site**:
オンライン **Work** の供給元。例: `narou`（小説家になろう）、`noc`（ノクターン系）、`kakuyomu`。
_Avoid_: Provider, Source, Service

**MediaSession**:
再生/閲覧状態を抽象化したエンティティ。Position / Buffer / Speed / PlayState を持つ。
動画は `VideoSession`、音楽は `AudioSession`、将来の漫画/書籍は `PageSession` として
同じ抽象に属する。
_Avoid_: Player, Controller, Playback

**ResumePoint**:
**Episode** ごとの「前回どこまで進めたか」。動画/音楽はミリ秒、小説/漫画はページや
スクロール位置。
_Avoid_: Bookmark, Progress

**Library**:
ユーザーが明示的に「保存」した **Work** の集合。v0.1 では小説のみ。v0.2 で動画/音楽
にも拡張する。
_Avoid_: Collection, Vault

**SiteConsent**:
特定の **Site** に対してユーザーが付与した利用許可。カクヨム機能のように追加同意が
必要な **Site** で利用する。
_Avoid_: Permission, Agreement

## Relationships

- A **Site** publishes many **Work**s.
- A **Work** has one or more **Episode**s.
- An **Episode** has zero or one **ResumePoint** per user.
- A **Library** entry references one **Work**.
- A **SiteConsent** is required before fetching from a restricted **Site** (current example: `kakuyomu`).

## Example dialogue

> **Dev:** "ユーザーが小説を 50 話読んだ状態でアプリを閉じたら、次回どこから開く?"
> **Domain expert:** "その **Work** に紐づく直近の **Episode** の **ResumePoint** から再開する。 **ResumePoint** がなければ **Work** の最初の **Episode** を開く。"

> **Dev:** "**Library** に追加していないカクヨム作品の本文を、一度読んだらキャッシュする?"
> **Domain expert:** "しない。**Library** 追加を能動的アクションとして扱う。受動キャッシュは ADR-0001 の方針で禁止。"

## Flagged ambiguities

- "再生" は動画/音楽の文脈、"閲覧" は小説/漫画/書籍の文脈で使われがちだが、ドメイン
  上は同一の **MediaSession** 抽象に収まる。UI 文言レイヤでのみ分岐させる。

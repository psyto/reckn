# STATUS — Reckn / ETHOnline 2026

**Phase 0 — Harness**（2026-09-03）

## 現在地

| | |
|---|---|
| イベント | ETHOnline 2026（9/4–16 async）、Continuity: **Ship a Feature** |
| 製品の事前作業の終端 | `a122b448887eb71b11f87c7d9cdf65afdc25fe69`（2026-08-02） |
| **`EVENT_START`** | **`121194ca3e25bab4ec92aaa4da1277f3a60b8421`**（2026-09-03 の最終 commit）。これ以降＝当日作業 |
| 当日作業の定義 | **日付が 2026-09-04 以降の commit のみ**（ハッシュでなく日付が一次） |
| 中心主張 | 判定する鍵が存在しない — `bash scripts/no-keys.sh` **PASS** |
| 凍結予定 | **9/12**（9/13–15 は R[3]sidency 締切 9/15 に明け渡す） |
| 撤退可能点 | **9/9** — 001/002 が緑でなければ founder 判断 |

## 完了

- Phase 0 — ハーネス: `AGENTS.md` / `CLAUDE.md` / `.claude/agents/` / `scripts/no-keys.sh`
- `scripts/no-keys.sh` は**負のコントロール3件**（`admin` フィールド追加 / 列挙外の関数追加 /
  `msg.sender` ゲート追加）で**いずれも正しく落ちること**を確認済み。
- 計画と事前開示文: `docs/ethonline-2026/{PLAN,DISCLOSURE}.md`
- **ドキュメント整合（9/3、事前作業／製品機能の変更なし）** — `README.md` に
  ①中心主張をビルド条件として明記 ②ETHOnline の境界（**当日作業=9/4以降の日付**、
  この README の内容は全て事前作業）③`Known gaps (not closed)`（**`RecknZkEscrow`
  に timeout が無く proof が来なければ資金がロックする**ことを含む）④欠けていた
  `zk-verdict/` とハーネスを Repository layout に追加 ⑤Collaboration model を
  「人間がリレーする」から現行ハーネスへ。あわせて `README:21` の
  「single instruction の PoC」を訂正（**EVM guest は実 revm を MPT 検証済み
  prestate 上で走らせている**。SVM 側だけが narrow slice）、`SUBMISSION.md` に
  未提出であることと ETHOnline が live entry であることを明記、
  `zk-verdict/program-revm/src/main.rs` の**コードに追いついていなかった**
  モジュールコメント（MPT 検証は「次に折り込める」→ 既に実装済み）を訂正。

## 次

1. **founder**: ETHOnline に応募（<https://ethglobal.com/events/ethonline2026>）
2. **founder**: 9/4 に `DISCLOSURE.md` を ETHGlobal へ送付
3. **9/4 以降**: `reckn-spec` → task 001（keyless timeout）の仕様を
   `docs/specs/001-keyless-timeout.md` に固める → `reckn-codex-review`(stage=spec) → `reckn-codex-impl`

## Day 1（2026-09-04）— 起点の記録

`EVENT_START = 121194c`。**これ以降の commit が当日作業**であり、以前は全て事前作業。

**9/3 の founder 裁定（`_applications/HANDOFF-2026-09-03-reckn-spec-timing.md`、22:15 作成）は
実行されていない。** 裁定は「仕様の事前執筆は開示すれば合法。9/3 に 001/002 の仕様を書き、
9/4 朝から実装に入る」だったが、Reckn の窓はその 25 分前（21:50）に最後の commit を打って
終わっていた。結果:

- `docs/specs/` `docs/reviews/` は**空のままイベントに入った**。仕様執筆は当日作業に食い込む。
- **ただし規約上の損失は無い。** 事前に仕様を書かなかったので、`DISCLOSURE.md` に
  追記すべき事前仕様も存在しない（裁定 §2(a)3 の追記は**不要**）。今日書く仕様は
  当日作業であり、開示の対象外。
- 失ったのは**正当性ではなく時間**。9/12 凍結までの実働8日のうち、初日が仕様に乗る。

裁定 §2(a) の規律更新（「境界をコードに引く」旨の `AGENTS.md` 追記）は、**この
イベントに対しては空振り**になった。次回イベントのために線を動かすかは founder 判断で、
今は当日作業を優先する。

## 未送付 / 未実行

- 事前開示の送付（founder の手）
- `psyto/reckn` の public 化（**提出時**、founder の合図で）

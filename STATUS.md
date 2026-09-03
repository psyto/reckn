# STATUS — Reckn / ETHOnline 2026

**Phase 0 — Harness**（2026-09-03）

## 現在地

| | |
|---|---|
| イベント | ETHOnline 2026（9/4–16 async）、Continuity: **Ship a Feature** |
| 基準コミット（事前作業の終端） | `a122b448887eb71b11f87c7d9cdf65afdc25fe69`（2026-08-02） |
| 中心主張 | 判定する鍵が存在しない — `bash scripts/no-keys.sh` **PASS** |
| 凍結予定 | **9/12**（9/13–15 は R[3]sidency 締切 9/15 に明け渡す） |
| 撤退可能点 | **9/9** — 001/002 が緑でなければ founder 判断 |

## 完了

- Phase 0 — ハーネス: `AGENTS.md` / `CLAUDE.md` / `.claude/agents/` / `scripts/no-keys.sh`
- `scripts/no-keys.sh` は**負のコントロール3件**（`admin` フィールド追加 / 列挙外の関数追加 /
  `msg.sender` ゲート追加）で**いずれも正しく落ちること**を確認済み。
- 計画と事前開示文: `docs/ethonline-2026/{PLAN,DISCLOSURE}.md`

## 次

1. **founder**: ETHOnline に応募（<https://ethglobal.com/events/ethonline2026>）
2. **founder**: 9/4 に `DISCLOSURE.md` を ETHGlobal へ送付
3. **9/4 以降**: `reckn-spec` → task 001（keyless timeout）の仕様を
   `docs/specs/001-keyless-timeout.md` に固める → `reckn-codex-review`(stage=spec) → `reckn-codex-impl`

## ⚠ 9/3 に実装を始めない

イベント開始は **9/4**。それ以前に書いたコードと設計は、規約上すべて**事前作業**であり、
当日分として主張できない。今日 001 の仕様や実装に着手すると、

- 正直に開示する → 001 を当日作業として失う
- 開示しない → **失格・賞金剥奪・BAN**

の二択になる。**今日はハーネスと計画で止める。** ハーネス自体は事前作業として
`DISCLOSURE.md` に記載済み（tooling であり製品機能ではない）。

サイクル開始は 9/4。

## 未送付 / 未実行

- 事前開示の送付（founder の手）
- `psyto/reckn` の public 化（**提出時**、founder の合図で）

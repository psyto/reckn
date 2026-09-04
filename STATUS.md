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
| 撤退可能点 | **9/9** — **003（001 の受入条件を内包）が緑**でなければ founder 判断（`AGENTS.md` §7、2026-09-04 の実行順裁定に合わせる。旧文言「001/002 が緑」は使わない） |

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

## レビュー

| task | stage | round | verdict | 記録 |
|---|---|---|---|---|
| 003 key gauntlet（001 を内包） | spec | r1 | **CHANGES** | `docs/reviews/003-spec-r1.md` |

**003 spec r1（2026-09-04）— CHANGES。** Codex を独立レビュアとして1回呼び、5 findings を受領。
自分で行単位に裁定し、**12 findings（BLOCKER 3 / MAJOR 6 / MINOR 3）**を残した。Codex 由来は
5 件中 4 件を採用（1 サブ主張を証拠付きで却下）、残り 8 件は裁定側の発見。

BLOCKER の中身:

1. **18 AC のうち 11 個が「テストを一行も書かない」実装で緑になる。** `forge test --match-test`
   はパターンが何にも一致しないとき **exit 0**（forge 1.7.1 で実測）。§5 冒頭の
   「Every AC is a command whose exit status decides it」は 11 個について偽。
2. **AC-6 と AC-8 のコマンドは、テストが存在しても永久に0件一致。** `--match-test` は正規表現
   1本であり `"test_AC06 testFuzz_AC06"` は空白を含むリテラル。AC-6 は binding（INV-9＝製品の
   健全性そのもの）の受入条件で、書かれたままでは必ず空振り。
3. **`transfer` の呼び出し箇所を数える検査がどこにも無い**（Codex 発見、検証済み）。§3.1 の
   「出口は2箇所、AC-1 がビルド条件にする」は成立しない。`fund` 内に
   `if (address(uint160(0x1337)) == msg.sender) { transfer(msg.sender, balanceOf(this)); }` を
   置き `amount == 0` で呼ぶと全額を抜けて、`no-keys.sh`・AC 群・mutant 群を**全部素通り**する。
   = **中心主張が偽のままデモできる状態**。付随して、spec が「本プロジェクトが3回開けた穴」と
   呼ぶ M-1 も、それを殺すはずの AC-2（caller fuzz）では殺せない。

**scope（founder 不確実点②）は spec 側を支持**: `transferFrom` 戻り値未検査の修正は 003 の枠内。
今日の `RecknZkEscrow.sol:86` は false を捨てるので、revert しない偽トークンが**裏付けの無い
Funded deal** を作り、支払いが**同一トークンの他 deal の元本**から出る。全鍵を公開しながら
同一トークンの drain 経路を積んだ gauntlet は gauntlet ではない。**正しい切り口**（004 が守る線）＝
「003 が `RecknZkEscrow.sol` を変えてよいのは、変えなければ matrix の行が真の期待値を持てない箇所だけ」。

**再litigate 不要（検証済みで健全）**: 001 の4条件は G-11/G-13/G-14/G-16/G-17 に**弱まらず全て存在**、
AC-16 の SHA-256 は2本とも再計算一致、行列32行と 20/7/5 の内訳は機械再計数一致、mutant id は37個で一致、
INV-9 の binding 式は `program-revm/src/main.rs:178-190` と一致。

**founder 判断が要るもの**: ①短窓デプロイ開示の形（finding 7）②OQ-1 の署名付き anvil を作るか
（finding 8）③`no-keys.sh` に target 引数を入れること自体（finding 12、`AGENTS.md` §0 は
このチェックの緩和を founder 判断としている）。

## 次

1. **founder**: ETHOnline に応募（<https://ethglobal.com/events/ethonline2026>）
2. **founder**: 9/4 に `DISCLOSURE.md` を ETHGlobal へ送付
3. **`reckn-spec`**: `docs/reviews/003-spec-r1.md` の「What must change before round 2」12項目を
   `docs/specs/003-key-gauntlet.md` に反映 → `reckn-codex-review`(stage=spec, r2)
4. spec が APPROVE になってから `reckn-codex-impl`。**実装・コントラクトは未着手**（r1 の時点で
   `RecknZkEscrow.sol` に変更なし）

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

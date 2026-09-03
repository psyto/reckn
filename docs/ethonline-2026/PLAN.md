# ETHOnline 2026 — Reckn / Track 03 (Ship a Feature)

2026-09-04 – 09-16（async）。**提出は 9/12 に凍結**し、9/13–15 は R[3]sidency（締切 9/15）に明け渡す。

## 差別化（これ一本）

> 他は全部「誰が判定するか」を設計している。Reckn はその問いを消す——**判定する鍵が存在しない。**

模倣不能なのは、競合が全員「鍵を持つ誰か」を抱えているから: TEE 系は TEE オペレータ、optimistic 系は
bonded resolver、feedback 系は投票者。**アーキテクチャを捨てないと同じことが言えない。**

重要: Reckn の**既定経路（optimistic + bonded resolver + challenge window + quorum, `README.md:109`）は
コモディティ**であり、差別化しない。デモは **zk 経路一本**に寄せる。

### 根拠（事前に存在。すべて検証済み）

- `zk-verdict/contracts/src/RecknZkEscrow.sol` — owner / resolver / admin / pause / upgrade **なし**。
  外部関数は `fund` と `settleWithProof` のみ。後者は **permissionless**。
- `zk-verdict/program-revm/src/main.rs` — prestate を `state_root` に対し MPT 検証（アカウント＋ストレージ
  証明）し、**本物の revm を in-guest 実行**して `post` を導出、causal delta 述語を適用。~410k cycles。
- `dealBinding = keccak("reckn/zk/bind/evm/v1" ‖ state_root ‖ address ‖ slot ‖ min ‖ max ‖ plan_hash)`
  により、別の都合の良い実行の proof ではこの deal を決済できない。
- 実 Groth16 で on-chain 検証 → エスクロー決済まで通っている（`RecknZkEscrow.t.sol`）。

## 見つけた穴（＝当日の新規作業の中心）

**`RecknZkEscrow` に timeout が無い。** proof が来なければ資金は永久ロック。本体 `RecknEscrow` は
「four deadlines and timeout escape hatches so funds never lock」を持つ（`contracts/README.md:12`）のに、
鍵の無い方だけが持っていない。**鍵を足さずに塞げる**（期限後は誰でも呼べる permissionless な返金）。

## 当日作るもの（Continuity の "substantive new work"）

1. **Keyless timeout** — `RecknZkEscrow` に期限後の permissionless 返金。「鍵は無い、しかしロックもしない」を成立させる
2. **The key gauntlet** — 全当事者の秘密鍵を画面に晒し、あらゆる窃取経路が revert することをテストと UI で実証
3. **Live adversarial input** — seller の納品主張を自由入力に。審査員自身に嘘を書かせ、LLM 判事は release / 再実行は refund
4. **実ワークロード化** — SSTORE のトイ（slot 7 = 42→142）から実 ERC-20 の入金（USDC balance slot）へ。cycles を実測
5. **スポンサー1本線** — Hedera 上の x402 有料サービス → Arc の USDC でエスクロー → World で人間が裏にいる側だけが紛争を開ける → 決着は鍵のない proof

World の identity は「**誰が紛争を開けるか**」のゲートであり「誰が判定するか」に触れない＝差別化を汚さない。
同じ理由で **Chainlink の Confidential Workflow（TEE handler 必須）は狙わない**。

## 狙う賞（SDK 3枠）

| スポンサー | 枠 | 額 |
|---|---|---|
| Arc / Circle | Agentic Economy + **Continuity** + Mainnet push Continuity | $1,667 + $1,666 + $1,500 |
| Hedera | AI & Agentic Payments（3枠）+ Continuity | $2,000 + $1,000 |
| World | **AgentKit Continuity**（Continuity 専用の最大枠） | $3,500 |

Arc の Mainnet push は **9/30 までに mainnet デプロイ可能**であることが条件（イベント後）。

## 日程

| | |
|---|---|
| 9/3 | ETHOnline に応募（Apply to attend） |
| 9/4–9/5 | 事前作業の**書面開示を送付**・公開リポジトリ作成・Continuity 登録・実ワークロード確定 |
| 9/6–9/8 | keyless timeout + 実 ERC-20 ワークロード化（cycles 実測） |
| 9/9 | **チェックポイント。**未達なら撤退可（R3sidency を守る） |
| 9/10 | key gauntlet（テスト＋UI） |
| 9/11 | ETHGlobal Tokyo 応募判断（同一リポで Track 03 再利用可）／スポンサー統合着手 |
| 9/12 | Arc・Hedera・World を1本線に + 動画。**凍結** |
| 9/13–15 | **R[3]sidency 専任** |
| 9/15前後 | 凍結済みの状態から提出 |

## 主張してはいけないこと（`zk-verdict/README.md` の Honest scope）

- `c-kzg` / `ecrecover` precompile は無効。これを要する plan は非対応
- verdict 値は `u64` にマップ（`u64_low` は limb 0 のみ。2^64 超の残高は切り捨て。USDC 6桁なら安全）
- 1 CALL + 1 delta check。フルブロック / 任意コントラクト集合は more cycles, same architecture
- `state_root` ↔ ブロックヘッダの束縛は off-chain の `reexec-evm::header` 層に残る

## 確定事項

**公開範囲: 提出時に `psyto/reckn` 全体を public**（2026-09-03 決定）。

規約の最低要件は「新規部分のみ永久 OSS」だが、新規部分だけ公開すると審査員がデモを再現できず、
差別化が実演でなく「主張」に戻る。全体公開なら審査員が `bash zk-verdict/scripts/zk-e2e.sh` を自分で
実走し、**「判定する鍵が存在しない」を自分の手で確認できる**——これが最大の武器なので、そこを削らない。
`SUBMISSION.md` の元計画（"flip `psyto/reckn` from private to public — do at submission"）とも一致。

代償として optimistic 経路・keeper・binder も公開されるが、差別化は zk 経路一本であり、
optimistic 経路はもともとコモディティ（`README.md:109`）なので失うものは小さい。
実行タイミングは**提出時**（それまでは private のまま）。

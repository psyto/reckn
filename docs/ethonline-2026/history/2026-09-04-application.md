# ETHOnline 2026 — 応募フォーム回答（Reckn / Hack on Existing Project）

> 2026-09-04 作成。**フォームへ貼る本文は下のコードブロック内**（段落内改行なし、textarea 用）。
> 数値は全て 2026-09-04 に実測。README / STATUS と食い違ったら**この文書でなく実測をやり直す**こと。

## トラック選択

**Hack on Existing Project**。Start from Scratch は選べない — 製品コードは 2026-08-02
（`a122b44`）で一旦終わっており、Scratch を選ぶと既存コード全部が規約違反になる。

⚠ 選択肢の説明文「an existing project **that has been submitted to the hackathon**」の
読み方に注意。「過去に ETHGlobal へ提出済み」が要件なら Reckn は該当しない（**一度も
どこにも提出していない**）。切り替え不可なので、疑義があれば選択前に確認する。

## 実測値（2026-09-04）

| 対象 | 結果 |
|---|---|
| contracts (Foundry, optimistic) | 57 passed / 0 failed |
| zk-verdict/contracts (keyless) | 12 passed / 0 failed |
| reexec-evm (revm) | 16 passed / 0 failed |
| reexec-svm (LiteSVM) | 30 passed / 0 failed |
| binder (cross-VM router) | 6 passed / 0 failed |
| keeper | 3 passed / 0 failed |
| reckn-evm-content | 5 passed / 0 failed |
| **合計** | **129** |
| Groth16 fixture 1本の end-to-end 再生成 | **335.02 s**（うち証明生成 31.71 s、制約 15,972,262） |

`zk-verdict/contracts` の fixture 3本は存在し、skip は発生していない（= 実 Groth16 で
escrow が決済されるテストが本当に走っている）。

## 事実確認の要点（誇張しないための線）

- **EVM**: 再実行 → 証明 → オンチェーン検証 → **escrow 決済**まで実測済み。
- **Solana**: 同じ汎用 verifier がオンチェーンで proof を検証するところまで。
  **`settleWithProof` を呼ぶテストは EVM の fixture のみ** = 決済への配線は未接続。
- **「no bridge / no light client」は adjudication についてのみ真**。committed prestate が
  実状態であることの anchoring は、EVM はヘッダ束縛が off-chain 層、Solana は
  `bank_hash` の出所が未証明。ここを平板に書くと嘘になる。
- 「エージェントにはマルチチェーンが必須」は**測定値でなく thesis**。主張として書き、
  測定値のようには書かない。

---

## Q1: What is the current state of the project?

```
THE THESIS

An AI agent that pays another agent does not live on one chain. It buys compute on one, data on another, and settles in stablecoins on a third. So the hard question is not "which chain do we deploy to" — it is: when a payment is disputed, who decides, and does that decider belong to a chain?

Every escrow in this category answers with a trusted party: a TEE running an LLM, a bonded resolver, a reputation vote. Each of them is a key somebody holds, and each of them is per-chain — you redeploy the judge, re-bond the resolver, and re-earn the reputation on every new chain your agent touches.

Reckn's answer is that the decider should not be a party at all. A disputed delivery is re-executed: the pre-state is pinned, the disputed work is replayed against it, and the predicate the deal was funded against is evaluated. Reproduce, or refund. Because re-execution is deterministic, anyone can redo it and reach the same verdict; because it is a computation rather than an authority, it does not live on a chain. The verdict's authority travels as a proof.

WHAT WORKS TODAY

The disputed work is re-executed inside an SP1 zkVM and a real Groth16 proof settles the escrow directly. RecknZkEscrow has no owner, no admin, no resolver, no pause and no upgrade path, and settleWithProof is permissionless: the right to move the money comes from a proof verifying, and from nothing else. We do not ask to be believed on that — "bash scripts/no-keys.sh" fails the build if a privileged role, an unlisted state-changing function, or a msg.sender gate ever appears.

The same re-execution runs on two deliberately dissimilar runtimes. On EVM, every account and storage slot is MPT-verified against the committed state_root, and then real revm executes the seller's committed CALL inside the guest and derives the post-state (~410k cycles). On Solana, the block bank_hash is recomputed from the committed accounts with the SIMD-0215 lattice hash, the real transaction is signature-verified with ed25519, and its System transfer is re-executed (~980k cycles).

Two state models with nothing in common — a Merkle-Patricia trie and a homomorphic lattice hash — and one generic on-chain verifier accepts both proofs. That is evidence that the trust root is VM-neutral rather than a claim about it. A cross-VM router already replays an EVM dispute and a Solana dispute through a single interface and returns the same verdict type.

The EVM path is complete end to end: re-execute, prove, verify on-chain, and settle to the seller on the proof alone with no resolver, tested with a real Groth16 proof against SP1's canonical verifier. The Solana path is proven and verified on-chain through that same verifier, but is not yet wired into settlement. Closing that is the first thing we do at the event.

Tests, re-measured on 2026-09-04, all green: contracts (Foundry, optimistic path) 57; zk-verdict/contracts (keyless path) 12; reexec-evm (revm) 16; reexec-svm (LiteSVM) 30; binder (cross-VM router) 6; keeper 3; reckn-evm-content 5. Total 129.

Two one-command demos: "bash zk-verdict/scripts/zk-e2e.sh" runs re-execute, prove, verify and settle; "bash scripts/anvil-e2e.sh" runs a full dispute on a throwaway local chain.

LINKS

Source code: https://github.com/psyto/reckn

Money-shot (the same dispute judged by an opinion LLM and by re-execution — toggle honest or false delivery and watch them disagree): https://claude.ai/code/artifact/88a370e4-bfeb-480c-af14-015661e6e6f7

ZK money-shot (re-executed in a zkVM, proven, verified on-chain, settled on the proof alone): https://claude.ai/code/artifact/9ae55be5-4a17-423e-8bb6-67c28838e579

Architecture: docs/protocol-architecture.md in the repository. Open gaps: README.md, section "Known gaps (not closed)".

WHAT IS NOT TRUE YET, SO YOU DO NOT HAVE TO GO FIND IT

A proof carries the verdict's authority. It does not by itself prove that the committed pre-state was the chain's real state. On EVM that anchoring exists but lives in an off-chain layer (the block header binding); on Solana the provenance of the committed bank_hash is not proven on-chain. So "no bridge, no light client" is true of the adjudication and not yet of the anchoring, and we say so in the README rather than in a footnote.

We also found a soundness bug in our own proof on 2026-09-04: the guest computed the balance delta on the low 64 bits while the off-chain engine used the full U256, so a balance decrease could be proven as a maximal credit — a false release. Nothing is deployed and no funds are at risk. It is in the README today, and fixing it is the second thing we do at the event.

Reckn has never been submitted to any hackathon. Product work paused at commit a122b44 on 2026-08-02; everything between then and the event start is tooling, planning and documentation, disclosed in advance.
```

## Q2: What will you be adding to the project at the hackathon?

```
GOAL FOR THE EVENT: make the cross-VM claim real, then make it safe to believe.

Four features, in dependency order. All new work is permanently open-source and the repository is fully public at submission. Our boundary is defined by date: event work is commits dated 2026-09-04 or later, and EVENT_START is recorded in STATUS.md as 121194ca3e25bab4ec92aaa4da1277f3a60b8421.

1. VERDICT DOMAIN SOUNDNESS — because nothing else is worth building on a proof that can lie.

The zkVM guest judged the balance delta on U256 limb 0 while the off-chain engine used the full U256. With pre = 2^64 and post = 2^64 - 1 — a decrease — the guest sees pre = 0 and post = u64::MAX and proves Reproduced, releasing to the seller. At 18 decimals that is any balance above roughly 18.45 tokens. We widen the judgment and the public-values ABI to uint256, move every hashed preimage to fixed-width big-endian with bumped domain tags, and close two adjacent holes of the same shape: the guest's in-memory database silently returns 0 where the off-chain engine returns MissingAccountWitness, and the deal binding commits neither chain_id nor gas_limit. We also make "the same engine runs in-guest" checkable rather than assumed, with a differential test that runs the real guest ELF.

2. CROSS-VM SETTLEMENT: AN EVM ESCROW SETTLED BY A SOLANA PROOF — the headline.

Today a Solana verdict is proven in the zkVM and verified on-chain by the same verifier that accepts EVM verdicts, but only EVM proofs reach settleWithProof. We bind a Solana dispute to a funded EVM escrow and let the SVM proof release or refund it directly. The demo is one sentence: a payment escrowed on an EVM chain, disputed over work performed on Solana, and settled by a proof — with no resolver on either side, no bridge, and no light client in the adjudication path. This is what "the decider does not belong to a chain" means once you can run it.

3. KEY GAUNTLET — we hand you the keys and dare you.

We publish the private keys of every party — buyer, seller, deployer — and demonstrate with a 38-row test matrix and a UI that every theft path reverts. Anyone watching can take those keys and try. It includes the missing keyless timeout: today a funded deal with no proof stays funded forever. We add a permissionless refundAfterDeadline — anyone may call it after the deadline, nobody before, the refund path dies once a proof settles, and the reverse order pays only once — without introducing a key. Going from two functions to three changes our central claim, so the build condition, the harness rules and the demo script all move in the same commit.

4. LIVE ADVERSARIAL INPUT — let the audience attack the judge.

The seller's delivery claim becomes free text that anyone watching can write. No byte of it changes the re-execution's verdict, pre, post, delta, gas used, state root or deal binding. Only what the seller actually delivered does, and that flips the verdict deterministically at the funded threshold. An opinion judge reading the same words can be talked into approving. Re-execution cannot be talked into anything — that is the entire product, made testable by strangers in real time.

HOW WE WORK, since you are assessing whether we can carry this

Every feature gets a written specification with mechanically checkable acceptance criteria, then an adversarial review by a second, independent model, and only then implementation. Specifications and review records are committed under docs/specs/ and docs/reviews/, each ending in an explicit APPROVE or CHANGES verdict.

That process is why the soundness bug above was found on day one instead of after shipping. The same reviews also caught that our acceptance criteria could pass with zero tests written — forge and cargo both exit 0 on a filter that matches nothing — and that our one-command demo discarded its test suite's exit status. We would rather tell you that than show you a green screenshot.
```

## Q3: Which of these are motivating you to apply?

選択肢が未取得のため未回答。選択肢を貼ってもらい次第、**該当するものだけ**を選ぶ
（該当しない「新しいチームを探している」「初参加」などを埋めない）。

## この回答が生む約束

Q2 に4本書いた以上、**出す義務がある**。特に項目2（クロスVM 決済）は現在
`AGENTS.md` §3 に登録されていない。**task 009 として登録し、実行順を
`008 → 009 → 003 → 004` に変更する**こと（binding が v2 になるため 008 の後、
審査で最も効く差分のため 004 より前）。9/9 のチェックポイントも合わせて更新する。
